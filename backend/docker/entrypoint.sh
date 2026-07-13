#!/bin/sh
set -e

# Inisialisasi .env untuk Laravel. Dua sumber yang mungkin:
#
# (a) Image bawa .env.example (di-allowlist oleh .dockerignore). Kalau
#     di container tidak ada .env satupun — first boot tanpa bind-mount,
#     atau volume kosong — copy dari .env.example. Image TIDAK bawa .env
#     itu sendiri supaya secret tidak bocor via image layer.
#
# (b) docker-compose.yml bind-mount .env dari host (path default). File
#     sudah ada di-mount dari host — JANGAN overwrite, kalau tidak
#     customized config (DB_PASSWORD, dll) hilang.
#
# Setelah init, set owner www-data + group write supaya php-fpm worker
# bisa tulis saat artisan key:generate / config:cache / optimize.
#
# Entrypoint run sebagai root (lihat Dockerfile USER root) supaya bisa
# chown. "exec" di akhir ganti process image ke www-data — bukan child
# process — sehingga php-fpm jadi PID 1 di user yang benar dan signal
# handling (SIGTERM dari docker stop) propagate.
if [ ! -f /var/www/html/.env ]; then
  cp /var/www/html/.env.example /var/www/html/.env
  echo "[entrypoint] .env dibuat dari .env.example"
fi

# chown idempotent. Kalau file di-bind-mount dari host dengan owner
# root, ini fix ke www-data. Kalau owner sudah www-data, no-op.
# chmod 0664 = owner+group rw, world read — cukup untuk php-fpm tulis.
chown www-data:www-data /var/www/html/.env
chmod 0664 /var/www/html/.env

# Bind-mount storage/app dari host (lihat docker-compose.yml volume
# ./storage/app:/var/www/html/storage/app). Host owner biasanya uid
# SSH user (root/enpii/197121) — bukan www-data (uid 33). Tanpa chown
# di sini, mkdir()/file_put_contents() di runtime gagal: "Permission
# denied" walaupun mode bits longgar, sama seperti .env gotcha.
# Fix: chown -R setelah container start supaya semua subdir releases/,
# icons/, tenants/ yang di-create runtime juga ikut writable.
#
# `-R` recursive tapi scope cuma storage/app subtree, bukan seluruh
# image — chown image jadi mahal. Pola: chown point-of-write dirs
# saja, bukan /var/www/html/.
chown -R www-data:www-data /var/www/html/storage/app
chmod -R ug+rwX /var/www/html/storage/app

exec "$@"