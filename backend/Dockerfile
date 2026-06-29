FROM php:8.4-fpm-alpine AS base

# Install system deps untuk compile PHP extensions (gd + intl).
# Hanya 2 extension yang compile — bukan 5. Sisanya (pdo_mysql,
# mbstring, zip, bcmath, opcache) sudah include di base image.
RUN apk add --no-cache \
    libpng-dev \
    freetype-dev \
    libjpeg-turbo-dev \
    icu-dev \
    linux-headers

# Install PHP extensions: pdo_mysql, gd, intl. Sisanya (mbstring,
# zip, bcmath, opcache) sudah include di base image.
#
# Compile ~2 menit total karena ini extension yang berat (gd butuh
# freetype + jpeg). pdo_mysql & intl cepat (~30 detik each).
RUN docker-php-ext-install -j$(nproc) pdo_mysql gd intl

# Redis extension (untuk session + cache driver).
# pecl install ringan (~30 detik) karena build pakai pre-compiled
# binary di PECL registry.
RUN apk add --no-cache $PHPIZE_DEPS \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del $PHPIZE_DEPS

# Install Composer (binary only — tidak perlu install Composer terpisah
# di host/server, image sudah membawa binary ini).
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Override php-fpm pool to listen on 0.0.0.0 so nginx (other container) can reach
COPY docker/php/www.conf /usr/local/etc/php-fpm.d/www.conf

# Install PHP dependencies (production: no dev). composer.lock pinning
# supaya build reproducible — versi dependency selalu sama persis.
COPY --chown=www-data:www-data composer.json composer.lock ./
ENV COMPOSER_MAX_RETRIES=2

# Composer 2.x auto-rewrite api.github.com dist URL ke
# codeload.github.com/legacy.zip yang return HTTP 400 intermittent
# dari region Asia. --prefer-dist dengan --prefer-stable + flag
# --no-interaction tidak cukup. Solusi: pakai --prefer-stable yang
# bypass rewrite untuk stable release (tapi tidak selalu).
#
# Real fix: packagist sudah migrate ke API zipball URL. Tapi Composer
# 2.x rewrite masih jalan. Set COMPOSER_NO_INTERACTION + retry.
ENV COMPOSER_MAX_RETRIES=2
ENV COMPOSER_DISABLE_TLS=false

RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist --prefer-stable --no-interaction --no-progress

# Copy application source. .env di-exclude lewat .dockerignore.
COPY --chown=www-data:www-data . .

# Generate optimized autoloader untuk production.
RUN composer dump-autoload --optimize --no-dev --no-scripts

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html

USER www-data

EXPOSE 9000
CMD ["php-fpm"]