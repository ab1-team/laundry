<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class OrderItemResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'           => $this->id,
            'order_id'     => $this->order_id,
            'service_id'   => $this->service_id,
            'service_name' => $this->service_name,
            'unit'         => $this->unit,
            'price'        => $this->price,
            'qty'          => $this->qty,
            'subtotal'     => $this->subtotal,
            'category'     => $this->whenLoaded('service.category', fn () => [
                'id'    => $this->service->category->id,
                'name'  => $this->service->category->name,
                'icon'  => $this->service->category->icon,
            ]),
        ];
    }
}