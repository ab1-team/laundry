<?php

use App\Http\Controllers\Admin\AuthController;
use App\Http\Controllers\Admin\IconController;
use App\Http\Controllers\Admin\ReleaseController;
use App\Http\Controllers\Admin\UserController;
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

        // Icon Manager — CRUD icon global (lihat Admin\IconController).
        // Icon dipakai oleh semua tenant lewat FK icon_id, jadi di-manage
        // di sini sekali dan otomatis tersedia untuk picker mobile.
        Route::get('icons',                  [IconController::class, 'index'])->name('admin.icons.index');
        Route::post('icons',                 [IconController::class, 'store'])->name('admin.icons.store');
        Route::patch('icons/{icon}',         [IconController::class, 'update'])->name('admin.icons.update');
        Route::delete('icons/{icon}',        [IconController::class, 'destroy'])->name('admin.icons.destroy');

        // User Manager — CRUD semua user (super_admin, owner, operator).
        // Lihat Admin\UserController. Endpoint password terpisah supaya
        // form edit profil tidak tercampur dengan reset password.
        Route::get('users',                    [UserController::class, 'index'])->name('admin.users.index');
        Route::post('users',                   [UserController::class, 'store'])->name('admin.users.store');
        Route::patch('users/{user}',           [UserController::class, 'update'])->name('admin.users.update');
        Route::patch('users/{user}/password',  [UserController::class, 'resetPassword'])->name('admin.users.password');
        Route::delete('users/{user}',          [UserController::class, 'destroy'])->name('admin.users.destroy');
    });
});