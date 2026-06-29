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

# Compile gd + intl dari source. ~2 menit total.
# gd = image processing (logo, icon)
# intl = format tanggal id_ID
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd intl

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
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist --no-interaction --no-progress

# Copy application source. .env di-exclude lewat .dockerignore.
COPY --chown=www-data:www-data . .

# Generate optimized autoloader untuk production.
RUN composer dump-autoload --optimize --no-dev --no-scripts

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html

USER www-data

EXPOSE 9000
CMD ["php-fpm"]