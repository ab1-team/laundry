<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class OrderResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'                    => $this->id,
            'tenant_id'             => $this->tenant_id,
            'customer_id'           => $this->customer_id,
            'customer'              => $this->whenLoaded('customer', fn () => new CustomerResource($this->customer)),
            'created_by'            => $this->created_by,
            'creator_name'          => $this->whenLoaded('creator', fn () => $this->creator->name),
            'ticket_number'         => $this->ticket_number,
            'notes'                 => $this->notes,
            'status'                => $this->status,
            'subtotal'              => $this->subtotal,
            'discount'              => $this->discount,
            'total'                 => $this->total,
            'estimated_finish_at'   => $this->estimated_finish_at?->toISOString(),
            'finished_at'           => $this->finished_at?->toISOString(),
            'picked_up_at'          => $this->picked_up_at?->toISOString(),
            'cancelled_at'          => $this->cancelled_at?->toISOString(),
            'cancel_reason'         => $this->cancel_reason,
            'items'                 => OrderItemResource::collection($this->whenLoaded('items')),
            'status_logs'           => OrderStatusLogResource::collection($this->whenLoaded('statusLogs')),
            'payments'              => PaymentResource::collection($this->whenLoaded('payments')),
            'total_paid'            => (float) $this->totalPaid(),
            'remaining'             => (float) $this->remaining(),
            'created_at'            => $this->created_at?->toISOString(),
            'updated_at'            => $this->updated_at?->toISOString(),
        ];
    }
}