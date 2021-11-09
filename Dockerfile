FROM devilbox/php-fpm-8.0:latest

# install last version xdebug
RUN pecl install xdebug-3.0.1 && docker-php-ext-enable xdebug


# Prevent error in nginx error.log
RUN touch /var/log/xdebug_remote.log
RUN chmod 777 /var/log/xdebug_remote.log

# add apcu and swoole to cache app
RUN pecl install apcu-5.1.21 && docker-php-ext-enable apcu
RUN pecl install swoole && docker-php-ext-enable swoole

RUN \
  apt-get -y install tzdata && \
  ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

# # Copy composer.lock and composer.json
# COPY composer.lock composer.json /var/www/

# Set working directory
WORKDIR /srv/www

# Install dependencies
RUN docker-php-ext-enable \
        imagick \
        redis \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure zip \
    && docker-php-ext-install \
        intl \
        curl \
        iconv \
        mbstring \
        pdo \
        pdo_mysql \
        pdo_pgsql \
        pdo_sqlite \
        pcntl \
        tokenizer \
        xml \
        gd \
        zip \
        bcmath

# Clear cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Install extensions
RUN docker-php-ext-configure imap --with-kerberos --with-imap-ssl
RUN docker-php-ext-install pdo_mysql mbstring zip exif pcntl bcmath mysqli sockets imap soap

RUN docker-php-ext-configure gd --with-gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ --with-png-dir=/usr/include/
RUN docker-php-ext-install gd

# RUN docker-php-ext-install redis
# RUN docker-php-ext-enable redis

RUN pecl install -o -f \
    imagick \
    redis \
    && rm -rf /tmp/pear

##SSL

RUN apt-get update -yqq \
    && apt-get install -y --no-install-recommends openssl \ 
    && sed -i 's,^\(MinProtocol[ ]*=\).*,\1'TLSv1.0',g' /etc/ssl/openssl.cnf \
    && sed -i 's,^\(CipherString[ ]*=\).*,\1'DEFAULT@SECLEVEL=1',g' /etc/ssl/openssl.cnf\
    && rm -rf /var/lib/apt/lists/*

# Install composer

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

# Add user for laravel application
RUN groupadd -g 1000 www
RUN useradd -u 1000 -ms /bin/bash -g www www

# Copy existing application directory contents
COPY . /srv/www

# Copy existing application directory permissions
COPY --chown=www:www . /srv/www

# Change current user to www
USER www

# Expose port 9000 and start php-fpm server
EXPOSE 9000
CMD ["php-fpm"]
