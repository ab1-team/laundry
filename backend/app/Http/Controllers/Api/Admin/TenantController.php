<?php

namespace App\Http\Controllers\Api\Admin;

use App\Helpers\ApiResponse;
use App\Http\Controllers\Controller;
use App\Http\Requests\TenantRequest;
use App\Http\Resources\TenantResource;
use App\Models\Tenant;
use App\Services\TenantService;
use Illuminate\Http\Request;

class TenantController extends Controller
{
    public function __construct(private readonly TenantService $tenantService) {}

    /**
     * GET /api/v1/admin/tenants
     */
    public function index(Request $request)
    {
        $query = Tenant::query();

        // Filter
        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        if ($search = $request->query('search')) {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('slug', 'like', "%{$search}%");
            });
        }

        $tenants = $query->withCount('users')->orderBy('created_at', 'desc')->paginate(20);

        return ApiResponse::paginated($tenants, TenantResource::class);
    }

    /**
     * POST /api/v1/admin/tenants
     * Bikin tenant + owner account dalam satu transaksi atomik.
     */
    public function store(TenantRequest $request)
    {
        $data = $request->validated();

        // Pakai service yang sama dengan public register, sehingga
        // tenant + owner tercipta dalam satu DB transaction dan status
        // awal trial + trial_ends_at 14 hari konsisten.
        $tenant = $this->tenantService->registerTenant([
            'name'           => $data['name'],
            'slug'           => $data['slug'],
            'phone'          => $data['phone'] ?? null,
            'address'        => $data['address'] ?? null,
            'city'           => $data['city'] ?? null,
            'owner_name'     => $data['owner_name'],
            'owner_email'    => $data['owner_email'],
            'owner_password' => $data['owner_password'],
        ]);

        return ApiResponse::success(
            new TenantResource($tenant->loadCount('users')),
            'Tenant + owner berhasil dibuat',
            201
        );
    }

    /**
     * GET /api/v1/admin/tenants/{tenant}
     */
    public function show(Tenant $tenant)
    {
        return ApiResponse::success(new TenantResource($tenant->loadCount('users')));
    }

    /**
     * PUT/PATCH /api/v1/admin/tenants/{tenant}
     */
    public function update(TenantRequest $request, Tenant $tenant)
    {
        $tenant->update($request->validated());

        return ApiResponse::success(new TenantResource($tenant), 'Tenant berhasil diupdate');
    }

    /**
     * PATCH /api/v1/admin/tenants/{tenant}/activate
     */
    public function activate(Tenant $tenant)
    {
        $tenant->update([
            'status'       => Tenant::STATUS_ACTIVE,
            'activated_at' => now(),
        ]);

        return ApiResponse::success(new TenantResource($tenant), 'Tenant berhasil diaktifkan');
    }

    /**
     * PATCH /api/v1/admin/tenants/{tenant}/suspend
     */
    public function suspend(Request $request, Tenant $tenant)
    {
        $request->validate(['reason' => 'nullable|string|max:255']);

        $tenant->update(['status' => Tenant::STATUS_SUSPENDED]);

        return ApiResponse::success(new TenantResource($tenant), 'Tenant berhasil di-suspend');
    }

    /**
     * DELETE /api/v1/admin/tenants/{tenant}
     * Hard delete — SoftDeletes belum diaktifkan di Tenant model.
     */
    public function destroy(Tenant $tenant)
    {
        $tenant->delete();

        return ApiResponse::success(null, 'Tenant berhasil dihapus');
    }
}