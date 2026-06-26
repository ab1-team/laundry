<?php

namespace App\Models;

use App\Traits\BelongsToTenant;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Payment extends Model
{
    use BelongsToTenant;

    protected $fillable = [
        'tenant_id',
        'order_id',
        'amount',
        'method',
        'note',
        'paid_at',
        'recorded_by',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'paid_at' => 'datetime',
        ];
    }

    /* ---- Constants ---- */
    public const METHOD_CASH     = 'cash';
    public const METHOD_TRANSFER = 'transfer';
    public const METHOD_QRIS     = 'qris';
    public const METHOD_LAINNYA  = 'lainnya';

    /* ---- Relations ---- */

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function recordedByUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'recorded_by');
    }
}