<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

class AppVersion extends Model
{
    protected $fillable = [
        'version',
        'version_code',
        'apk_path',
        'apk_size',
        'apk_checksum',
        'min_version',
        'force_update',
        'changelog',
        'is_active',
        'published_at',
    ];

    protected function casts(): array
    {
        return [
            'version_code' => 'integer',
            'apk_size'     => 'integer',
            'force_update' => 'boolean',
            'is_active'    => 'boolean',
            'published_at' => 'datetime',
        ];
    }

    /**
     * Ambil row rilis yang sedang aktif. Selalu paling baru yang menang
     * untuk tie-breaker (published_at desc).
     */
    public function scopeActive(Builder $query): Builder
    {
        return $query
            ->where('is_active', true)
            ->orderByDesc('published_at')
            ->orderByDesc('id');
    }
}