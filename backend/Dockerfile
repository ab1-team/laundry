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

# Install PHP dependencies (no dev dependencies for production)
COPY --chown=www-data:www-data composer.json composer.lock ./
# Retry on transient GitHub zipball flakes; use dist (default) and avoid
# source fallback to archived repos like php-fig/simple-cache.
ENV COMPOSER_MAX_RETRIES=5
RUN composer clear-cache \
 && composer install --no-dev --no-scripts --no-autoloader --prefer-dist --no-interaction

# Copy application source
COPY --chown=www-data:www-data . .

# Generate optimized autoloader
RUN composer dump-autoload --optimize --no-dev

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html

USER www-data

EXPOSE 9000
CMD ["php-fpm"]
