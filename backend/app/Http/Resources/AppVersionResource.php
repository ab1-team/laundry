<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

class AppVersionResource extends JsonResource
{
    public function toArray($request): array
    {
        return [
            'id'           => $this->id,
            'version'      => $this->version,
            'version_code' => $this->version_code,
            'apk_path'     => $this->apk_path,
            'apk_size'     => $this->apk_size,
            'apk_checksum' => $this->apk_checksum,
            'min_version'  => $this->min_version,
            'force_update' => $this->force_update,
            'changelog'    => $this->changelog,
            'is_active'    => $this->is_active,
            'published_at' => optional($this->published_at)->toIso8601String(),
            'created_at'   => optional($this->created_at)->toIso8601String(),
            'updated_at'   => optional($this->updated_at)->toIso8601String(),
        ];
    }
}