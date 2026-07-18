<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('tenants', function (Blueprint $table) {
            // JSON: { enabled: bool, instance: string, notify_on: [masuk,dicuci,...] }
            // Disimpan sebagai JSON supaya future fields (jam operasional, custom
            // template, dsb) tidak butuh migrasi tambahan.
            $table->json('wa_settings')->nullable()->after('activated_at');
        });
    }

    public function down(): void
    {
        Schema::table('tenants', function (Blueprint $table) {
            $table->dropColumn('wa_settings');
        });
    }
};
