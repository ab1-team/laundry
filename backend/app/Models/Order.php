<?php

namespace App\Models;

use App\Traits\BelongsToTenant;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Order extends Model
{
    use BelongsToTenant;

    protected $fillable = [
        'tenant_id',
        'customer_id',
        'created_by',
        'ticket_number',
        'notes',
        'status',
        'subtotal',
        'discount',
        'total',
        'estimated_finish_at',
        'finished_at',
        'picked_up_at',
        'cancelled_at',
        'cancel_reason',
    ];

    protected function casts(): array
    {
        return [
            'subtotal'              => 'decimal:2',
            'discount'              => 'decimal:2',
            'total'                 => 'decimal:2',
            'estimated_finish_at'   => 'datetime',
            'finished_at'           => 'datetime',
            'picked_up_at'          => 'datetime',
            'cancelled_at'          => 'datetime',
        ];
    }

    /* ---- Status constants ---- */
    public const STATUS_MASUK      = 'masuk';
    public const STATUS_DICUCI     = 'dicuci';
    public const STATUS_SELESAI    = 'selesai';
    public const STATUS_DIAMBIL    = 'diambil';
    public const STATUS_DIBATALKAN = 'dibatalkan';

    /** Pipeline: stage → next allowed stage */
    public const STATUS_FLOW = [
        self::STATUS_MASUK      => [self::STATUS_DICUCI, self::STATUS_DIBATALKAN],
        self::STATUS_DICUCI     => [self::STATUS_SELESAI, self::STATUS_DIBATALKAN],
        self::STATUS_SELESAI    => [self::STATUS_DIAMBIL],
        self::STATUS_DIAMBIL    => [],
        self::STATUS_DIBATALKAN => [],
    ];

    /* ---- Relations ---- */

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function items(): HasMany
    {
        return $this->hasMany(OrderItem::class);
    }

    public function statusLogs(): HasMany
    {
        return $this->hasMany(OrderStatusLog::class);
    }

    public function payments(): HasMany
    {
        return $this->hasMany(Payment::class);
    }

    /* ---- Helpers ---- */

    public function canTransitionTo(string $newStatus): bool
    {
        return in_array($newStatus, self::STATUS_FLOW[$this->status] ?? [], true);
    }

    public function totalPaid(): float
    {
        return (float) $this->payments()->sum('amount');
    }

    public function remaining(): float
    {
        return (float) $this->total - $this->totalPaid();
    }

    public function isPaid(): bool
    {
        return $this->remaining() <= 0;
    }
}