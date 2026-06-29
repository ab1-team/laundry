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

# Install Composer (binary only — tidak perlu install Composer terpisah
# di host/server, image sudah membawa binary ini).
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Override php-fpm pool to listen on 0.0.0.0 so nginx (other container) can reach
COPY docker/php/www.conf /usr/local/etc/php-fpm.d/www.conf

# Install PHP dependencies (production: no dev). composer.lock pinning
# supaya build reproducible — versi dependency selalu sama persis.
COPY --chown=www-data:www-data composer.json composer.lock ./
# --prefer-dist + GitHub dist mirror: download dari api.github.com (zipball),
# bukan codeload.github.com/legacy.zip yang sering HTTP 400 untuk archived
# PHP-FIG repos. COMPOSER_MAX_RETRIES rendah agar gagal cepat.
ENV COMPOSER_MAX_RETRIES=2
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist --no-interaction --no-progress

# Copy application source. .env di-exclude lewat .dockerignore sehingga
# image TIDAK berisi konfigurasi runtime — host yang punya .env via
# bind-mount / env_file. bootstrap/cache juga di-exclude — cache di-
# generate saat container start, bukan dari host (yang mungkin punya
# dev cache yang refer ke package yang tidak ada di production).
COPY --chown=www-data:www-data . .

# Generate optimized autoloader untuk production.
RUN composer dump-autoload --optimize --no-dev --no-scripts

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html

USER www-data

EXPOSE 9000
CMD ["php-fpm"]