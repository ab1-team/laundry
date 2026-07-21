<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('wa_notifications', function (Blueprint $table) {
            // Status order yang trigger dispatch notif ini — captured
            // saat OrderService::maybeNotifyWa supaya Job bisa reconstruct
            // intent (PDF nota HANYA untuk 'selesai', bukan 'diambil'
            // yang juga punya finished_at terisi).
            // Nullable: notif lama (pre-deploy) tidak punya nilai ini.
            $table->string('trigger_status', 20)->nullable()->after('message');
        });
    }

    public function down(): void
    {
        Schema::table('wa_notifications', function (Blueprint $table) {
            $table->dropColumn('trigger_status');
        });
    }
};