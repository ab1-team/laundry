<?php

namespace App\Http\Controllers\Api;

use App\Helpers\ApiResponse;
use App\Http\Controllers\Controller;
use App\Http\Requests\OrderRequest;
use App\Http\Requests\OrderStatusRequest;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use App\Services\OrderService;
use Illuminate\Http\Request;

class OrderController extends Controller
{
    public function __construct(private readonly OrderService $orderService) {}

    /**
     * GET /api/v1/orders
     */
    public function index(Request $request)
    {
        $query = Order::query()
            // Eager-load items + service.category so OrderItemResource
            // can emit `category.icon` and the mobile Daftar Order card
            // can render the middle row (qty + service name). Without
            // this, `items` is omitted from the JSON (whenLoaded) and
            // the card falls back to a 3-line layout that drops the
            // qty/service info from the design.
            ->with(['customer:id,name,phone', 'creator:id,name', 'items.service.category']);

        // Filter by status
        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        // Filter by customer
        if ($customerId = $request->query('customer_id')) {
            $query->where('customer_id', $customerId);
        }

        // Date range
        if ($from = $request->query('date_from')) {
            $query->whereDate('created_at', '>=', $from);
        }
        if ($to = $request->query('date_to')) {
            $query->whereDate('created_at', '<=', $to);
        }

        // Search by ticket
        if ($search = $request->query('search')) {
            $query->where('ticket_number', 'like', "%{$search}%");
        }

        // Grouped: aktif vs history
        if ($request->query('group') === 'active') {
            $query->whereIn('status', [
                Order::STATUS_MASUK,
                Order::STATUS_DICUCI,
                Order::STATUS_SELESAI,
            ]);
        } elseif ($request->query('group') === 'history') {
            $query->whereIn('status', [
                Order::STATUS_DIAMBIL,
                Order::STATUS_DIBATALKAN,
            ]);
        }

        // Outstanding-balance filter: only orders that still owe money,
        // regardless of pipeline status. Lets the operator surface
        // unpaid orders (e.g. `diambil` but not yet settled) without
        // scanning the whole active list. `remaining` is a computed
        // value (total - sum of payments), so we use a correlated
        // subquery against the payments table. Applied in SQL so the
        // result survives Laravel's `paginate(20)`.
        //
        // Cancelled orders are excluded — a `dibatalkan` order shouldn't
        // show up in "Belum Lunas" regardless of any payment state.
        if ($request->boolean('unpaid')) {
            $query->where('status', '!=', Order::STATUS_DIBATALKAN)
                ->whereRaw(
                    'orders.total - (' .
                    'SELECT COALESCE(SUM(amount), 0) FROM payments WHERE payments.order_id = orders.id' .
                    ') > 0'
                );
        }

        $orders = $query->orderByDesc('created_at')->paginate(20);

        return ApiResponse::paginated($orders, OrderResource::class);
    }

    /**
     * POST /api/v1/orders
     */
    public function store(OrderRequest $request)
    {
        try {
            $order = $this->orderService->createOrder(
                tenantId:   $request->user()->tenant_id,
                customerId: $request->integer('customer_id'),
                createdBy:  $request->user()->id,
                items:      $request->input('items'),
                notes:      $request->input('notes'),
                discount:   (float) $request->input('discount', 0),
            );
        } catch (\RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), 422);
        }

        return ApiResponse::success(
            new OrderResource($order),
            'Order berhasil dibuat',
            201
        );
    }

    /**
     * GET /api/v1/orders/{order}
     */
    public function show(Order $order)
    {
        $order->load(['customer:id,name,phone', 'creator:id,name', 'items.service.category', 'statusLogs.changedByUser:id,name']);

        return ApiResponse::success(new OrderResource($order));
    }

    /**
     * PATCH /api/v1/orders/{order}/status
     */
    public function updateStatus(OrderStatusRequest $request, Order $order)
    {
        try {
            $updated = $this->orderService->updateStatus(
                order:         $order,
                newStatus:     $request->input('status'),
                changedBy:     $request->user()->id,
                note:          $request->input('note'),
                cancelReason:  $request->input('cancel_reason'),
            );
        } catch (\RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), 422);
        }

        $updated->load(['customer:id,name,phone', 'creator:id,name', 'items.service.category', 'statusLogs.changedByUser:id,name']);

        return ApiResponse::success(
            new OrderResource($updated),
            'Status order berhasil diupdate'
        );
    }

    /**
     * DELETE /api/v1/orders/{order}
     * Hard delete (only if status = dibatalkan). Owner only.
     */
    public function destroy(Request $request, Order $order)
    {
        if (!$request->user()->isOwner() && !$request->user()->isSuperAdmin()) {
            return ApiResponse::error('Hanya owner yang boleh menghapus order.', 403);
        }

        if ($order->status !== Order::STATUS_DIBATALKAN) {
            return ApiResponse::error('Order hanya bisa dihapus jika status dibatalkan.', 422);
        }

        $order->delete();

        return ApiResponse::success(null, 'Order berhasil dihapus');
    }
}