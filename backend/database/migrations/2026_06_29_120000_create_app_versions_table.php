<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Tabel app_versions — katalog rilis APK yang di-publish oleh
     * super_admin. Hanya satu row yang boleh `is_active = true` pada satu
     * waktu; row itulah yang dikembalikan oleh GET /api/v1/app/version.
     *
     * Kenapa bukan env?
     *   - Env mengharuskan redeploy / restart container tiap rilis.
     *   - Dengan DB, admin tinggal upload APK via API dan activate row
     *     baru tanpa downtime.
     */
    public function up(): void
    {
        Schema::create('app_versions', function (Blueprint $table) {
            $table->id();
            // versionName dari pubspec.yaml (mis. "1.2.0").
            $table->string('version', 30);
            // versionCode dari build.gradle — increment tiap build Android.
            $table->unsignedInteger('version_code');
            // Path relatif di Storage::disk('public') — mis.
            // "releases/laundryaja-1.2.0.apk".
            $table->string('apk_path', 255);
            // Ukuran file dalam bytes, di-set otomatis saat upload.
            $table->unsignedBigInteger('apk_size')->nullable();
            // SHA-256 checksum, dipakai client untuk verifikasi integritas
            // sebelum install (defense-in-depth terhadap MITM).
            $table->string('apk_checksum', 64)->nullable();
            // Versi minimum yang masih boleh online. Null = tidak ada
            // paksa update. Versi lokal < min_version akan di-block.
            $table->string('min_version', 30)->nullable();
            // Override paksa update independent dari min_version. Admin
            // bisa set true untuk rilis hotfix tanpa harus naik min_version.
            $table->boolean('force_update')->default(false);
            // Catatan rilis — tampil di dialog update di app.
            $table->text('changelog')->nullable();
            // Hanya satu row is_active=true pada satu waktu (di-enforce
            // di controller, bukan partial unique, supaya transisi
            // deactivate-then-activate lebih mudah diaudit).
            $table->boolean('is_active')->default(false);
            $table->timestamp('published_at')->nullable();
            $table->timestamps();

            $table->index('is_active');
            $table->index(['version_code', 'is_active']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('app_versions');
    }
};