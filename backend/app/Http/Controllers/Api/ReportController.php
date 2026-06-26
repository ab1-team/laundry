<?php

namespace App\Http\Controllers\Api;

use App\Helpers\ApiResponse;
use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Payment;
use App\Services\ReportService;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ReportController extends Controller
{
    public function __construct(private readonly ReportService $reportService) {}

    /**
     * GET /api/v1/reports/dashboard
     * Ringkasan untuk landing page owner.
     */
    public function dashboard(Request $request)
    {
        $tenantId = $request->user()->tenant_id;
        return ApiResponse::success($this->reportService->dashboard($tenantId));
    }

    /**
     * GET /api/v1/reports/income/daily?from=2026-06-01&to=2026-06-30
     */
    public function dailyIncome(Request $request)
    {
        $tenantId = $request->user()->tenant_id;
        $data = $this->reportService->dailyIncome(
            $tenantId,
            $request->query('from'),
            $request->query('to'),
        );
        return ApiResponse::success($data);
    }

    /**
     * GET /api/v1/reports/income/monthly
     * 12 bulan terakhir.
     */
    public function monthlyIncome(Request $request)
    {
        $tenantId = $request->user()->tenant_id;
        $data = $this->reportService->monthlyIncome($tenantId);
        return ApiResponse::success($data);
    }

    /**
     * GET /api/v1/reports/income/weekly
     * 12 minggu terakhir.
     */
    public function weeklyIncome(Request $request)
    {
        $tenantId = $request->user()->tenant_id;
        $data = $this->reportService->weeklyIncome($tenantId);
        return ApiResponse::success($data);
    }

    /**
     * GET /api/v1/reports/services?from=...&to=...
     */
    public function services(Request $request)
    {
        $tenantId = $request->user()->tenant_id;
        $data = $this->reportService->servicesReport(
            $tenantId,
            $request->query('from'),
            $request->query('to'),
        );
        return ApiResponse::success($data);
    }

    /**
     * GET /api/v1/reports/piutang
     */
    public function piutang(Request $request)
    {
        $tenantId = $request->user()->tenant_id;
        $data = $this->reportService->piutangSummary($tenantId);
        return ApiResponse::success($data);
    }

    /**
     * GET /api/v1/reports/export/orders?from=...&to=...
     * Export orders ke CSV.
     */
    public function exportOrders(Request $request): StreamedResponse
    {
        $tenantId = $request->user()->tenant_id;
        $from = $request->query('from') ? \Carbon\Carbon::parse($request->query('from'))->startOfDay() : now()->subDays(30);
        $to   = $request->query('to')   ? \Carbon\Carbon::parse($request->query('to'))->endOfDay()   : now();

        $filename = "orders_{$from->toDateString()}_{$to->toDateString()}.csv";

        $headers = [
            'Content-Type'        => 'text/csv; charset=UTF-8',
            'Content-Disposition' => "attachment; filename=\"{$filename}\"",
        ];

        return response()->stream(function () use ($tenantId, $from, $to) {
            $out = fopen('php://output', 'w');
            fwrite($out, "\xEF\xBB\xBF"); // BOM for Excel UTF-8

            fputcsv($out, ['Ticket', 'Tanggal', 'Customer', 'Phone', 'Status', 'Subtotal', 'Discount', 'Total', 'Paid', 'Remaining', 'Notes']);

            Order::query()
                ->where('tenant_id', $tenantId)
                ->whereBetween('created_at', [$from, $to])
                ->with('customer:id,name,phone')
                ->orderBy('created_at')
                ->chunk(100, function ($orders) use ($out) {
                    foreach ($orders as $order) {
                        $totalPaid = (float) $order->totalPaid();
                        fputcsv($out, [
                            $order->ticket_number,
                            $order->created_at?->toDateTimeString(),
                            $order->customer?->name,
                            $order->customer?->phone,
                            $order->status,
                            $order->subtotal,
                            $order->discount,
                            $order->total,
                            $totalPaid,
                            (float) $order->total - $totalPaid,
                            $order->notes,
                        ]);
                    }
                });

            fclose($out);
        }, 200, $headers);
    }

    /**
     * GET /api/v1/reports/export/payments?from=...&to=...
     * Export payments ke CSV.
     */
    public function exportPayments(Request $request): StreamedResponse
    {
        $tenantId = $request->user()->tenant_id;
        $from = $request->query('from') ? \Carbon\Carbon::parse($request->query('from'))->startOfDay() : now()->subDays(30);
        $to   = $request->query('to')   ? \Carbon\Carbon::parse($request->query('to'))->endOfDay()   : now();

        $filename = "payments_{$from->toDateString()}_{$to->toDateString()}.csv";

        $headers = [
            'Content-Type'        => 'text/csv; charset=UTF-8',
            'Content-Disposition' => "attachment; filename=\"{$filename}\"",
        ];

        return response()->stream(function () use ($tenantId, $from, $to) {
            $out = fopen('php://output', 'w');
            fwrite($out, "\xEF\xBB\xBF");

            fputcsv($out, ['Tanggal', 'Ticket', 'Customer', 'Method', 'Amount', 'Note', 'Recorded By']);

            Payment::query()
                ->where('tenant_id', $tenantId)
                ->whereBetween('paid_at', [$from, $to])
                ->with(['order:id,ticket_number,customer_id', 'order.customer:id,name', 'recordedByUser:id,name'])
                ->orderBy('paid_at')
                ->chunk(100, function ($payments) use ($out) {
                    foreach ($payments as $payment) {
                        fputcsv($out, [
                            $payment->paid_at?->toDateTimeString(),
                            $payment->order?->ticket_number,
                            $payment->order?->customer?->name,
                            $payment->method,
                            $payment->amount,
                            $payment->note,
                            $payment->recordedByUser?->name,
                        ]);
                    }
                });

            fclose($out);
        }, 200, $headers);
    }
}