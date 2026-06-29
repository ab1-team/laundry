<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AppVersion;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

/**
 * Admin web controller untuk manage app_versions.
 *
 * Pattern: TIDAK memanggil API endpoint via HTTP. Langsung pakai model
 * supaya sederhana, no CSRF-vs-API-token ribet, dan 1 round-trip less.
 * Endpoint API tetap dipertahankan untuk integrasi external / automation.
 */
class ReleaseController extends Controller
{
    public function index(Request $request)
    {
        $releases = AppVersion::query()
            ->orderByDesc('id')
            ->paginate(15)
            ->withQueryString();

        return view('admin.releases', [
            'releases' => $releases,
        ]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'version'      => ['required', 'string', 'max:30'],
            'version_code' => ['required', 'integer', 'min:1'],
            'min_version'  => ['nullable', 'string', 'max:30'],
            'force_update' => ['boolean'],
            'changelog'    => ['nullable', 'string', 'max:5000'],
        ]);

        $data['force_update'] = $request->boolean('force_update');
        $release = AppVersion::create($data);

        return redirect()
            ->route('admin.releases.index')
            ->with('status', "Rilis {$release->version} berhasil dibuat. Upload APK untuk melanjutkan.");
    }

    public function update(Request $request, AppVersion $appVersion)
    {
        $data = $request->validate([
            'version'      => ['required', 'string', 'max:30'],
            'version_code' => ['required', 'integer', 'min:1'],
            'min_version'  => ['nullable', 'string', 'max:30'],
            'force_update' => ['boolean'],
            'changelog'    => ['nullable', 'string', 'max:5000'],
        ]);

        $data['force_update'] = $request->boolean('force_update');
        $appVersion->update($data);

        return redirect()
            ->route('admin.releases.index')
            ->with('status', "Rilis {$appVersion->version} berhasil diupdate.");
    }

    public function upload(Request $request, AppVersion $appVersion)
    {
        $request->validate([
            'apk' => ['required', 'file', 'mimetypes:application/vnd.android.package-archive', 'max:102400'],
        ]);

        $disk = Storage::disk('public');
        $relativePath = "releases/laundryaja-{$appVersion->version}.apk";

        // Replace file lama kalau ada — tidak simpan history APK untuk
        // menjaga storage tetap ramping.
        if ($disk->exists($relativePath)) {
            $disk->delete($relativePath);
        }
        $disk->putFileAs('releases', $request->file('apk'), "laundryaja-{$appVersion->version}.apk");

        $absolute = $disk->path($relativePath);
        $appVersion->update([
            'apk_path'     => $relativePath,
            'apk_size'     => filesize($absolute) ?: null,
            'apk_checksum' => hash_file('sha256', $absolute),
        ]);

        return redirect()
            ->route('admin.releases.index')
            ->with('status', "APK untuk versi {$appVersion->version} berhasil diupload.");
    }

    public function activate(AppVersion $appVersion)
    {
        DB::transaction(function () use ($appVersion) {
            AppVersion::where('is_active', true)->update(['is_active' => false]);
            $appVersion->update([
                'is_active'    => true,
                'published_at' => $appVersion->published_at ?? now(),
            ]);
        });

        return redirect()
            ->route('admin.releases.index')
            ->with('status', "Versi {$appVersion->version} sekarang aktif. User akan dapat update pada buka app berikutnya.");
    }

    public function destroy(AppVersion $appVersion)
    {
        $version = $appVersion->version;
        $disk = Storage::disk('public');
        if ($appVersion->apk_path && $disk->exists($appVersion->apk_path)) {
            $disk->delete($appVersion->apk_path);
        }
        $appVersion->delete();

        return redirect()
            ->route('admin.releases.index')
            ->with('status', "Rilis {$version} berhasil dihapus.");
    }
}