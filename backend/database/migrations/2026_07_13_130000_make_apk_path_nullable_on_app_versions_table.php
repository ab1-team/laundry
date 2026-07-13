<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * app_versions.apk_path dulu NOT NULL tanpa default → insert rilis
     * baru via admin.releases.store (create draft) gagal karena kolom
     * wajib diisi padahal form "Buat rilis" tidak minta file APK —
     * upload APK dilakukan terpisah oleh admin.releases.upload sebagai
     * langkah kedua (badge "Draft" vs "Siap Publish" di view turunan
     * dari null vs terisi).
     *
     * Fix: ubah kolom ke NULLABLE. Pakai raw SQL ALTER karena Laravel
     * 13's `->change()` butuh doctrine/dbal yang tidak ada di composer
     * dan tidak ingin menambah dep hanya untuk migration ini.
     *
     * MySQL-only: MODIFY COLUMN syntax +AFTER NULL mempertahankan posisi
     * kolom di schema awal (setelah version_code). Tidak mengubah data
     * existing — semua row yang sudah upload APK tetap punya apk_path.
     */
    public function up(): void
    {
        DB::statement('ALTER TABLE app_versions MODIFY COLUMN apk_path VARCHAR(255) NULL AFTER version_code');
    }

    public function down(): void
    {
        // Rollback ke NOT NULL. Aman hanya kalau tidak ada row dengan
        // apk_path NULL — caller harus bersihkan data sebelum rollback.
        DB::statement('ALTER TABLE app_versions MODIFY COLUMN apk_path VARCHAR(255) NOT NULL AFTER version_code');
    }
};