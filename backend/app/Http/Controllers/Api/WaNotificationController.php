<?php

namespace App\Http\Controllers\Api;

use App\Contracts\WhatsAppGateway;
use App\Helpers\ApiResponse;
use App\Http\Controllers\Controller;
use App\Http\Requests\WaPairingRequest;
use App\Http\Resources\WaNotificationResource;
use App\Jobs\SendWaNotificationJob;
use App\Models\WaNotification;
use App\Services\N8nWaGateway;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
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
    public function reset(Request $request, WhatsAppGateway $wa)
    {
        $tenant = $request->user()->tenant;

        if (!$tenant) {
            return ApiResponse::error('Tenant tidak ditemukan', 404);
        }

        $settings = $tenant->wa_settings ?? [];
        $instance = $settings['instance'] ?? null;

        // Hit WA gateway hanya kalau instance pernah dibuat — kalau belum,
        // state backend sudah "kosong", tidak perlu round-trip. n8n flow
        // tidak punya endpoint `logoutInstance` — `deleteInstance` cukup
        // idempotent untuk tujuan "putuskan sesi WA di HP owner".
        if ($instance) {
            try {
                $wa->deleteInstance($instance);
            } catch (RuntimeException $e) {
                return ApiResponse::error($e->getMessage(), 502);
            }
        }

        // Reset = putus koneksi sepenuhnya. Clear instance + enabled
        // supaya owner bisa input nomor baru. owner_number tetap sebagai
        // hint (pre-fill) tapi phone field jadi editable lagi.
        $settings['enabled'] = false;
        unset($settings['instance']);
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
    public function connectionState(Request $request, WhatsAppGateway $wa)
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
            $result = $wa->connectionState($instance);
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

    public function pairing(WaPairingRequest $request, N8nWaGateway $wa)
    {
        $tenant = $request->user()->tenant;

        if (!$tenant) {
            return ApiResponse::error('Tenant tidak ditemukan', 404);
        }

        $settings = $tenant->wa_settings ?? [];
        $instance = $settings['instance'] ?? null;
        $number = $request->input('number');

        // Auto-generate nama instance kalau belum ada. Format n8n:
        // `app-{slug}-{tenant_id}` (lihat N8nWaGateway::generateInstanceName).
        if (!$instance) {
            $instance = N8nWaGateway::generateInstanceName($number, $tenant->id);
            $settings['instance'] = $instance;
        }

        // HANYA hit n8n `create-instance`. SATU round-trip. Tidak ada
        // pre-flight `connectionState` (flakey, bisa 502), tidak ada retry
        // pairing code (n8n workflow saat ini return `pairingCode: null`
        // karena pairing code 8-char adalah flow Evolution-direct legacy,
        // bukan flow n8n webhook yang return QR).
        //
        // Polling state transisi `connecting → open` setelah owner scan QR
        // terjadi di endpoint terpisah `GET /wa-connection-state` (lihat
        // method `connectionState()` di bawah), cadence tiap 30-45 detik
        // supaya tidak spam n8n dan tidak trigger reset koneksi.
        try {
            $result = $wa->createInstance($instance, $number);
        } catch (RuntimeException $e) {
            // Logging swallow kalau storage/logs/ permission denied —
            // LoggingException akan propagate sebagai 500 dan wrap pesan
            // asli upstream, BUKAN 502 gateway. error_log() fallback ke
            // PHP error log (stderr container) supaya diagnosa tidak hilang.
            try {
                Log::error('wa-pairing: create-instance gagal', [
                    'tenant_id' => $tenant->id,
                    'instance'  => $instance,
                    'error'     => $e->getMessage(),
                ]);
            } catch (\Throwable $logErr) {
                error_log('[wa-pairing] log unavailable: ' . $logErr->getMessage()
                    . ' | original: ' . $e->getMessage());
            }
            return ApiResponse::error($e->getMessage(), 502);
        }

        // Persist instance + owner_number. `enabled` tetap false sampai
        // `connectionState()` melihat `state=open` di polling berikutnya.
        $settings['owner_number'] = $number;
        if (!isset($settings['notify_on']) || empty($settings['notify_on'])) {
            $settings['notify_on'] = ['selesai', 'diambil'];
        }
        $tenant->update(['wa_settings' => $settings]);

        // Return response apa adanya dari n8n → mobile. Field shape n8n
        // aktual: `{success, instance: {name, status, qr, pairingCode, state}}`.
        // Tidak strip/alias — biarkan mobile yang parse. Ini sesuai instruksi
        // "hanya hit create-instance" (no transformation layer di backend).
        return ApiResponse::success($result, 'Instance WhatsApp dibuat.');
    }

    /**
     * POST /api/v1/wa-pairing/regenerate
     *
     * Mintakan pairing code / QR baru untuk instance yang sudah ada —
     * TIDAK membuat instance baru (beda dari /wa-pairing). Pakai endpoint
     * n8n `instance-state` yang return `{qr, state}`. Owner tinggal scan
     * QR dengan WA → Linked Devices.
     *
     * Kapan pakai:
     * - Pairing code sebelumnya expire (60s) dan owner belum sempat input.
     * - Owner klik "Generate Pairing Lagi" setelah instance sudah dibuat.
     *
     * Response shape: sama dengan create-instance — `{success, instance:
     * {name, status, qr?, pairingCode?, state}}`. Pairing code 8-char
     * hanya muncul di create-instance (onboarding awal); flow regenerate
     * pakai QR base64 dari `instance.qr`.
     */
    public function regenerate(Request $request, WhatsAppGateway $wa)
    {
        $tenant = $request->user()->tenant;

        if (!$tenant) {
            return ApiResponse::error('Tenant tidak ditemukan', 404);
        }

        $settings = $tenant->wa_settings ?? [];
        $instance = $settings['instance'] ?? null;
        $ownerNumber = $settings['owner_number'] ?? null;

        // Guard: kalau instance + owner_number belum ada, paksa mobile
        // pakai /wa-pairing dulu untuk create-instance + input nomor.
        if (!$instance || !$ownerNumber) {
            return ApiResponse::error(
                'Belum ada instance WhatsApp. Panggil /wa-pairing dulu untuk membuat instance.',
                422
            );
        }

        // Bypass n8n idempotency: nama instance existing di n8n (walaupun
        // sudah stale / state=unknown) bikin create-instance kembalikan
        // response default tanpa pairing code 8-char. Untuk regenerate
        // pairing code yang reliable, kita pakai nama instance BARU dengan
        // suffix timestamp — pairing di WA tetap pakai nomor HP owner,
        // jadi owner HP tidak perlu input pairing code baru kecuali
        // kalau owner ganti device (lihat alur pairing WA manual).
        $regenInstance = $instance . '-' . substr((string) time(), -6);

        try {
            $result = $wa->regeneratePairing($regenInstance, $ownerNumber);
        } catch (RuntimeException $e) {
            try {
                Log::error('wa-pairing: regenerate gagal', [
                    'tenant_id' => $tenant->id,
                    'instance'  => $instance,
                    'error'     => $e->getMessage(),
                ]);
            } catch (\Throwable $logErr) {
                error_log('[wa-pairing] regenerate log unavailable: '
                    . $logErr->getMessage() . ' | original: ' . $e->getMessage());
            }
            return ApiResponse::error($e->getMessage(), 502);
        }

        // Persist nama instance baru supaya connectionState() polling
        // pakai nama yang benar.
        $settings['instance'] = $regenInstance;
        $settings['enabled'] = false;
        $tenant->update(['wa_settings' => $settings]);

        return ApiResponse::success($result, 'Pairing code / QR baru diminta.');
    }
}
