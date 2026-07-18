<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TenantResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'             => $this->id,
            'name'           => $this->name,
            'slug'           => $this->slug,
            'phone'          => $this->phone,
            'address'        => $this->address,
            'city'           => $this->city,
            'logo_path'      => $this->logo_path,
            // Relative URL — frontend concatenates with the API host
            // (see ApiClient.baseUrl origin) so the same payload works for
            // web, local emulator, and physical devices on the LAN.
            'logo_url'       => $this->logo_path
                ? '/storage/' . ltrim($this->logo_path, '/')
                : null,
            'status'         => $this->status,
            'trial_ends_at'  => $this->trial_ends_at?->toISOString(),
            'activated_at'   => $this->activated_at?->toISOString(),
            'created_at'     => $this->created_at?->toISOString(),
            // Di-load via `?->loadCount('users')` — null jika tidak di-eager-load.
            'users_count'    => $this->whenCounted('users'),
            // WA gateway settings (Evolution API). Null jika belum diset.
            // Sensitive token (api_key) tidak pernah ada di sini — hanya
            // per-tenant config yang boleh diubah owner via TenantSettings.
            'wa_settings'    => $this->wa_settings,
        ];
    }
}