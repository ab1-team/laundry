<?php

namespace Database\Seeders;

use App\Models\Tenant;
use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        DB::transaction(function () {
            // ---- Tenant demo ----
            $tenant = Tenant::updateOrCreate(
                ['slug' => 'laundryaja-demo'],
                [
                    'name'         => 'LaundryAja Demo',
                    'phone'        => '081234567890',
                    'address'      => 'Jl. Merdeka No. 1',
                    'city'         => 'Jakarta',
                    'status'       => Tenant::STATUS_ACTIVE,
                    'activated_at' => now(),
                ]
            );

            // ---- Super admin (platform-level, no tenant) ----
            User::updateOrCreate(
                ['email' => 'admin@laundryaja.com'],
                [
                    'tenant_id' => null,
                    'name'      => 'Super Admin',
                    'password'  => 'admin123',
                    'role'      => User::ROLE_SUPER_ADMIN,
                    'is_active' => true,
                ]
            );

            // ---- Tenant owner (admin bisnis laundry) ----
            User::updateOrCreate(
                ['email' => 'owner@laundryaja.com'],
                [
                    'tenant_id' => $tenant->id,
                    'name'      => 'Pemilik Laundry',
                    'password'  => 'owner123',
                    'role'      => User::ROLE_OWNER,
                    'is_active' => true,
                ]
            );

            // ---- Operator (staff) ----
            User::updateOrCreate(
                ['email' => 'operator@laundryaja.com'],
                [
                    'tenant_id' => $tenant->id,
                    'name'      => 'Operator Laundry',
                    'password'  => 'operator123',
                    'role'      => User::ROLE_OPERATOR,
                    'is_active' => true,
                ]
            );
        });
    }
}
