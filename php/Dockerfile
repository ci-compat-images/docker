FROM base

ARG PHP_VERSION=8.3.21
ARG PHP_MINOR=8.3
ARG COMPOSER_VERSION=2.8.4

ENV PHP_VERSION=${PHP_VERSION} \
    PHP_MINOR=${PHP_MINOR}

# Install dependencies
RUN sudo apt-get update && sudo apt-get install -y \
    autoconf \
    bison \
    build-essential \
    libcurl4-openssl-dev \
    libfreetype6-dev \
    libjpeg-dev \
    libonig-dev \
    libpng-dev \
    libreadline-dev \
    libsodium-dev \
    libsqlite3-dev \
    libssl-dev \
    libtool \
    libwebp-dev \
    libxml2-dev \
    libxpm-dev \
    libzip-dev \
    re2c \
    zlib1g-dev

# RUN sudo rm -rf /var/lib/apt/lists/*

RUN curl -sSL "https://github.com/php/php-src/archive/refs/tags/php-${PHP_VERSION}.tar.gz" | tar -xz

RUN set -eux; \
    cd "php-src-php-${PHP_VERSION}"; \
    if [[ "$PHP_MINOR" == 7.3* ]]; then \
    GD_FLAG="--with-gd"; \
    else \
    GD_FLAG="--enable-gd"; \
    fi; \
    ./buildconf --force; \
    ./configure $GD_FLAG \
    --enable-bcmath \
    --enable-fpm \
    --enable-intl \
    --enable-mbstring \
    --enable-pcntl \
    --enable-phpdbg \
    --enable-sockets \
    --enable-calendar \
    --enable-ftp \
    --enable-exif \
    --enable-zip \
    --enable-soap \
    --with-config-file-scan-dir=/etc/php.d \
    --with-curl \
    --with-freetype \
    --with-jpeg \
    --with-mysqli=mysqlnd \
    --with-pear \
    --with-pdo-mysql=mysqlnd \
    --with-pdo-pgsql \
    --with-pdo-sqlite \
    --with-pgsql \
    --with-openssl \
    --with-readline \
    --with-sodium \
    --with-webp \
    --with-xpm \
    --with-zip \
    --with-zlib

RUN cd "php-src-php-${PHP_VERSION}" && make -j $(nproc) && sudo make install

RUN rm -r php-src-php-${PHP_VERSION}

RUN sudo mkdir -p /etc/php.d && echo 'memory_limit = -1' | sudo tee -a /etc/php.d/circleci.ini

RUN sudo pear config-set php_ini /etc/php.d/circleci.ini && sudo pecl update-channels

# Check things are as they should be
# We likely don't need to test EVERYTHING here. What is important is to
# test for extensions where the installation method has changed between
# releases. For example, if we decide to use this template back for older
# PHP releases, the way `gd` is enabled at compile time changed.
RUN php --version | grep "${PHP_VERSION}" || ( echo "Error: PHP version installed is not correct." && exit 1 )
RUN php -m | grep "gd"
RUN php -m | grep "sockets"

# Installs install-php-extensions functionality to add, enable, and configurae PHP extensions. The script is modified to
# work with CircleCI's environment. Updates to the script should be accompanied with a release in it's respective
# repositpory

ENV EXT_URL=https://github.com/CircleCI-Public/docker-php-extension-installer/releases/latest/download/install-php-extensions
ENV PHP_INI_DIR=/usr/local/etc/php

COPY /docker-php-scripts/docker-php-* /usr/local/bin/

RUN sudo mkdir -p "$PHP_INI_DIR/conf.d"  && \
    curl -sSL ${EXT_URL} > install-php-extensions && \
    sudo mv install-php-extensions /usr/local/bin && \
    sudo chmod +x /usr/local/bin/docker-php-* /usr/local/bin/install-php-extensions

# Install the PHP package manager Composer
RUN sudo php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    sudo php composer-setup.php --version=$COMPOSER_VERSION --install-dir=/usr/local/bin --filename=composer && \
    sudo php -r "unlink('composer-setup.php');" && \
    composer --version

# No memory limit - CI will limit whole container
ENV COMPOSER_MEMORY_LIMIT=-1

ENV PATH=/home/circleci/.config/composer/vendor/bin:/home/circleci/.composer/vendor/bin:$PATH