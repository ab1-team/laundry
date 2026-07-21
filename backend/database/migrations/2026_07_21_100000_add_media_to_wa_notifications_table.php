<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('wa_notifications', function (Blueprint $table) {
            // Lampiran media (PDF nota, image, dll). NULL → text-only.
            // Path relatif thd `local` disk (storage/app/private).
            $table->string('media_path')->nullable()->after('message');
            $table->string('media_type', 50)->nullable()->after('media_path');
        });
    }

    public function down(): void
    {
        Schema::table('wa_notifications', function (Blueprint $table) {
            $table->dropColumn(['media_path', 'media_type']);
        });
    }
};