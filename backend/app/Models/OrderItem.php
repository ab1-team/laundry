<?php

namespace App\Models;

use App\Traits\BelongsToTenant;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class OrderItem extends Model
{
    use BelongsToTenant;

    public $timestamps = false;

    protected $fillable = [
        'tenant_id',
        'order_id',
        'service_id',
        'service_name',
        'unit',
        'price',
        'qty',
        'subtotal',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'price'    => 'decimal:2',
            'qty'      => 'decimal:2',
            'subtotal' => 'decimal:2',
            'created_at' => 'datetime',
        ];
    }

    /* ---- Relations ---- */

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function service(): BelongsTo
    {
        return $this->belongsTo(Service::class);
    }
}