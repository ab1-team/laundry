<?php

use App\Http\Controllers\Admin\AuthController;
use App\Http\Controllers\Admin\ReleaseController;
use Illuminate\Support\Facades\Route;

// Landing publik tetap welcome.
Route::get('/', function () {
    return view('welcome');
});

// Admin panel — prefix /admin, terpisah dari API.
Route::prefix('admin')->group(function () {
    // Halaman yang tidak butuh auth
    Route::middleware('guest:web')->group(function () {
        Route::get('login',  [AuthController::class, 'showLogin'])->name('admin.login');
        Route::post('login', [AuthController::class, 'login'])->name('admin.login.attempt');
    });

    // Halaman yang butuh auth + role super_admin
    Route::middleware(['auth:web', 'role:super_admin'])->group(function () {
        Route::post('logout', [AuthController::class, 'logout'])->name('admin.logout');

        Route::get('/', [ReleaseController::class, 'index'])->name('admin.home');

        Route::get('releases',                   [ReleaseController::class, 'index'])->name('admin.releases.index');
        Route::post('releases',                  [ReleaseController::class, 'store'])->name('admin.releases.store');
        Route::patch('releases/{appVersion}',    [ReleaseController::class, 'update'])->name('admin.releases.update');
        Route::delete('releases/{appVersion}',   [ReleaseController::class, 'destroy'])->name('admin.releases.destroy');
        Route::post('releases/{appVersion}/upload',   [ReleaseController::class, 'upload'])->name('admin.releases.upload');
        Route::patch('releases/{appVersion}/activate', [ReleaseController::class, 'activate'])->name('admin.releases.activate');
    });
});