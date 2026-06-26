<?php

namespace App\Services;

use App\Models\Customer;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\OrderStatusLog;
use App\Models\Service;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class OrderService
{
    public function __construct(private readonly TicketGenerator $ticketGenerator) {}

    /**
     * Buat order baru + items + initial status log.
     * Items array: [{ service_id, qty, ... }, ...]
     */
    public function createOrder(
        int $tenantId,
        int $customerId,
        int $createdBy,
        array $items,
        ?string $notes = null,
        float $discount = 0,
    ): Order {
        return DB::transaction(function () use ($tenantId, $customerId, $createdBy, $items, $notes, $discount) {
            // Validate customer
            $customer = Customer::query()
                ->where('id', $customerId)
                ->where('tenant_id', $tenantId)
                ->firstOrFail();

            // Resolve services
            $services = Service::query()
                ->whereIn('id', collect($items)->pluck('service_id'))
                ->where('tenant_id', $tenantId)
                ->get()
                ->keyBy('id');

            if ($services->count() !== count(array_unique(array_column($items, 'service_id')))) {
                throw new RuntimeException('Satu atau lebih service tidak ditemukan / tidak aktif.');
            }

            // Build items + hitung subtotal
            $subtotal = 0;
            $maxDuration = 0;
            $itemsToInsert = [];

            foreach ($items as $item) {
                $service = $services[$item['service_id']];

                if (!$service->is_active) {
                    throw new RuntimeException("Service '{$service->name}' tidak aktif.");
                }

                $qty     = (float) ($item['qty'] ?? 1);
                $price   = (float) $service->price;
                $lineSubtotal = $qty * $price;
                $subtotal += $lineSubtotal;

                $maxDuration = max($maxDuration, (int) $service->duration_hours);

                $itemsToInsert[] = [
                    'tenant_id'    => $tenantId,
                    'service_id'   => $service->id,
                    'service_name' => $service->name,
                    'unit'         => $service->unit,
                    'price'        => $price,
                    'qty'          => $qty,
                    'subtotal'     => $lineSubtotal,
                ];
            }

            $total = $subtotal - $discount;

            // Create order
            $order = Order::create([
                'tenant_id'            => $tenantId,
                'customer_id'          => $customer->id,
                'created_by'           => $createdBy,
                'ticket_number'        => $this->ticketGenerator->generate($tenantId),
                'notes'                => $notes,
                'status'               => Order::STATUS_MASUK,
                'subtotal'             => $subtotal,
                'discount'             => $discount,
                'total'                => $total,
                'estimated_finish_at'  => now()->addHours($maxDuration),
            ]);

            // Create items
            foreach ($itemsToInsert as &$row) {
                $row['order_id'] = $order->id;
            }
            OrderItem::insert($itemsToInsert);

            // Initial status log
            OrderStatusLog::create([
                'tenant_id'  => $tenantId,
                'order_id'   => $order->id,
                'status'     => Order::STATUS_MASUK,
                'note'       => 'Order dibuat',
                'changed_by' => $createdBy,
                'created_at' => now(),
            ]);

            // Update customer counters
            $customer->increment('total_orders');
            $customer->increment('total_spent', $total);

            return $order->fresh(['items', 'customer', 'creator']);
        });
    }

    /**
     * Update status order dengan validasi pipeline + log.
     */
    public function updateStatus(
        Order $order,
        string $newStatus,
        int $changedBy,
        ?string $note = null,
        ?string $cancelReason = null,
    ): Order {
        return DB::transaction(function () use ($order, $newStatus, $changedBy, $note, $cancelReason) {
            if ($order->status === $newStatus) {
                throw new RuntimeException("Order sudah berstatus {$newStatus}");
            }

            if (!$order->canTransitionTo($newStatus)) {
                throw new RuntimeException(
                    "Transisi status '{$order->status}' → '{$newStatus}' tidak diizinkan."
                );
            }

            // Update timestamp sesuai status
            $update = ['status' => $newStatus];

            if ($newStatus === Order::STATUS_SELESAI) {
                $update['finished_at'] = now();
            } elseif ($newStatus === Order::STATUS_DIAMBIL) {
                $update['picked_up_at'] = now();
            } elseif ($newStatus === Order::STATUS_DIBATALKAN) {
                $update['cancelled_at']  = now();
                $update['cancel_reason'] = $cancelReason;
            }

            $order->update($update);

            OrderStatusLog::create([
                'tenant_id'  => $order->tenant_id,
                'order_id'   => $order->id,
                'status'     => $newStatus,
                'note'       => $note ?? $cancelReason,
                'changed_by' => $changedBy,
                'created_at' => now(),
            ]);

            return $order->fresh();
        });
    }
}