<?php

namespace App\Services;

use App\Models\Tenant;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class TenantService
{
    /**
     * Register tenant + owner dalam satu transaksi.
     */
    public function registerTenant(array $data): Tenant
    {
        return DB::transaction(function () use ($data) {
            // 1. Buat tenant (status trial by default)
            $tenant = Tenant::create([
                'name'           => $data['name'],
                'slug'           => $data['slug'],
                'phone'          => $data['phone'] ?? null,
                'address'        => $data['address'] ?? null,
                'city'           => $data['city'] ?? null,
                'status'         => Tenant::STATUS_TRIAL,
                'trial_ends_at'  => now()->addDays(14),
                'activated_at'   => null,
            ]);

            // 2. Buat owner user
            User::create([
                'tenant_id' => $tenant->id,
                'name'      => $data['owner_name'],
                'email'     => $data['owner_email'],
                'password'  => $data['owner_password'],
                'role'      => User::ROLE_OWNER,
                'is_active' => true,
            ]);

            return $tenant->fresh('users');
        });
    }
}