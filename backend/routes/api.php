<?php

use App\Http\Controllers\Api\Admin\AppVersionAdminController;
use App\Http\Controllers\Api\Admin\TenantController;
use App\Http\Controllers\Api\AppVersionController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CustomerController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\ServiceCategoryController;
use App\Http\Controllers\Api\ServiceController;
use App\Http\Controllers\Api\TenantSettingsController;
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