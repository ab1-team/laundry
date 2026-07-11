<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // service_categories: ganti kolom `icon` (string identifier) jadi
        // `icon_id` (FK ke tabel icons). nullOnDelete supaya admin boleh
        // hapus icon tanpa menghapus kategori — kategori.icon_id jadi null,
        // bukan kategori hilang.
        Schema::table('service_categories', function (Blueprint $table) {
            $table->dropColumn('icon');
        });
        Schema::table('service_categories', function (Blueprint $table) {
            $table->foreignId('icon_id')
                ->nullable()
                ->after('name')
                ->constrained('icons')
                ->nullOnDelete();
        });

        // services: tambah icon_id nullable setelah category_id.
        Schema::table('services', function (Blueprint $table) {
            $table->foreignId('icon_id')
                ->nullable()
                ->after('category_id')
                ->constrained('icons')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('services', function (Blueprint $table) {
            $table->dropConstrainedForeignId('icon_id');
        });
        Schema::table('service_categories', function (Blueprint $table) {
            $table->dropConstrainedForeignId('icon_id');
        });
        Schema::table('service_categories', function (Blueprint $table) {
            $table->string('icon', 100)->nullable()->after('name');
        });
    }
};