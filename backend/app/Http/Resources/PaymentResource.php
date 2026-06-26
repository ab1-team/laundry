<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PaymentResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'           => $this->id,
            'tenant_id'    => $this->tenant_id,
            'order_id'     => $this->order_id,
            'amount'       => $this->amount,
            'method'       => $this->method,
            'note'         => $this->note,
            'paid_at'      => $this->paid_at?->toISOString(),
            'recorded_by'  => $this->recorded_by,
            'recorded_by_name' => $this->whenLoaded('recordedByUser', fn () => $this->recordedByUser->name),
            'created_at'   => $this->created_at?->toISOString(),
        ];
    }
}