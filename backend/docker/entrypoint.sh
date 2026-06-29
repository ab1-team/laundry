#!/bin/sh
set -e

# Inisialisasi .env untuk Laravel. Image bawa .env.example (di-
# allowlist oleh .dockerignore) tapi BUKAN .env — supaya secret
# tidak bocor via image layer. Copy di container saat start, lalu
# set owner www-data (uid 33 di php:8.4-fpm-alpine) supaya proses
# php-fpm nanti (yang run sebagai www-data) bisa tulis saat
# artisan key:generate / config:cache.
#
# Entrypoint run sebagai root supaya bisa chown. "exec" di akhir
# ganti process image ke www-data — bukan child process — sehingga
# php-fpm langsung jadi PID 1 di user www-data.
if [ ! -f /var/www/html/.env ]; then
  cp /var/www/html/.env.example /var/www/html/.env
  echo "[entrypoint] .env dibuat dari .env.example"
fi

chown www-data:www-data /var/www/html/.env
chmod 0664 /var/www/html/.env

exec "$@"
