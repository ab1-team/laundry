<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Icon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

/**
 * Admin web controller untuk manage global Icon library.
 *
 * Pattern: TIDAK memanggil API endpoint via HTTP. Langsung query model
 * — sama dengan ReleaseController. Icon dipakai semua tenant via FK
 * icon_id di service_categories & services, jadi CRUD dilakukan di
 * sini dan otomatis tersedia untuk semua picker di mobile.
 *
 * Lokasi storage: `icons/<hash>.<ext>` di disk `public` — tanpa folder
 * tenant karena icon adalah global asset (lihat migration
 * 2026_07_11_110000_make_icons_global yang drop tenant_id).
 */
class IconController extends Controller
{
    public function index(Request $request)
    {
        $icons = Icon::query()
            ->orderByDesc('id')
            ->paginate(24)
            ->withQueryString();

        return view('admin.icons', [
            'icons' => $icons,
        ]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:100'],
            // image max 1 MB; ukuran image picker mobile biasanya
            // sudah compress, tapi admin web bisa upload apa saja.
            'icon' => ['required', 'file', 'image', 'max:1024'],
        ]);

        $data['icon_path'] = $request->file('icon')->store('icons', 'public');
        $icon = Icon::create($data);

        return redirect()
            ->route('admin.icons.index')
            ->with('status', "Icon \"{$icon->name}\" berhasil ditambahkan.");
    }

    public function update(Request $request, Icon $icon)
    {
        $data = $request->validate([
            'name'      => ['required', 'string', 'max:100'],
            // Nullable pada update — kalau admin tidak upload file baru,
            // hanya update metadata. Kalau upload, replace file lama.
            'icon'      => ['nullable', 'file', 'image', 'max:1024'],
            'is_active' => ['boolean'],
        ]);

        $data['is_active'] = $request->boolean('is_active');

        $disk = Storage::disk('public');
        if ($request->hasFile('icon')) {
            if ($icon->icon_path && $disk->exists($icon->icon_path)) {
                $disk->delete($icon->icon_path);
            }
            $data['icon_path'] = $request->file('icon')->store('icons', 'public');
        }

        $icon->update($data);

        return redirect()
            ->route('admin.icons.index')
            ->with('status', "Icon \"{$icon->name}\" berhasil diupdate.");
    }

    public function destroy(Icon $icon)
    {
        $name = $icon->name;
        $disk = Storage::disk('public');
        if ($icon->icon_path && $disk->exists($icon->icon_path)) {
            $disk->delete($icon->icon_path);
        }
        $icon->delete();

        return redirect()
            ->route('admin.icons.index')
            ->with('status', "Icon \"{$name}\" berhasil dihapus. Kategori/layanan yang memakainya akan kehilangan icon.");
    }
}