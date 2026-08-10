<?php

namespace App\Providers;

use App\Contracts\WhatsAppGateway;
use App\Services\N8nWaGateway;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        // Bind kontrak WA gateway ke implementasi n8n. Caller cukup
        // type-hint `WhatsAppGateway` — dapat `N8nWaGateway` instance
        // dengan env config (WA_GATEWAY_BASE / WA_GATEWAY_API_KEY) sudah
        // di-resolve lewat config('services.wa_gateway.*').
        //
        // Untuk ganti provider (Twilio, Meta Cloud, dll di masa depan),
        // cukup swap binding ini — semua caller yang pakai type-hint
        // WhatsAppGateway (SendWaNotificationJob, WaNotificationController)
        // otomatis ikut tanpa edit.
        $this->app->bind(WhatsAppGateway::class, N8nWaGateway::class);
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        //
    }
}
