<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Icon extends Model
{
    // Icons adalah global asset — semua tenant refer ke tabel ini,
    // TIDAK ada tenant_id. Tanpa BelongsToTenant trait.

    protected $fillable = [
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