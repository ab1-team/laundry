<?php

namespace App\Models;

use App\Traits\BelongsToTenant;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Customer extends Model
{
    use BelongsToTenant;

    protected $fillable = [
        'tenant_id',
        'name',
        'phone',
        'address',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'total_orders'  => 'integer',
            'total_spent'   => 'decimal:2',
        ];
    }

    /* ---- Relations ---- */

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class);
    }
}
