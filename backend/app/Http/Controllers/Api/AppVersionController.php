<?php

namespace App\Http\Controllers\Api;

use App\Helpers\ApiResponse;
use App\Http\Controllers\Controller;
use App\Models\AppVersion;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

/**
 * App self-update endpoints (public — dipanggil sebelum login).
 *
 * Sumber data: tabel `app_versions` (row dengan is_active=true).
 * Fallback ke config('app_release.*') kalau tabel kosong / tidak ada
 * row aktif — supaya tidak break instalasi lama yang belum migrasi.
 *
 * Kontrak response /api/v1/app/version:
 *   {
 *     latest_version: "1.2.0",
 *     min_version:    "1.0.0",
 *     apk_url:        "https://api.example.com/api/v1/app/apk/download",
 *     force_update:   false,
 *     changelog:      "..."
 *   }
 */
class AppVersionController extends Controller
{
    public function version(Request $request)
    {
        $active = AppVersion::active()->first();

        if ($active) {
            return ApiResponse::success([
                'latest_version' => $active->version,
                'min_version'    => $active->min_version ?? '0.0.0',
                'apk_url'        => url('/api/v1/app/apk/download'),
                'force_update'   => (bool) $active->force_update,
                'changelog'      => $active->changelog,
            ]);
        }

        // Fallback: env-driven (untuk deployment yang belum migrasi).
        return ApiResponse::success([
            'latest_version' => config('app_release.version', '1.0.0'),
            'min_version'    => config('app_release.min_version', '1.0.0'),
            'apk_url'        => url('/api/v1/app/apk/download'),
            'force_update'   => (bool) config('app_release.force_update', false),
            'changelog'      => config('app_release.changelog'),
        ]);
    }

    /**
     * Stream APK row aktif. Path file dibaca dari DB, bukan dari input
     * user — supaya user tidak bisa request sembarang file di disk.
     */
    public function downloadApk(Request $request)
    {
        $active = AppVersion::active()->first();

        if (! $active) {
            return ApiResponse::error('Tidak ada rilis aktif.', 404);
        }

        $disk = Storage::disk(config('app_release.disk', 'public'));

        if (! $active->apk_path || ! $disk->exists($active->apk_path)) {
            return ApiResponse::error('APK belum diupload untuk rilis ini.', 404);
        }

        $filename = "laundryaja-{$active->version}.apk";

        // streamDownload baca file langsung dari disk tanpa load ke
        // memory — penting untuk APK yang bisa 50-80 MB.
        return $disk->download($active->apk_path, $filename, [
            'Content-Type' => 'application/vnd.android.package-archive',
            // APK bisa di-cache lama — versioned URL tidak dipakai di
            // sini (frontend cache via ?v= di level app), jadi pakai
            // ETag dari checksum.
            'ETag' => $active->apk_checksum ? "\"{$active->apk_checksum}\"" : null,
        ]);
    }
}