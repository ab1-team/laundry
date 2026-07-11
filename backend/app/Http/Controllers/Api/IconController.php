<?php

namespace App\Http\Controllers\Api;

use App\Helpers\ApiResponse;
use App\Http\Controllers\Controller;
use App\Http\Requests\IconRequest;
use App\Http\Resources\IconResource;
use App\Models\Icon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class IconController extends Controller
{
    /**
     * GET /api/v1/icons
     */
    public function index(Request $request)
    {
        $query = Icon::query();

        if ($request->boolean('active_only')) {
            $query->where('is_active', true);
        }

        // Tenant scope otomatis dari BelongsToTenant trait.
        $icons = $query->orderBy('name')->paginate(50);

        return ApiResponse::paginated($icons, IconResource::class);
    }

    /**
     * POST /api/v1/icons (multipart untuk upload file).
     */
    public function store(IconRequest $request)
    {
        $data = $request->validated();

        // Upload file icon ke disk public (folder tenants/icons/{tenant_id}).
        // Pola sama dengan TenantSettingsController::update logo.
        if ($request->hasFile('icon')) {
            $data['icon_path'] = $this->storeIconFile($request->file('icon'));
        }

        // Field `icon` (file) bukan fillable; buang agar tidak lolos ke create().
        unset($data['icon']);

        $icon = Icon::create($data);

        return ApiResponse::success(
            new IconResource($icon),
            'Icon berhasil dibuat',
            201
        );
    }

    /**
     * GET /api/v1/icons/{icon}
     */
    public function show(Icon $icon)
    {
        return ApiResponse::success(new IconResource($icon));
    }

    /**
     * PUT/PATCH /api/v1/icons/{icon} (multipart opsional untuk replace file).
     */
    public function update(IconRequest $request, Icon $icon)
    {
        $data = $request->validated();

        if ($request->hasFile('icon')) {
            // Hapus file lama biar tidak numpuk di storage.
            if ($icon->icon_path && Storage::disk('public')->exists($icon->icon_path)) {
                Storage::disk('public')->delete($icon->icon_path);
            }
            $data['icon_path'] = $this->storeIconFile($request->file('icon'));
        }

        unset($data['icon']);

        $icon->update($data);

        return ApiResponse::success(
            new IconResource($icon->fresh()),
            'Icon berhasil diupdate'
        );
    }

    /**
     * DELETE /api/v1/icons/{icon}
     */
    public function destroy(Icon $icon)
    {
        // Hapus file fisik kalau ada — DB constraint akan nullOnDelete
        // service_categories.icon_id & services.icon_id (lihat migration).
        if ($icon->icon_path && Storage::disk('public')->exists($icon->icon_path)) {
            Storage::disk('public')->delete($icon->icon_path);
        }

        $icon->delete();

        return ApiResponse::success(null, 'Icon berhasil dihapus');
    }

    /**
     * Simpan file upload ke tenants/icons/<tenant_id>/<hash>.<ext>.
     * Folder per tenant membatasi blast radius kalau storage leak.
     */
    private function storeIconFile(\Illuminate\Http\UploadedFile $file): string
    {
        $tenantId = auth()->user()?->tenant_id ?? 'shared';
        return $file->store("tenants/icons/{$tenantId}", 'public');
    }
}