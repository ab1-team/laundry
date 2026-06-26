<?php

namespace App\Http\Controllers\Api;

use App\Helpers\ApiResponse;
use App\Http\Controllers\Controller;
use App\Http\Requests\CustomerRequest;
use App\Http\Resources\CustomerResource;
use App\Models\Customer;
use Illuminate\Http\Request;

class CustomerController extends Controller
{
    /**
     * GET /api/v1/customers
     */
    public function index(Request $request)
    {
        $query = Customer::query();

        // Search by name or phone
        if ($search = $request->query('search')) {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('phone', 'like', "%{$search}%");
            });
        }

        $customers = $query->orderBy('name')->paginate(20);

        return ApiResponse::paginated($customers, CustomerResource::class);
    }

    /**
     * POST /api/v1/customers
     */
    public function store(CustomerRequest $request)
    {
        $customer = Customer::create($request->validated());

        return ApiResponse::success(
            new CustomerResource($customer),
            'Customer berhasil ditambahkan',
            201
        );
    }

    /**
     * GET /api/v1/customers/{customer}
     */
    public function show(Customer $customer)
    {
        return ApiResponse::success(new CustomerResource($customer));
    }

    /**
     * PUT/PATCH /api/v1/customers/{customer}
     */
    public function update(CustomerRequest $request, Customer $customer)
    {
        $customer->update($request->validated());

        return ApiResponse::success(
            new CustomerResource($customer),
            'Customer berhasil diupdate'
        );
    }

    /**
     * DELETE /api/v1/customers/{customer}
     */
    public function destroy(Customer $customer)
    {
        $customer->delete();

        return ApiResponse::success(null, 'Customer berhasil dihapus');
    }

    /**
     * GET /api/v1/customers/{customer}/orders
     * Order history per customer — returns empty array untuk sekarang
     * (akan di-populate di Fase 3)
     */
    public function orders(Customer $customer)
    {
        return ApiResponse::success([
            'customer' => new CustomerResource($customer),
            'orders'   => [],
        ], 'Riwayat order (Fase 3)');
    }
}