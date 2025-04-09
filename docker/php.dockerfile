FROM php:8.3-fpm

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip \
    libzip-dev \
    libicu-dev \
    libpq-dev \
    supervisor \
    librabbitmq-dev \
    libssh-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    postgresql-client \
    && pecl install swoole \
    && docker-php-ext-enable swoole \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure intl \
    && docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql \
    && docker-php-ext-install \
        pdo_pgsql \
        pgsql \
        xml \
        gd \
        zip \
        intl \
        opcache \
        pcntl \
        bcmath \
    && rm -rf /var/lib/apt/lists/*

# Install redis extension
RUN pecl install redis && docker-php-ext-enable redis

# PHP settings
RUN { \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=4000'; \
        echo 'opcache.revalidate_freq=2'; \
        echo 'opcache.fast_shutdown=1'; \
        echo 'opcache.enable_cli=1'; \
    } > /usr/local/etc/php/conf.d/opcache-recommended.ini

# PHP-FPM config
RUN { \
        echo '[global]'; \
        echo 'daemonize = no'; \
        echo '[www]'; \
        echo 'listen = 9000'; \
    } > /usr/local/etc/php-fpm.d/zz-docker.conf

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Create user
RUN useradd -G www-data,root -u 1000 -d /home/dev dev
RUN mkdir -p /home/dev/.composer && \
    chown -R dev:dev /home/dev

# Set working directory
WORKDIR /var/www

# Copy source code
COPY --chown=dev:dev . .

# Install PHP dependencies
RUN composer install --no-interaction --prefer-dist --optimize-autoloader

# Set proper permissions
RUN chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache

# ⚠️ Don't run artisan commands inside Dockerfile
# Laravel queue and reverb should be started via entrypoint or docker-compose command
# because they are long-running processes

# Set default user
USER dev