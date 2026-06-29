FROM php:8.4-fpm-alpine AS base

# Install dependencies
RUN apk add --no-cache \
    libzip-dev \
    oniguruma-dev \
    libpng-dev \
    freetype-dev \
    libjpeg-turbo-dev \
    icu-dev \
    linux-headers

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install \
    pdo_mysql \
    mbstring \
    zip \
    gd \
    bcmath \
    intl \
    opcache

# Install Redis extension
RUN apk add --no-cache $PHPIZE_DEPS \
    && pecl install redis \
    && docker-php-ext-enable redis

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Override php-fpm pool to listen on 0.0.0.0 so nginx (other container) can reach
COPY docker/php/www.conf /usr/local/etc/php-fpm.d/www.conf

# Image ini HANYA runtime. Tidak ada source code, tidak ada .env.
# Semua di-mount dari host lewat docker-compose.yml:
#   - ./  → /var/www/html        (source code)
#   - ./.env → /var/www/html/.env (konfigurasi runtime)
# Container cuma PHP-FPM process; data hidup di host filesystem.
#
# Composer install tidak dilakukan di sini — vendor/ di-generate di
# host saat pertama kali `composer install`, lalu folder vendor/
# di-bind-mount juga. Atau jalankan di runtime via entrypoint.

USER www-data

EXPOSE 9000
CMD ["php-fpm"]