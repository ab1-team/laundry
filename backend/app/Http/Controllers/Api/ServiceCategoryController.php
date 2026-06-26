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
        $query = ServiceCategory::query()->withCount('services');

        if ($request->boolean('active_only')) {
            $query->where('is_active', true);
        }

        $categories = $query->orderBy('sort_order')->orderBy('name')->paginate(20);

        return ApiResponse::paginated($categories, ServiceCategoryResource::class);
    }

    /**
     * POST /api/v1/master/service-categories
     */
    public function store(ServiceCategoryRequest $request)
    {
        $category = ServiceCategory::create($request->validated());

        return ApiResponse::success(
            new ServiceCategoryResource($category),
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
            new ServiceCategoryResource($serviceCategory->loadCount('services'))
        );
    }

    /**
     * PUT/PATCH /api/v1/master/service-categories/{serviceCategory}
     */
    public function update(ServiceCategoryRequest $request, ServiceCategory $serviceCategory)
    {
        $serviceCategory->update($request->validated());

        return ApiResponse::success(
            new ServiceCategoryResource($serviceCategory),
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