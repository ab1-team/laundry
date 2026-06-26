<?php

namespace App\Http\Controllers\Api;

use App\Helpers\ApiResponse;
use App\Http\Controllers\Controller;
use App\Http\Requests\TenantSettingsRequest;
use App\Http\Resources\TenantResource;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class TenantSettingsController extends Controller
{
    /**
     * GET /api/v1/settings/tenant
     */
    public function show(Request $request)
    {
        $tenant = $request->user()->tenant;

        if (!$tenant) {
            return ApiResponse::error('Tenant tidak ditemukan', 404);
        }

        return ApiResponse::success(new TenantResource($tenant));
    }

    /**
     * PUT/PATCH /api/v1/settings/tenant (multipart untuk upload logo).
     */
    public function update(TenantSettingsRequest $request)
    {
        $tenant = $request->user()->tenant;

        if (!$tenant) {
            return ApiResponse::error('Tenant tidak ditemukan', 404);
        }

        $data = $request->validated();

        // Handle upload logo: simpan ke disk public di folder tenants/logos,
        // hapus file lama supaya tidak menumpuk. Path relatif disimpan ke kolom logo_path.
        if ($request->hasFile('logo')) {
            if ($tenant->logo_path && Storage::disk('public')->exists($tenant->logo_path)) {
                Storage::disk('public')->delete($tenant->logo_path);
            }
            $data['logo_path'] = $request->file('logo')->store(
                'tenants/logos',
                'public'
            );
        }

        // Logo bukan field fillable di model selain via logo_path di atas,
        // buang key 'logo' dari validated payload agar tidak error fillable.
        unset($data['logo']);

        $tenant->update($data);

        return ApiResponse::success(
            new TenantResource($tenant->fresh()),
            'Pengaturan tenant berhasil diupdate'
        );
    }
}
