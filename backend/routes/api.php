<?php

use App\Http\Controllers\Api\Admin\AppVersionAdminController;
use App\Http\Controllers\Api\Admin\TenantController;
use App\Http\Controllers\Api\AppVersionController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CustomerController;
use App\Http\Controllers\Api\IconController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\ServiceCategoryController;
use App\Http\Controllers\Api\ServiceController;
use App\Http\Controllers\Api\TenantSettingsController;
use App\Http\Controllers\Api\WaNotificationController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes (v1)
|--------------------------------------------------------------------------
*/

Route::prefix('v1')->group(function () {

    // =====================
    // Public Auth
    // =====================
    Route::prefix('auth')->group(function () {
        Route::post('register', [AuthController::class, 'register']);
        Route::post('login',    [AuthController::class, 'login']);
    });

    // =====================
    // App self-update (public — perlu dijangkau sebelum login)
    // =====================
    Route::prefix('app')->group(function () {
        Route::get('version',        [AppVersionController::class, 'version']);
        Route::get('apk/download',   [AppVersionController::class, 'downloadApk']);
    });

    // =====================
    // Authenticated Routes
    // =====================
    Route::middleware('auth:sanctum')->group(function () {

        // Auth session
        Route::prefix('auth')->group(function () {
            Route::post('logout',  [AuthController::class, 'logout']);
            Route::get('me',       [AuthController::class, 'me']);
            Route::put('password', [AuthController::class, 'changePassword']);
            Route::put('profile',  [AuthController::class, 'updateProfile']);
        });

        // =====================
        // Tenant Settings
        // =====================
        Route::prefix('settings')->group(function () {
            Route::get('tenant',  [TenantSettingsController::class, 'show']);
            Route::match(['put', 'patch'], 'tenant', [TenantSettingsController::class, 'update']);
        });

        // =====================
        // Master Data (Services)
        // Owner & Operator boleh akses
        // =====================
        Route::prefix('master')->group(function () {
            Route::apiResource('service-categories', ServiceCategoryController::class);
            Route::apiResource('services',           ServiceController::class);
            // Icon: GET-only API. Create/update/delete via panel admin
            // /admin/icons (lihat routes/web.php). Icon adalah global
            // asset yang di-manage oleh super_admin.
            Route::get('icons', [IconController::class, 'index']);
        });

        // =====================
        // Customers
        // =====================
        Route::prefix('customers')->group(function () {
            Route::get('{customer}/orders', [CustomerController::class, 'orders']);
        });
        Route::apiResource('customers', CustomerController::class);

        // =====================
        // Orders
        // =====================
        Route::patch('orders/{order}/status', [OrderController::class, 'updateStatus']);
        Route::apiResource('orders', OrderController::class);

        // =====================
        // Payments & Piutang
        // =====================
        // Nested di order untuk catat / list per order
        Route::get('orders/{order}/payments',      [PaymentController::class, 'index']);
        Route::post('orders/{order}/payments',     [PaymentController::class, 'store']);
        Route::delete('orders/{order}/payments/{payment}', [PaymentController::class, 'destroy']);

        // Top-level: history transaksi per tenant
        Route::get('payments', [PaymentController::class, 'all']);

        // Piutang list
        Route::get('piutang',  [PaymentController::class, 'piutang']);

        // =====================
        // Reports (Owner only)
        // =====================
        Route::prefix('reports')->middleware('role:owner,super_admin')->group(function () {
            Route::get('dashboard',           [ReportController::class, 'dashboard']);
            Route::get('income/daily',        [ReportController::class, 'dailyIncome']);
            Route::get('income/weekly',       [ReportController::class, 'weeklyIncome']);
            Route::get('income/monthly',      [ReportController::class, 'monthlyIncome']);
            Route::get('services',            [ReportController::class, 'services']);
            Route::get('piutang',             [ReportController::class, 'piutang']);
            Route::get('export/orders',       [ReportController::class, 'exportOrders']);
            Route::get('export/payments',     [ReportController::class, 'exportPayments']);
        });

        // =====================
        // WA Notifications (log history)
        // =====================
        // GET  /api/v1/wa-notifications   — paginated, filter status/order
        // POST /api/v1/wa-notifications/{notification}/retry — re-dispatch jika failed
        Route::get('wa-notifications', [WaNotificationController::class, 'index']);
        Route::post('wa-notifications/{notification}/retry', [WaNotificationController::class, 'retry']);

        // POST /api/v1/wa-pairing — minta pairing code utk instance tenant
        // (Owner input manual di WA → Settings → Linked Devices → Link with phone)
        Route::post('wa-pairing', [WaNotificationController::class, 'pairing']);
        // POST /api/v1/wa-pairing/reset — logout instance di Evolution + clear
        // wa_settings.enabled. Setelah ini, re-call /wa-pairing untuk dapat
        // pairing code baru. Tujuannya: tombol "Reset Koneksi" benar-benar
        // memutus sesi WA di HP owner, bukan cuma return info "sudah terhubung".
        Route::post('wa-pairing/reset', [WaNotificationController::class, 'reset']);
        // GET /api/v1/wa-connection-state — sinkron flag enabled backend
        // dengan state real Evolution. Handle skenario owner re-pair manual
        // di WA tanpa lewat endpoint /wa-pairing (server-side reset DB
        // setelah owner reset koneksi).
        Route::get('wa-connection-state', [WaNotificationController::class, 'connectionState']);

        // =====================
        // Super Admin Routes
        // =====================
        Route::prefix('admin')
            ->middleware('role:super_admin')
            ->group(function () {
                Route::patch('tenants/{tenant}/activate', [TenantController::class, 'activate']);
                Route::patch('tenants/{tenant}/suspend',  [TenantController::class, 'suspend']);
                Route::apiResource('tenants', TenantController::class);

                // App self-release management. {appVersion} di-resolve via route model
                // binding — Laravel auto-inject AppVersion berdasarkan id di URL.
                Route::post('app-versions/{appVersion}/upload',  [AppVersionAdminController::class, 'upload']);
                Route::patch('app-versions/{appVersion}/activate', [AppVersionAdminController::class, 'activate']);
                Route::apiResource('app-versions', AppVersionAdminController::class);
            });
    });
});