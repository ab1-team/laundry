<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Icons adalah global asset yang di-manage oleh super_admin via
        // halaman /admin/icons. Tidak ada FK ke tenant. Drop kolom
        // tenant_id + index. Lakukan dalam transaction-like pair (drop
        // FK dulu, lalu drop column) — Schema::table tidak otomatis
        // drop index FK di semua driver.
        Schema::table('icons', function (Blueprint $table) {
            $table->dropConstrainedForeignId('tenant_id');
        });
        Schema::table('icons', function (Blueprint $table) {
            $table->dropIndex(['tenant_id', 'is_active']);
            // Index ulang untuk filter aktif (yang dipakai mobile picker).
            $table->index('is_active');
        });
    }

    public function down(): void
    {
        Schema::table('icons', function (Blueprint $table) {
            $table->dropIndex(['is_active']);
        });
        Schema::table('icons', function (Blueprint $table) {
            $table->foreignId('tenant_id')->nullable()->after('id')->constrained('tenants')->cascadeOnDelete();
            $table->index(['tenant_id', 'is_active']);
        });
    }
};