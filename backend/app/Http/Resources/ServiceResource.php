<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ServiceResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'             => $this->id,
            'tenant_id'      => $this->tenant_id,
            'category_id'    => $this->category_id,
            'category'       => $this->whenLoaded('category', fn () => new ServiceCategoryResource($this->category)),
            // Icon milik layanan sendiri (override kategori.icon kalau
            // di-set) — kalau null, frontend fallback ke category.icon.
            'icon_id'        => $this->icon_id,
            'icon'           => $this->whenLoaded('icon', fn () => new IconResource($this->icon)),
            'name'           => $this->name,
            'price'          => $this->price,
            'unit'           => $this->unit,
            'duration_hours' => $this->duration_hours,
            'is_active'      => $this->is_active,
            'created_at'     => $this->created_at?->toISOString(),
            'updated_at'     => $this->updated_at?->toISOString(),
        ];
    }
}
