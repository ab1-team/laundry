<?php

namespace App\Models;

use App\Traits\BelongsToTenant;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Service extends Model
{
    use BelongsToTenant;

    protected $fillable = [
        'tenant_id',
        'category_id',
        'name',
        'price',
        'unit',
        'duration_hours',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'price'           => 'float',
            'is_active'       => 'boolean',
            'duration_hours'  => 'integer',
        ];
    }

    /* ---- Relations ---- */

    public function category(): BelongsTo
    {
        return $this->belongsTo(ServiceCategory::class, 'category_id');
    }
}
