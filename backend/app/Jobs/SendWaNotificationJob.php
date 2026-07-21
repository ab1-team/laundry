<?php

namespace App\Jobs;

use App\Models\Order;
use App\Models\WaNotification;
use App\Services\EvolutionService;
use App\Services\NotaGenerator;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Throwable;

/**
 * Kirim 1 pesan WA via Evolution API, lalu update status log row.
 *
 * Dispatch dari OrderService::updateStatus ketika tenant wa_enabled=1
 * dan status ada di wa_settings.notify_on.
 *
 * Retry: 3x dengan backoff 30s/2m/5m. Failure akhir → status=failed
 * dengan pesan error di kolom `error`.
 *
 * Skipped: rate-limit per-instance, queue terpisah `wa`, monitoring
 * dashboard. Add when volume naik / multi-tenant banyak konflik.
 */
class SendWaNotificationJob implements ShouldQueue
{
    use Dispatchable, Queueable, InteractsWithQueue, SerializesModels;

    /**
     * Map mime → extension untuk WhatsApp attachment. Tanpa map ini,
     * `image/jpeg` jadi `nota-123.bin` yg penerima gak bisa buka.
     * Tambah entry di sini kalau support tipe media baru.
     */
    private const MIME_EXT_MAP = [
        'application/pdf' => 'pdf',
        'image/jpeg'      => 'jpg',
        'image/png'       => 'png',
        'image/webp'      => 'webp',
    ];

    public int $tries = 3;
    public int $timeout = 30;

    /** @var int[] Backoff detik antar retry */
    public function backoff(): array
    {
        return [30, 120, 300];
    }

    public function __construct(public int $notificationId) {}

    public function handle(EvolutionService $evolution): void
    {
        $notif = WaNotification::query()->find($this->notificationId);
        if (!$notif || $notif->status === WaNotification::STATUS_SENT) {
            return;
        }

        $tenant = $notif->tenant;
        if (!$tenant) {
            $notif->update([
                'status' => WaNotification::STATUS_FAILED,
                'error'  => 'Tenant tidak ditemukan',
            ]);
            return;
        }

        $settings = $tenant->wa_settings ?? [];
        $instance = $settings['instance'] ?? null;

        if (!$instance) {
            $notif->update([
                'status' => WaNotification::STATUS_FAILED,
                'error'  => 'Instance Evolution API belum diset di tenant settings',
            ]);
            return;
        }

        if (!$evolution->isConfigured()) {
            $notif->update([
                'status' => WaNotification::STATUS_FAILED,
                'error'  => 'Evolution API global (base_url / api_key) belum di-set',
            ]);
            return;
        }

        // Generate PDF nota kalau dispatch di-trigger oleh transisi ke
        // 'selesai' & belum ada media. Pakai trigger_status (bukan
        // order.finished_at) supaya notif 'diambil' tidak ikut generate —
        // finished_at tetap set setelah transisi 'diambil'.
        // Async di worker — supaya admin request tidak nunggu DomPDF.
        // Gagal → fallback text-only + log, retry job coba lagi (3x max).
        if (!$notif->hasMedia() && $notif->trigger_status === Order::STATUS_SELESAI) {
            try {
                $path = app(NotaGenerator::class)->generate($notif->order);
                $notif->update([
                    'media_path' => $path,
                    'media_type' => 'application/pdf',
                ]);
                $notif->refresh();
            } catch (Throwable $e) {
                Log::warning('Nota PDF generation gagal, kirim text-only', [
                    'order_id' => $notif->order_id,
                    'error'    => $e->getMessage(),
                ]);
            }
        }

        try {
            if ($notif->hasMedia()) {
                // Type null biasanya data inconsistency — jangan diam-diam
                // pakai default tanpa jejak.
                $mime = $notif->media_type;
                if (!$mime) {
                    Log::warning('WaNotification media_type null, default ke application/pdf', [
                        'notif_id' => $notif->id,
                        'path'     => $notif->media_path,
                    ]);
                    $mime = 'application/pdf';
                }

                $ext = self::MIME_EXT_MAP[$mime]
                    ?? preg_replace(
                        '/[^a-z0-9]/',
                        '',
                        strtolower(explode('/', $mime, 2)[1] ?? ''),
                    )
                    ?: 'bin';

                $fname = "nota-{$notif->order_id}.{$ext}";
                $evolution->sendMedia(
                    $instance,
                    $notif->phone,
                    $notif->media_path,
                    $mime,
                    $fname,
                    $notif->message,
                );
            } else {
                $evolution->sendText($instance, $notif->phone, $notif->message);
            }

            $notif->update([
                'status' => WaNotification::STATUS_SENT,
                'sent_at' => now(),
                'error'   => null,
            ]);
        } catch (Throwable $e) {
            // Tandai failed hanya di attempt terakhir — sebelumnya biarkan
            // queue worker retry sesuai `backoff()`.
            if ($this->attempts() >= $this->tries) {
                $notif->update([
                    'status' => WaNotification::STATUS_FAILED,
                    'error'  => $e->getMessage(),
                ]);
                return;
            }
            throw $e;
        }
    }

    public function failed(Throwable $exception): void
    {
        $notif = WaNotification::query()->find($this->notificationId);
        if (!$notif || $notif->status === WaNotification::STATUS_SENT) {
            return;
        }

        // Hapus PDF orphaned — kalau job gagal permanen, file gak akan
        // pernah terkirim. Path nota/order-{id}.pdf cuma direference
        // 1 notif (saat ini), jadi aman delete tanpa cek referensi.
        // Future: kalau ada multi-notif per path, tambah referensi check.
        if ($notif->media_path && Storage::disk('local')->exists($notif->media_path)) {
            Storage::disk('local')->delete($notif->media_path);
        }

        $notif->update([
            'status' => WaNotification::STATUS_FAILED,
            'error'  => $exception->getMessage(),
        ]);
    }
}
