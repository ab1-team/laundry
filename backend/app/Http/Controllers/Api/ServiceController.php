<?php

namespace App\Http\Controllers\Api;

use App\Helpers\ApiResponse;
use App\Http\Controllers\Controller;
use App\Http\Requests\ServiceRequest;
use App\Http\Resources\ServiceResource;
use App\Models\Service;
use Illuminate\Http\Request;

class ServiceController extends Controller
{
    /**
     * GET /api/v1/master/services
     */
    public function index(Request $request)
    {
        $query = Service::query()->with('category:id,name,icon,sort_order');

        // Filter by category
        if ($categoryId = $request->query('category_id')) {
            $query->where('category_id', $categoryId);
        }

        // Filter active
        if ($request->boolean('active_only')) {
            $query->where('is_active', true);
        }

        // Search
        if ($search = $request->query('search')) {
            $query->where('name', 'like', "%{$search}%");
        }

        // Order by category display order (ascending) so the operator sees
        // categories in the same order they configured in Master Data.
        // Join category table because sort_order lives there. Then order
        // by category_id so services inside the same category stick
        // together, and finally by name for a deterministic tie-breaker.
        $services = $query
            ->join('service_categories', 'services.category_id', '=', 'service_categories.id')
            ->orderBy('service_categories.sort_order')
            ->orderBy('services.category_id')
            ->orderBy('services.name')
            ->select('services.*')
            ->paginate(20);

        return ApiResponse::paginated($services, ServiceResource::class);
    }

    /**
     * POST /api/v1/master/services
     */
    public function store(ServiceRequest $request)
    {
        $service = Service::create($request->validated());

        return ApiResponse::success(
            new ServiceResource($service->load('category:id,name,icon')),
            'Layanan berhasil dibuat',
            201
        );
    }

    /**
     * GET /api/v1/master/services/{service}
     */
    public function show(Service $service)
    {
        return ApiResponse::success(
            new ServiceResource($service->load('category:id,name,icon'))
        );
    }

    /**
     * PUT/PATCH /api/v1/master/services/{service}
     */
    public function update(ServiceRequest $request, Service $service)
    {
        $service->update($request->validated());

        return ApiResponse::success(
            new ServiceResource($service->load('category:id,name,icon')),
            'Layanan berhasil diupdate'
        );
    }

    /**
     * DELETE /api/v1/master/services/{service}
     */
    public function destroy(Service $service)
    {
        $service->delete();

        return ApiResponse::success(null, 'Layanan berhasil dihapus');
    }
}