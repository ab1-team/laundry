<?php

namespace App\Services;

use App\Jobs\SendWaNotificationJob;
use App\Models\Customer;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\OrderStatusLog;
use App\Models\Service;
use App\Models\Tenant;
use App\Models\WaNotification;
use App\Services\EvolutionService;
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

            // Trigger WA notif untuk status awal 'masuk' di luar transaction
            // (afterCommit) — supaya kalau rollback, notif tidak terkirim.
            // Default `notify_on` include 'masuk' (lihat Tenant::waNotifyOn)
            // supaya owner yang belum customize tetap dapat notif order baru.
            DB::afterCommit(function () use ($order) {
                $this->maybeNotifyWa($order->fresh(), Order::STATUS_MASUK, 'Order dibuat');
            });

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

            // Diluar transaction supaya job jalan setelah commit DB.
            // Tapi karena ini nested dalam DB::transaction, gunakan afterCommit().
            DB::afterCommit(function () use ($order, $newStatus, $note) {
                $this->maybeNotifyWa($order->fresh(), $newStatus, $note);
            });

            return $order->fresh();
        });
    }

    /**
     * Cek opt-in/out tenant lalu enqueue job kirim WA.
     * Dipanggil via DB::afterCommit supaya notif tidak terkirim kalau
     * transaction rollback.
     */
    private function maybeNotifyWa(Order $order, string $newStatus, ?string $note): void
    {
        try {
            $tenant = Tenant::query()->find($order->tenant_id);
            if (!$tenant || !$tenant->waEnabled()) {
                return;
            }
            if (!in_array($newStatus, $tenant->waNotifyOn(), true)) {
                return;
            }

            $customer = $order->customer;
            if (!$customer || empty($customer->phone)) {
                return;
            }

            $statusLabel = self::statusLabel($newStatus);

            // Build $vars dengan key ber-brace — EvolutionService::renderTemplate
            // pakai strtr, dan strtr abaikan key yang gak ada di $vars (token
            // unknown left literal). Tetap declare semua kemungkinan var
            // termasuk null supaya fallback eksplisit (lihat format rules
            // di bawah) dan template tidak nge-render "{var_name}".
            $message = EvolutionService::renderForTenant($tenant, $newStatus, [
                '{tenant_name}'        => $tenant->name,
                '{ticket_number}'      => $order->ticket_number,
                '{status_label}'       => $statusLabel,
                '{notes}'              => $note ?? '',
                '{customer_name}'      => $customer->name ?? '',
                '{order_total}'        => $order->total !== null
                    ? 'Rp ' . number_format((float) $order->total, 0, ',', '.')
                    : 'Rp -',
                '{estimated_ready_at}' => $order->estimated_finish_at?->format('d M Y H:i') ?? '',
            ]);

            $notif = WaNotification::create([
                'tenant_id'   => $tenant->id,
                'order_id'    => $order->id,
                'customer_id' => $customer->id,
                'phone'       => $customer->phone,
                'message'     => $message,
                'status'      => WaNotification::STATUS_PENDING,
            ]);

            SendWaNotificationJob::dispatch($notif->id);
        } catch (\Throwable $e) {
            // Jangan sampai error WA menggagalkan order update — log saja.
            \Log::warning('WA notification enqueue gagal', [
                'order_id' => $order->id,
                'error'    => $e->getMessage(),
            ]);
        }
    }

    /**
     * Indonesian label untuk status order. Dipakai backend untuk template
     * WA dan di-export ke mobile (lihat `mobile/lib/core/wa/wa_status_labels.dart`)
     * sebagai single source of truth. Tambahkan status baru = update kedua sisi.
     */
    public static function statusLabel(string $status): string
    {
        return match ($status) {
            Order::STATUS_MASUK      => 'Diterima',
            Order::STATUS_DICUCI     => 'Sedang Dicuci',
            Order::STATUS_SELESAI    => 'Selesai',
            Order::STATUS_DIAMBIL    => 'Sudah Diambil',
            Order::STATUS_DIBATALKAN => 'Dibatalkan',
            default                  => $status,
        };
    }
}