FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    sudo software-properties-common curl apt-transport-https \
    ca-certificates gnupg lsb-release supervisor nginx tar unzip git \
    php8.2 php8.2-common php8.2-cli php8.2-gd php8.2-mysql php8.2-mbstring \
    php8.2-bcmath php8.2-xml php8.2-fpm php8.2-curl php8.2-zip \
    redis-server mariadb-server \
    && rm -rf /var/lib/apt/lists/*
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
RUN mkdir -p /var/www/pterodactyl && cd /var/www/pterodactyl \
    && curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz \
    && tar -xzf panel.tar.gz \
    && rm panel.tar.gz \
    && chmod -R 755 storage/* bootstrap/cache/ \
    && cp .env.example .env \
    && COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader \
    && rm .env
RUN rm -f /etc/nginx/sites-enabled/default
COPY pterodactyl.conf /etc/nginx/sites-available/pterodactyl.conf
RUN ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
COPY supervisord.conf /etc/supervisord.conf
RUN echo "* * * * * www-data php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1" > /etc/cron.d/pterodactyl
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
