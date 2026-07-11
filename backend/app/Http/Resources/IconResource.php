<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class IconResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'         => $this->id,
            'tenant_id'  => $this->tenant_id,
            'name'       => $this->name,
            'icon_path'  => $this->icon_path,
            // Relative URL — frontend concatenate dengan API host origin
            // (resolveAssetUrl di mobile/lib/core/network/asset_url.dart).
            // Pola sama dengan TenantResource::logo_url.
            'icon_url'   => $this->icon_url,
            'is_active'  => $this->is_active,
            'created_at' => $this->created_at?->toISOString(),
            'updated_at' => $this->updated_at?->toISOString(),
        ];
    }
}