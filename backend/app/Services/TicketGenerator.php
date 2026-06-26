<?php

namespace App\Services;

use App\Models\Order;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;

class TicketGenerator
{
    /**
     * Generate ticket number dengan format LND-YYYYMMDD-XXXX
     * Counter di-reset setiap hari, unique per tenant.
     */
    public function generate(int $tenantId): string
    {
        $today = Carbon::today();
        $prefix = 'LND-' . $today->format('Ymd') . '-';

        // Global counter — ticket_number is unique across all tenants per migration.
        // Bypass tenant global scope via withoutGlobalScope.
        $count = DB::transaction(function () use ($today) {
            return Order::query()
                ->withoutGlobalScope('tenant')
                ->whereDate('created_at', $today)
                ->lockForUpdate()
                ->count() + 1;
        });

        return $prefix . str_pad((string) $count, 4, '0', STR_PAD_LEFT);
    }
}