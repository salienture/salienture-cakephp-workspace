FROM dunglas/frankenphp:1-php8.5-bookworm

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Common CakePHP extensions
RUN install-php-extensions \
    pdo_mysql \
    mysqli \
    intl \
    mbstring \
    simplexml \
    zip \
    gd \
    opcache \
    redis \
    pcntl \
    exif

# Optional Xdebug — set INSTALL_XDEBUG=true at build time, XDEBUG_MODE at runtime
ARG INSTALL_XDEBUG=false
RUN if [ "$INSTALL_XDEBUG" = "true" ]; then install-php-extensions xdebug; fi

COPY Caddyfile /etc/caddy/Caddyfile

WORKDIR /app

EXPOSE 80 443 443/udp

CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]
