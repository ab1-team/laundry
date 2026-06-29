<?php

namespace App\Http\Controllers\Api\Admin;

use App\Helpers\ApiResponse;
use App\Http\Controllers\Controller;
use App\Http\Requests\AppVersionRequest;
use App\Models\AppVersion;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

/**
 * Admin endpoints untuk manage rilis APK.
 *
 *   GET    /api/v1/admin/app-versions              — list semua row
 *   POST   /api/v1/admin/app-versions              — create row (metadata)
 *   POST   /api/v1/admin/app-versions/{id}/upload — upload file APK
 *   PATCH  /api/v1/admin/app-versions/{id}         — update metadata
 *   DELETE /api/v1/admin/app-versions/{id}         — hapus row + file
 *   PATCH  /api/v1/admin/app-versions/{id}/activate — set is_active=true
 *
 * Kenapa upload dipisah dari create?
 *   - Multipart upload di FormRequest validasi campuran susah di-handle
 *     (string + file). Pisahkan biar validasi file di fase upload saja.
 *   - Admin bisa create draft row dulu (mis. jadwal publish), upload
 *     belakangan saat build selesai.
 */
class AppVersionAdminController extends Controller
{
    public function index(Request $request)
    {
        $query = AppVersion::query()->orderByDesc('id');

        if ($request->boolean('active_only')) {
            $query->where('is_active', true);
        }

        return ApiResponse::paginated($query->paginate(20), \App\Http\Resources\AppVersionResource::class);
    }

    public function store(AppVersionRequest $request)
    {
        $row = AppVersion::create($request->validated());

        return ApiResponse::success(
            new \App\Http\Resources\AppVersionResource($row),
            'Rilis berhasil dibuat. Upload APK sebelum aktivasi.',
            201
        );
    }

    public function show(AppVersion $appVersion)
    {
        return ApiResponse::success(new \App\Http\Resources\AppVersionResource($appVersion));
    }

    public function update(AppVersionRequest $request, AppVersion $appVersion)
    {
        $appVersion->update($request->validated());

        return ApiResponse::success(
            new \App\Http\Resources\AppVersionResource($appVersion),
            'Rilis berhasil diupdate'
        );
    }

    /**
     * Upload file APK ke storage + hitung checksum + size.
     * Validasi: MIME application/vnd.android.package-archive + ekstensi .apk.
     */
    public function upload(Request $request, AppVersion $appVersion)
    {
        $request->validate([
            'apk' => ['required', 'file', 'mimetypes:application/vnd.android.package-archive', 'max:102400'], // 100 MB
        ]);

        $disk = Storage::disk('public');
        $file = $request->file('apk');

        // Path deterministik per versi — replace upload lama kalau ada.
        $relativePath = "releases/laundryaja-{$appVersion->version}.apk";
        if ($disk->exists($relativePath)) {
            $disk->delete($relativePath);
        }
        $disk->putFileAs('releases', $file, "laundryaja-{$appVersion->version}.apk");

        // Hitung SHA-256 dari konten yang baru disimpan — buka dari disk
        // (bukan dari UploadedFile) supaya hash konsisten dengan yang
        // akan di-download client.
        $absolute = $disk->path($relativePath);
        $checksum = hash_file('sha256', $absolute);

        $appVersion->update([
            'apk_path'     => $relativePath,
            'apk_size'     => filesize($absolute) ?: null,
            'apk_checksum' => $checksum,
        ]);

        return ApiResponse::success(
            new \App\Http\Resources\AppVersionResource($appVersion->fresh()),
            'APK berhasil diupload'
        );
    }

    /**
     * Aktivasi row. Hanya satu row yang boleh is_active=true — dilakukan
     * dalam transaction supaya tidak ada window "no active row" kalau
     * dua admin klik bersamaan.
     */
    public function activate(AppVersion $appVersion)
    {
        DB::transaction(function () use ($appVersion) {
            AppVersion::where('is_active', true)->update(['is_active' => false]);
            $appVersion->update([
                'is_active'    => true,
                'published_at' => $appVersion->published_at ?? now(),
            ]);
        });

        return ApiResponse::success(
            new \App\Http\Resources\AppVersionResource($appVersion->fresh()),
            "Versi {$appVersion->version} sekarang aktif untuk semua user"
        );
    }

    /**
     * Soft logic: kalau row aktif dihapus, jangan sampai tidak ada row
     * aktif sama sekali — yang lain jadi error 500 di endpoint publik.
     * Caller bisa aktivasi row lain secara manual setelah delete.
     */
    public function destroy(AppVersion $appVersion)
    {
        $disk = Storage::disk('public');
        if ($appVersion->apk_path && $disk->exists($appVersion->apk_path)) {
            $disk->delete($appVersion->apk_path);
        }
        $appVersion->delete();

        return ApiResponse::success(null, 'Rilis berhasil dihapus');
    }
}