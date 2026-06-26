<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CustomerResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'            => $this->id,
            'tenant_id'     => $this->tenant_id,
            'name'          => $this->name,
            'phone'         => $this->phone,
            'address'       => $this->address,
            'notes'         => $this->notes,
            'total_orders'  => (int) $this->total_orders,
            'total_spent'   => (float) $this->total_spent,
            'created_at'    => $this->created_at?->toISOString(),
            'updated_at'    => $this->updated_at?->toISOString(),
        ];
    }
}
