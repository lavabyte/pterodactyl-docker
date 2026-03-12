#!/bin/bash
set -e
if [ ! -d /var/lib/mysql/mysql ]; then
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql > /dev/null
fi
mysqld_safe --datadir=/var/lib/mysql &
until mysqladmin ping --silent 2>/dev/null; do sleep 1; done
redis-server --port 6379 --daemonize yes
until redis-cli ping 2>/dev/null | grep -q PONG; do sleep 1; done
if [ ! -f /var/www/pterodactyl/.db_initialized ]; then
    mariadb -u root <<EOF
CREATE USER IF NOT EXISTS 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '123';
CREATE DATABASE IF NOT EXISTS panel;
GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
    cd /var/www/pterodactyl
    cp .env.example .env
    sed -i "s|APP_URL=.*|APP_URL=https://example.com|g" .env
    sed -i "s|APP_ENV=.*|APP_ENV=production|g" .env
    sed -i "s|APP_DEBUG=.*|APP_DEBUG=false|g" .env
    sed -i "s|CACHE_DRIVER=.*|CACHE_DRIVER=redis|g" .env
    sed -i "s|SESSION_DRIVER=.*|SESSION_DRIVER=redis|g" .env
    sed -i "s|QUEUE_DRIVER=.*|QUEUE_DRIVER=redis|g" .env
    sed -i "s|DB_HOST=.*|DB_HOST=127.0.0.1|g" .env
    sed -i "s|DB_PORT=.*|DB_PORT=3306|g" .env
    sed -i "s|DB_DATABASE=.*|DB_DATABASE=panel|g" .env
    sed -i "s|DB_USERNAME=.*|DB_USERNAME=pterodactyl|g" .env
    sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=123|g" .env
    sed -i "s|REDIS_HOST=.*|REDIS_HOST=127.0.0.1|g" .env
    sed -i "s|REDIS_PORT=.*|REDIS_PORT=6379|g" .env
    echo "APP_ENVIRONMENT_ONLY=false" >> .env
    KEY=$(php -r "echo 'base64:'.base64_encode(random_bytes(32));")
    sed -i "s|APP_KEY=.*|APP_KEY=$KEY|g" .env
    php artisan migrate --seed --force
    php artisan p:user:make --email=admin@example.com --username=admin --name-first=. --name-last=. --password=admin --admin=1 2>/dev/null || true
    chown -R www-data:www-data /var/www/pterodactyl/*
    touch /var/www/pterodactyl/.db_initialized
fi
mysqladmin -u root shutdown 2>/dev/null || true
redis-cli shutdown 2>/dev/null || true
exec supervisord -n -c /etc/supervisord.conf
