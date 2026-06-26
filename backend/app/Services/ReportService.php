<?php

namespace App\Services;

use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Payment;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;

class ReportService
{
    /**
     * Indonesian month names indexed 1-12. Used by monthlyIncome and
     * weeklyIncome to format period labels in a way the operator can
     * actually read, sidestepping the inconsistent id_ID translations
     * produced by Carbon on this server.
     */
    private const MONTH_NAMES_ID = [
        1  => 'Januari',
        2  => 'Februari',
        3  => 'Maret',
        4  => 'April',
        5  => 'Mei',
        6  => 'Juni',
        7  => 'Juli',
        8  => 'Agustus',
        9  => 'September',
        10 => 'Oktober',
        11 => 'November',
        12 => 'Desember',
    ];

    // Short labels used in the PDF table where horizontal space is
    // tight ("Mei", "Jun") — long names ("Mei", "Juni") would wrap.
    private const MONTH_NAMES_SHORT_ID = [
        1  => 'Jan', 2  => 'Feb', 3  => 'Mar', 4  => 'Apr',
        5  => 'Mei', 6  => 'Jun', 7  => 'Jul', 8  => 'Agt',
        9  => 'Sep', 10 => 'Okt', 11 => 'Nov', 12 => 'Des',
    ];
    /**
     * Pendapatan per hari pada range tanggal (default: 7 hari terakhir).
     * Sum dari payments.paid_at, group by date.
     */
    public function dailyIncome(int $tenantId, ?string $from = null, ?string $to = null): array
    {
        $from = $from ? Carbon::parse($from) : Carbon::today()->subDays(6);
        $to   = $to   ? Carbon::parse($to)   : Carbon::today();

        $rows = Payment::query()
            ->where('tenant_id', $tenantId)
            ->whereBetween('paid_at', [$from->startOfDay(), $to->endOfDay()])
            ->selectRaw('DATE(paid_at) as date, SUM(amount) as total, COUNT(*) as transactions')
            ->groupBy('date')
            ->orderBy('date')
            ->get();

        // Isi tanggal yang tidak ada transaksi dengan 0
        $result = [];
        $cursor = $from->copy();
        while ($cursor->lte($to)) {
            $dateStr = $cursor->toDateString();
            $row = $rows->firstWhere('date', $dateStr);
            $result[] = [
                'date'         => $dateStr,
                // Owner-friendly day label: "24 Jun" (day + Indonesian
                // short month). Same Carbon-id_ID bug as monthly/weekly
                // forces us to look up the name ourselves.
                'date_label'   => $cursor->day . ' ' . self::MONTH_NAMES_SHORT_ID[$cursor->month],
                'total'        => (float) ($row->total ?? 0),
                'transactions' => (int) ($row->transactions ?? 0),
            ];
            $cursor->addDay();
        }

        return [
            'range' => [
                'from' => $from->toDateString(),
                'to'   => $to->toDateString(),
            ],
            'data'  => $result,
            'summary' => [
                'total_income'   => (float) array_sum(array_column($result, 'total')),
                'total_tx'       => (int) array_sum(array_column($result, 'transactions')),
                'average_daily'  => $result
                    ? (float) array_sum(array_column($result, 'total')) / count($result)
                    : 0.0,
            ],
        ];
    }

    /**
     * Pendapatan per bulan (12 bulan terakhir).
     */
    public function monthlyIncome(int $tenantId): array
    {
        $from = Carbon::today()->subMonths(11)->startOfMonth();
        $to   = Carbon::today()->endOfMonth();

        $rows = Payment::query()
            ->where('tenant_id', $tenantId)
            ->whereBetween('paid_at', [$from, $to])
            ->selectRaw('DATE_FORMAT(paid_at, "%Y-%m") as month, SUM(amount) as total, COUNT(*) as transactions')
            ->groupBy('month')
            ->orderBy('month')
            ->get();

        $result = [];
        $cursor = $from->copy();
        while ($cursor->lte($to)) {
            $month = $cursor->format('Y-m');
            $row = $rows->firstWhere('month', $month);
            $result[] = [
                'month'        => $month,
                // "Mei 2026" — Indonesian month name + year. Carbon's
                // translatedFormat with id_ID on this server produces
                // mixed Indonesian/English month names, so we hand-pick
                // the names here for a consistent label across reports.
                'month_label'  => self::MONTH_NAMES_ID[$cursor->month] . ' ' . $cursor->year,
                'total'        => (float) ($row->total ?? 0),
                'transactions' => (int) ($row->transactions ?? 0),
            ];
            $cursor->addMonth();
        }

        return [
            'range' => [
                'from' => $from->format('Y-m'),
                'to'   => $to->format('Y-m'),
            ],
            'data'  => $result,
            'summary' => [
                'total_income' => (float) array_sum(array_column($result, 'total')),
                'total_tx'     => (int) array_sum(array_column($result, 'transactions')),
            ],
        ];
    }

    /**
     * Pendapatan per minggu (5 minggu terakhir). Window yang konsisten
     * dengan skala period lain: Harian menampilkan 1 minggu terakhir,
     * Bulanan menampilkan 1 tahun terakhir, jadi Mingguan menampilkan
     * sekitar 1 bulan terakhir (5 minggu). Semua di-anchor ke Senin
     * sebagai awal minggu ISO supaya row tabel rapi.
     */
    public function weeklyIncome(int $tenantId): array
    {
        // 4 minggu sebelumnya + minggu ini = 5 minggu total.
        $from = Carbon::today()->startOfWeek()->subWeeks(4);
        $to   = Carbon::today()->endOfWeek();

        $rows = Payment::query()
            ->where('tenant_id', $tenantId)
            ->whereBetween('paid_at', [$from, $to])
            ->selectRaw('YEARWEEK(paid_at, 3) as yearweek, MIN(DATE(paid_at)) as week_start, SUM(amount) as total, COUNT(*) as transactions')
            ->groupBy('yearweek')
            ->orderBy('yearweek')
            ->get();

        $result = [];
        $cursor = $from->copy();
        while ($cursor->lte($to)) {
            // Mode 3 di YEARWEEK: ISO week, Senin sebagai hari pertama.
            $yw = $cursor->format('oW');
            $row = $rows->firstWhere('yearweek', (int) $yw);
            $result[] = [
                'week'         => $yw,
                'week_start'   => $cursor->toDateString(),
                // "06 Apr" — owner-friendly short label: day + Indonesian
                // month name. We hand-pick the month name (see
                // MONTH_NAMES_ID) because Carbon's translatedFormat with
                // id_ID on this server returns mixed-language output and
                // sometimes leaks the raw spec token ("AprilApril4").
                'week_label'   => $cursor->day . ' ' . self::MONTH_NAMES_ID[$cursor->month],
                'total'        => (float) ($row->total ?? 0),
                'transactions' => (int) ($row->transactions ?? 0),
            ];
            $cursor->addWeek();
        }

        return [
            'range' => [
                'from' => $from->toDateString(),
                'to'   => $to->toDateString(),
            ],
            'data'  => $result,
            'summary' => [
                'total_income' => (float) array_sum(array_column($result, 'total')),
                'total_tx'     => (int) array_sum(array_column($result, 'transactions')),
                'average_weekly' => $result
                    ? (float) array_sum(array_column($result, 'total')) / count($result)
                    : 0.0,
            ],
        ];
    }

    /**
     * Laporan per layanan: order count + revenue per service.
     * Range default: 30 hari terakhir.
     */
    public function servicesReport(int $tenantId, ?string $from = null, ?string $to = null): array
    {
        $from = $from ? Carbon::parse($from) : Carbon::today()->subDays(30);
        $to   = $to   ? Carbon::parse($to)   : Carbon::today();

        $rows = OrderItem::query()
            ->where('order_items.tenant_id', $tenantId)
            ->whereHas('order', fn ($q) => $q->whereBetween('orders.created_at', [$from->startOfDay(), $to->endOfDay()]))
            ->join('service_categories', 'service_categories.id', '=', 'order_items.service_id')
            ->leftJoin('services', 'services.id', '=', 'order_items.service_id')
            ->selectRaw('
                order_items.service_id,
                order_items.service_name,
                SUM(order_items.qty) as total_qty,
                SUM(order_items.subtotal) as total_revenue,
                COUNT(DISTINCT order_items.order_id) as order_count
            ')
            ->groupBy('order_items.service_id', 'order_items.service_name')
            ->orderByDesc('total_revenue')
            ->get();

        return [
            'range' => [
                'from' => $from->toDateString(),
                'to'   => $to->toDateString(),
            ],
            'data'  => $rows->map(fn ($r) => [
                'service_id'    => (int) $r->service_id,
                'service_name'  => $r->service_name,
                'total_qty'     => (float) $r->total_qty,
                'order_count'   => (int) $r->order_count,
                'total_revenue' => (float) $r->total_revenue,
            ]),
            'summary' => [
                'total_revenue'  => (float) $rows->sum('total_revenue'),
                'total_services' => (int) $rows->count(),
            ],
        ];
    }

    /**
     * Ringkasan piutang: total sisa tagihan, jumlah order belum lunas,
     * top customer berpiutang.
     */
    public function piutangSummary(int $tenantId): array
    {
        $orders = Order::query()
            ->where('tenant_id', $tenantId)
            ->where('status', '!=', Order::STATUS_DIBATALKAN)
            ->with(['customer:id,name,phone', 'payments'])
            ->get();

        $unpaid = $orders->filter(fn ($o) => $o->remaining() > 0);

        // Group by customer
        $byCustomer = $unpaid
            ->groupBy('customer_id')
            ->map(function ($items) {
                $customer = $items->first()->customer;
                $totalRemaining = $items->sum(fn ($o) => $o->remaining());
                return [
                    'customer'        => [
                        'id'    => $customer->id,
                        'name'  => $customer->name,
                        'phone' => $customer->phone,
                    ],
                    'order_count'     => (int) $items->count(),
                    'total_piutang'   => (float) $totalRemaining,
                ];
            })
            ->sortByDesc('total_piutang')
            ->values();

        return [
            'summary' => [
                'total_orders'   => (int) $unpaid->count(),
                'total_piutang'  => (float) $unpaid->sum(fn ($o) => $o->remaining()),
            ],
            'by_customer' => $byCustomer,
        ];
    }

    /**
     * Dashboard summary (untuk landing dashboard owner):
     * - order hari ini (count + revenue)
     * - order bulan ini
     * - piutang aktif
     * - order belum selesai
     */
    public function dashboard(int $tenantId): array
    {
        $today = Carbon::today();
        $monthStart = Carbon::today()->startOfMonth();

        // Order hari ini (by created_at)
        $todayOrders = Order::query()
            ->where('tenant_id', $tenantId)
            ->whereDate('created_at', $today)
            ->get();

        // Pendapatan hari ini (sum payments hari ini)
        $todayIncome = (float) Payment::query()
            ->where('tenant_id', $tenantId)
            ->whereDate('paid_at', $today)
            ->sum('amount');

        // Pendapatan bulan ini
        $monthIncome = (float) Payment::query()
            ->where('tenant_id', $tenantId)
            ->where('paid_at', '>=', $monthStart)
            ->sum('amount');

        // Order belum selesai (masuk/dicuci/selesai)
        $activeOrders = Order::query()
            ->where('tenant_id', $tenantId)
            ->whereIn('status', [Order::STATUS_MASUK, Order::STATUS_DICUCI, Order::STATUS_SELESAI])
            ->count();

        // Total piutang
        $piutang = Order::query()
            ->where('tenant_id', $tenantId)
            ->where('status', '!=', Order::STATUS_DIBATALKAN)
            ->with('payments')
            ->get()
            ->sum(fn ($o) => $o->remaining());

        // Top 5 layanan bulan ini
        $topServices = OrderItem::query()
            ->where('order_items.tenant_id', $tenantId)
            ->whereHas('order', fn ($q) => $q->where('orders.created_at', '>=', $monthStart))
            ->selectRaw('
                order_items.service_id,
                order_items.service_name,
                SUM(order_items.qty) as total_qty,
                SUM(order_items.subtotal) as total_revenue
            ')
            ->groupBy('order_items.service_id', 'order_items.service_name')
            ->orderByDesc('total_revenue')
            ->limit(5)
            ->get();

        return [
            'today' => [
                'order_count'    => (int) $todayOrders->count(),
                'income'         => $todayIncome,
            ],
            'this_month' => [
                'income' => $monthIncome,
            ],
            'active_orders'    => (int) $activeOrders,
            'total_piutang'    => (float) $piutang,
            'top_services'     => $topServices->map(fn ($r) => [
                'service_id'   => (int) $r->service_id,
                'service_name' => $r->service_name,
                'total_qty'    => (float) $r->total_qty,
                'revenue'      => (float) $r->total_revenue,
            ]),
        ];
    }
}