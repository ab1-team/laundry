<?php

namespace App\Services;

use App\Models\Order;
use App\Models\Payment;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class PaymentService
{
    /**
     * Catat pembayaran untuk order. Validasi order milik tenant,
     * order tidak boleh dibatalkan, dan pembayaran tidak boleh melebihi sisa.
     */
    public function recordPayment(
        Order $order,
        float $amount,
        string $method,
        int $recordedBy,
        ?string $note = null,
        ?\DateTimeInterface $paidAt = null,
    ): Payment {
        return DB::transaction(function () use ($order, $amount, $method, $recordedBy, $note, $paidAt) {
            if ($order->status === Order::STATUS_DIBATALKAN) {
                throw new RuntimeException('Tidak bisa mencatat pembayaran untuk order yang dibatalkan.');
            }

            $remaining = $order->remaining();

            if ($amount > $remaining) {
                throw new RuntimeException(
                    "Jumlah pembayaran (Rp " . number_format($amount, 0, ',', '.') .
                    ") melebihi sisa tagihan (Rp " . number_format($remaining, 0, ',', '.') . ")."
                );
            }

            return Payment::create([
                'tenant_id'   => $order->tenant_id,
                'order_id'    => $order->id,
                'amount'      => $amount,
                'method'      => $method,
                'note'        => $note,
                'paid_at'     => $paidAt ?? now(),
                'recorded_by' => $recordedBy,
            ]);
        });
    }
}