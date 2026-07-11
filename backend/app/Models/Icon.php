<?php

namespace App\Models;

use App\Traits\BelongsToTenant;
use Illuminate\Database\Eloquent\Model;

class Icon extends Model
{
    use BelongsToTenant;

    protected $fillable = [
        'tenant_id',
        'name',
        'icon_path',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
        ];
    }

    /**
     * Relative URL yang dilayani oleh `php artisan storage:link`.
     * Sama pola dengan TenantResource::logo_url — frontend pakai
     * resolveAssetUrl() untuk menggabungkan origin host + path ini.
     */
    public function getIconUrlAttribute(): ?string
    {
        return $this->icon_path
            ? '/storage/' . ltrim($this->icon_path, '/')
            : null;
    }
}