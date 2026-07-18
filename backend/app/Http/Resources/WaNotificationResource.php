<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class WaNotificationResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'           => $this->id,
            'tenant_id'    => $this->tenant_id,
            'order_id'     => $this->order_id,
            'customer_id'  => $this->customer_id,
            'phone'        => $this->phone,
            'message'      => $this->message,
            'status'       => $this->status,
            'sent_at'      => $this->sent_at?->toISOString(),
            'error'        => $this->error,
            'created_at'   => $this->created_at?->toISOString(),
            'updated_at'   => $this->updated_at?->toISOString(),
        ];
    }
}
