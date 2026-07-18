<?php

namespace App\Http\Controllers\Api;

use App\Helpers\ApiResponse;
use App\Http\Controllers\Controller;
use App\Http\Requests\WaPairingRequest;
use App\Http\Resources\WaNotificationResource;
use App\Jobs\SendWaNotificationJob;
use App\Models\WaNotification;
use App\Services\EvolutionService;
use Illuminate\Http\Request;
use RuntimeException;

class WaNotificationController extends Controller
{
    /**
     * GET /api/v1/wa-notifications
     *
     * Query: ?status=sent|failed|pending, ?order_id=, ?per_page=
     */
    public function index(Request $request)
    {
        $query = WaNotification::query()->orderByDesc('created_at');

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }
        if ($orderId = $request->query('order_id')) {
            $query->where('order_id', $orderId);
        }

        $perPage = min((int) $request->query('per_page', 25), 100);

        return ApiResponse::paginated(
            $query->paginate($perPage),
            WaNotificationResource::class
        );
    }

    /**
     * POST /api/v1/wa-notifications/{notification}/retry
     * Re-dispatch job kalau status failed.
     */
    public function retry(Request $request, WaNotification $notification)
    {
        if ($notification->status === WaNotification::STATUS_SENT) {
            return ApiResponse::error('Notifikasi sudah terkirim.', 422);
        }

        $notification->update([
            'status' => WaNotification::STATUS_PENDING,
            'error'  => null,
        ]);

        SendWaNotificationJob::dispatch($notification->id);

        return ApiResponse::success(
            new WaNotificationResource($notification->fresh()),
            'Job kirim WA akan dijalankan ulang.'
        );
    }

/**
     * POST /api/v1/wa-pairing
     *
     * Ambil pairing code untuk instance tenant. Owner tampilkan kode ini
     * ke customer-service-onboarding agar di-input manual di WA:
     * Settings → Linked Devices → "Link with phone number".
     *
     * Flow try-first, create-on-404:
     * 1. Auto-generate nama instance kalau `wa_settings.instance` kosong
     *    (format "LaundryAja-{nomorHP}{tenantId}").
     * 2. Try pairingCode(instance, number) langsung. Kalau instance ada
     *    → dapat kode, return ke mobile.
     * 3. Kalau Evolution return 404 (instance tidak ada) → createInstance
     *    + retry pairingCode SEKALI. Ini menggantikan pre-flight
     *    `connectionState` yang kadang flakey dan bikin mobile dapat
     *    502 di first request.
     * 4. Kalau masih error → return error ke mobile.
     *
     * Body: { number: "0812xxx" }
     * Response: { pairing_code: "WZYEH1YY", instance: "...", expires_in: 60 }
     *
     * Pairing code cuma berlaku ~60 detik dan hanya sekali pakai — kalau
     * expired, panggil endpoint ini lagi untuk regenerate.
     */
    public function reset(Request $request, EvolutionService $evolution)
    {
        $tenant = $request->user()->tenant;

        if (!$tenant) {
            return ApiResponse::error('Tenant tidak ditemukan', 404);
        }

        $settings = $tenant->wa_settings ?? [];
        $instance = $settings['instance'] ?? null;

        // Hit Evolution hanya kalau instance pernah dibuat — kalau belum,
        // state backend sudah "kosong", tidak perlu round-trip.
        if ($instance) {
            try {
                $evolution->logoutInstance($instance);
            } catch (RuntimeException $e) {
                return ApiResponse::error($e->getMessage(), 502);
            }
        }

        // Clear enabled flag — instance & owner_number tetap (untuk re-pair
        // cepat pakai nomor sama). Kalau owner ganti nomor, /wa-pairing
        // endpoint auto-detect dan update.
        $settings['enabled'] = false;
        $tenant->update(['wa_settings' => $settings]);

        return ApiResponse::success([
            'instance' => $instance,
        ], 'Koneksi WhatsApp di-reset. Generate pairing code baru untuk menghubungkan ulang.');
    }

    /**
     * GET /api/v1/wa-connection-state
     *
     * Sinkronkan flag `enabled` di tenants.wa_settings dengan state real
     * dari Evolution. Owner bisa re-pair WA di HP tanpa lewat endpoint
     * /wa-pairing (mis. langsung di WA → Linked Devices setelah reset),
     * sehingga DB `enabled` bisa stale=false walau Evolution `state=open`.
     *
     * Endpoint ini panggil Evolution connectionState — kalau `state=open`,
     * set enabled=true. Return `{state, enabled}` ke mobile untuk refresh UI.
     *
     * Idempotent: kalau instance belum pernah dibuat, return enabled=false
     * tanpa hit Evolution.
     */
    public function connectionState(Request $request, EvolutionService $evolution)
    {
        $tenant = $request->user()->tenant;

        if (!$tenant) {
            return ApiResponse::error('Tenant tidak ditemukan', 404);
        }

        $settings = $tenant->wa_settings ?? [];
        $instance = $settings['instance'] ?? null;
        $enabled = (bool) ($settings['enabled'] ?? false);

        // No instance = never setup → nothing to sync.
        if (!$instance) {
            return ApiResponse::success([
                'state' => null,
                'enabled' => false,
            ]);
        }

        try {
            $result = $evolution->connectionState($instance);
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), 502);
        }

        $state = $result['instance']['state'] ?? null;

        // Sinkron DB kalau state berubah:
        // - open + enabled=false → owner re-pair manual di WA, reflect.
        // - close + enabled=true → owner logout WA di HP, reflect.
        if ($state === 'open' && !$enabled) {
            $settings['enabled'] = true;
            $tenant->update(['wa_settings' => $settings]);
            $enabled = true;
        } elseif ($state === 'close' && $enabled) {
            // Close di Evolution tapi DB masih enabled=true → sync down.
            // Skip kalau enabled=false (no-op).
            $settings['enabled'] = false;
            $tenant->update(['wa_settings' => $settings]);
            $enabled = false;
        }

        return ApiResponse::success([
            'state' => $state,
            'enabled' => $enabled,
            'instance' => $instance,
        ]);
    }

    public function pairing(WaPairingRequest $request, EvolutionService $evolution)
    {
        $tenant = $request->user()->tenant;

        if (!$tenant) {
            return ApiResponse::error('Tenant tidak ditemukan', 404);
        }

        $settings = $tenant->wa_settings ?? [];
        $instance = $settings['instance'] ?? null;
        $number = $request->input('number');

        // Auto-generate nama instance kalau belum ada.
        if (!$instance) {
            $instance = EvolutionService::generateInstanceName($number, $tenant->id);
            $settings['instance'] = $instance;
        }

        try {
            // Try pairing langsung. Happy path: 1 round-trip kalau instance
            // sudah ada. Kalau 404 (instance dropped atau belum dibuat),
            // createInstance + retry pairing sekali.
            try {
                $result = $evolution->pairingCode($instance, $number);
            } catch (RuntimeException $e) {
                if (!str_contains($e->getMessage(), '[404]')) {
                    throw $e;
                }
                // 404 → create + retry
                $evolution->createInstance($instance, $number);
                $result = $evolution->pairingCode($instance, $number);
            }
        } catch (RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), 502);
        }

        $pairingCode = $result['pairingCode']
            ?? $result['pairing_code']
            ?? $result['code']
            ?? null;

        // Kalau instance sudah connected, Evolution return shape berbeda
        // ({"instance":{"state":"open"}}) tanpa pairingCode. Jangan treat
        // sebagai error — return info "already connected" supaya mobile
        // bisa stop hit endpoint. Sebelumnya ini return 502 dan user
        // lihat snackbar merah tiap buka screen.
        if (!$pairingCode) {
            $state = $result['instance']['state'] ?? null;
            if ($state === 'open') {
                // Sync enabled flag ke true — kalau backend detect state=open
                // via Evolution, pasti connected di-HP. Sebelumnya pakai
                // `?? true` yang gak override enabled=false existing (bug
                // yang bikin app stuck "Belum Diaktifkan" setelah owner
                // reset + re-pair manual via WA tanpa lewat endpoint ini).
                $settings['enabled'] = true;
                $settings['owner_number'] = $number;
                $tenant->update(['wa_settings' => $settings]);

                return ApiResponse::success([
                    'pairing_code' => null,
                    'instance'     => $instance,
                    'state'        => 'open',
                    'already_connected' => true,
                ], 'WhatsApp sudah terhubung.');
            }

            return ApiResponse::error(
                'Evolution API tidak mengembalikan pairing code. Cek log backend.',
                502
            );
        }

        // Simpan enabled=true + nomor owner + notify_on default.
        $settings['enabled'] = true;
        $settings['owner_number'] = $number;
        if (!isset($settings['notify_on']) || empty($settings['notify_on'])) {
            $settings['notify_on'] = ['selesai', 'diambil'];
        }
        $tenant->update(['wa_settings' => $settings]);

        return ApiResponse::success([
            'pairing_code' => $pairingCode,
            'instance'     => $instance,
            'expires_in'   => 60,
        ], 'Pairing code berhasil di-generate.');
    }
}
