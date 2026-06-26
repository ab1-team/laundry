<?php

namespace App\Traits;

use Illuminate\Database\Eloquent\Builder;

trait BelongsToTenant
{
    protected static function bootBelongsToTenant(): void
    {
        // Auto-inject WHERE tenant_id on every query
        static::addGlobalScope('tenant', function (Builder $query) {
            $user = auth()->user();

            if ($user && $user->tenant_id !== null) {
                $query->where($query->getModel()->getTable() . '.tenant_id', $user->tenant_id);
            }
        });

        // Auto-set tenant_id on creating
        static::creating(function ($model) {
            $user = auth()->user();

            if ($user && $user->tenant_id !== null && empty($model->tenant_id)) {
                $model->tenant_id = $user->tenant_id;
            }
        });
    }
}
