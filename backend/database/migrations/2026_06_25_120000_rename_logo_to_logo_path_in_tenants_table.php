<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tenants', function (Blueprint $table) {
            // Rename kolom `logo` (string URL/path legacy) ke `logo_path`
            // untuk semantik path file hasil upload di storage/app/public.
            $table->renameColumn('logo', 'logo_path');
        });
    }

    public function down(): void
    {
        Schema::table('tenants', function (Blueprint $table) {
            $table->renameColumn('logo_path', 'logo');
        });
    }
};
