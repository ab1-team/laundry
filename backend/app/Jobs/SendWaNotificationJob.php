<?php

namespace App\Jobs;

use App\Models\WaNotification;
use App\Services\EvolutionService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
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

        try {
            $evolution->sendText($instance, $notif->phone, $notif->message);

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
        if ($notif && $notif->status !== WaNotification::STATUS_SENT) {
            $notif->update([
                'status' => WaNotification::STATUS_FAILED,
                'error'  => $exception->getMessage(),
            ]);
        }
    }
}
