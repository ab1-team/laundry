<?php

namespace App\Http\Controllers\Api;

use App\Helpers\ApiResponse;
use App\Http\Controllers\Controller;
use App\Http\Requests\ServiceCategoryRequest;
use App\Http\Resources\ServiceCategoryResource;
use App\Models\ServiceCategory;
use Illuminate\Http\Request;

class ServiceCategoryController extends Controller
{
    /**
     * GET /api/v1/master/service-categories
     */
    public function index(Request $request)
    {
        $query = ServiceCategory::query()
            ->with('icon:id,tenant_id,name,icon_path,is_active')
            ->withCount('services');

        if ($request->boolean('active_only')) {
            $query->where('is_active', true);
        }

        // Tanpa pagination — halaman Master + Buat Order butuh semua
        // kategori. Backend hanya return is_active=true by default
        // kecuali caller pass active_only=false.
        $categories = $query->orderBy('sort_order')->orderBy('name')->get();

        return ApiResponse::success(
            ServiceCategoryResource::collection($categories),
            'Success'
        );
    }

    /**
     * POST /api/v1/master/service-categories
     */
    public function store(ServiceCategoryRequest $request)
    {
        $category = ServiceCategory::create($request->validated());

        return ApiResponse::success(
            new ServiceCategoryResource($category->load('icon:id,name,icon_path')),
            'Kategori berhasil dibuat',
            201
        );
    }

    /**
     * GET /api/v1/master/service-categories/{serviceCategory}
     */
    public function show(ServiceCategory $serviceCategory)
    {
        return ApiResponse::success(
            new ServiceCategoryResource(
                $serviceCategory->load(['icon:id,name,icon_path'])->loadCount('services')
            )
        );
    }

    /**
     * PUT/PATCH /api/v1/master/service-categories/{serviceCategory}
     */
    public function update(ServiceCategoryRequest $request, ServiceCategory $serviceCategory)
    {
        $serviceCategory->update($request->validated());

        return ApiResponse::success(
            new ServiceCategoryResource($serviceCategory->load('icon:id,name,icon_path')),
            'Kategori berhasil diupdate'
        );
    }

    /**
     * DELETE /api/v1/master/service-categories/{serviceCategory}
     */
    public function destroy(ServiceCategory $serviceCategory)
    {
        $serviceCategory->delete();

        return ApiResponse::success(null, 'Kategori berhasil dihapus');
    }
}