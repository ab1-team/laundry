<?php

return [
    /*
    | Versi aplikasi yang sedang dipublikasikan.
    | Diset via env agar deploy / image rebuild cukup update .env tanpa
    | commit kode. Sesuaikan dengan versionName di mobile/pubspec.yaml.
    */
    'version'      => env('APP_VERSION', '1.1.0'),

    /*
    | Versi minimum yang masih boleh online. Versi di bawah ini akan
    | dipaksa update (force_update otomatis true jika latest < min).
    */
    'min_version'  => env('APP_MIN_VERSION', '1.0.0'),

    /*
    | Paksa user update sebelum lanjut pakai app.
    */
    'force_update' => (bool) env('APP_FORCE_UPDATE', false),

    /*
    | Catatan rilis (tampil di dialog update). Multi-line diperbolehkan.
    */
    'changelog'    => env('APP_CHANGELOG', 'Perbaikan bug & peningkatan stabilitas.'),

    /*
    | Lokasi APK di storage.
    | Disk "public" = storage/app/public. Path relatif dari root disk.
    | Taruh APK di:  storage/app/public/releases/latest.apk
    */
    'disk'         => env('APP_APK_DISK', 'public'),
    'apk_path'     => env('APP_APK_PATH', 'releases/latest.apk'),
];