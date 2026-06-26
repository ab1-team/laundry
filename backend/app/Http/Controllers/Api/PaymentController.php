<?php

namespace App\Http\Controllers\Api;

use App\Helpers\ApiResponse;
use App\Http\Controllers\Controller;
use App\Http\Requests\PaymentRequest;
use App\Http\Resources\OrderResource;
use App\Http\Resources\PaymentResource;
use App\Models\Order;
use App\Models\Payment;
use App\Services\PaymentService;
use Carbon\Carbon;
use Illuminate\Http\Request;

class PaymentController extends Controller
{
    public function __construct(private readonly PaymentService $paymentService) {}

    /**
     * GET /api/v1/orders/{order}/payments
     */
    public function index(Order $order)
    {
        $payments = $order->payments()
            ->with('recordedByUser:id,name')
            ->orderBy('paid_at')
            ->get();

        return ApiResponse::success([
            'order'         => [
                'id'           => $order->id,
                'ticket_number'=> $order->ticket_number,
                'total'        => (float) $order->total,
            ],
            'total_paid'    => (float) $order->totalPaid(),
            'remaining'     => (float) $order->remaining(),
            'is_paid'       => $order->isPaid(),
            'payments'      => PaymentResource::collection($payments),
        ]);
    }

    /**
     * POST /api/v1/orders/{order}/payments
     */
    public function store(PaymentRequest $request, Order $order)
    {
        try {
            $payment = $this->paymentService->recordPayment(
                order:      $order,
                amount:     (float) $request->input('amount'),
                method:     $request->input('method'),
                recordedBy: $request->user()->id,
                note:       $request->input('note'),
                paidAt:     $request->input('paid_at') ? Carbon::parse($request->input('paid_at')) : null,
            );
        } catch (\RuntimeException $e) {
            return ApiResponse::error($e->getMessage(), 422);
        }

        $payment->load('recordedByUser:id,name');

        return ApiResponse::success(
            new PaymentResource($payment),
            'Pembayaran berhasil dicatat',
            201
        );
    }

    /**
     * GET /api/v1/payments
     * Daftar semua payment per tenant (riwayat transaksi).
     */
    public function all(Request $request)
    {
        $query = Payment::query()
            ->with(['order:id,ticket_number,total,customer_id', 'order.customer:id,name,phone', 'recordedByUser:id,name']);

        if ($method = $request->query('method')) {
            $query->where('method', $method);
        }

        if ($from = $request->query('date_from')) {
            $query->whereDate('paid_at', '>=', $from);
        }
        if ($to = $request->query('date_to')) {
            $query->whereDate('paid_at', '<=', $to);
        }

        if ($customerId = $request->query('customer_id')) {
            $query->whereHas('order', fn ($q) => $q->where('customer_id', $customerId));
        }

        $payments = $query->orderByDesc('paid_at')->paginate(20);

        return ApiResponse::paginated($payments, PaymentResource::class);
    }

    /**
     * GET /api/v1/piutang
     * Daftar order yang belum lunas (remaining > 0).
     * Exclude order yang dibatalkan.
     */
    public function piutang(Request $request)
    {
        $orders = Order::query()
            ->with(['customer:id,name,phone', 'payments'])
            ->where('status', '!=', Order::STATUS_DIBATALKAN)
            ->orderByDesc('created_at')
            ->get()
            ->filter(fn ($order) => $order->remaining() > 0)
            ->map(function ($order) {
                return [
                    'order_id'              => $order->id,
                    'ticket_number'         => $order->ticket_number,
                    'status'                => $order->status,
                    'customer'              => [
                        'id'    => $order->customer->id,
                        'name'  => $order->customer->name,
                        'phone' => $order->customer->phone,
                    ],
                    'total'                 => (float) $order->total,
                    'total_paid'            => (float) $order->totalPaid(),
                    'remaining'             => (float) $order->remaining(),
                    'created_at'            => $order->created_at?->toISOString(),
                    'estimated_finish_at'   => $order->estimated_finish_at?->toISOString(),
                ];
            })
            ->values();

        $totalPiutang = $orders->sum('remaining');

        return ApiResponse::success([
            'summary' => [
                'total_orders'  => $orders->count(),
                'total_piutang' => (float) $totalPiutang,
            ],
            'orders'  => $orders,
        ], 'Daftar piutang');
    }

    /**
     * DELETE /api/v1/orders/{order}/payments/{payment}
     * Hanya owner / super_admin. Hapus payment (misal salah input).
     */
    public function destroy(Request $request, Order $order, Payment $payment)
    {
        if (!$request->user()->isOwner() && !$request->user()->isSuperAdmin()) {
            return ApiResponse::error('Hanya owner yang boleh menghapus payment.', 403);
        }

        if ($payment->order_id !== $order->id) {
            return ApiResponse::error('Payment tidak terkait dengan order ini.', 422);
        }

        $payment->delete();

        return ApiResponse::success(null, 'Payment berhasil dihapus');
    }
}