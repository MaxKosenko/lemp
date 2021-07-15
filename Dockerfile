FROM ubuntu:20.04

ARG HOST_NAME=lemp_host
ENV HOST_NAME=$HOST_NAME

ARG HOST_USER=lemp_user
ENV HOST_USER=$HOST_USER

ARG HOST_USER_PASSWORD=123321
ENV HOST_USER_PASSWORD=$HOST_USER_PASSWORD

ARG PHP_VERSION=7.4
ENV PHP_VERSION=$PHP_VERSION

ARG MYSQL_USER_NAME=lemp_user
ENV MYSQL_USER_NAME=$MYSQL_USER_NAME

ARG MYSQL_USER_PASSWORD=123321
ENV MYSQL_USER_PASSWORD=$MYSQL_USER_PASSWORD

ARG MYSQL_ROOT_PASSWORD=123321
ENV MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD

ARG MYSQL_DATABASE_NAME=lemp_db
ENV MYSQL_DATABASE_NAME=$MYSQL_DATABASE_NAME

RUN echo "THE HOST NAME IS ${HOST_NAME} "

RUN set -eux; \
    apt-get update; \
    apt-get upgrade -y; \
    apt-get install -y --force-yes --no-install-recommends software-properties-common; \
    apt-add-repository ppa:ondrej/nginx -y; \
    apt-add-repository ppa:ondrej/php -y; \
    apt-get update; \
    add-apt-repository universe; \
    apt-get install -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y --force-yes --no-install-recommends build-essential sudo curl pkg-config fail2ban gcc g++ git libmcrypt4 libpcre3-dev \
    make python3 python3-pip wget sendmail supervisor mc zip unzip whois zsh ncdu bash cron logrotate uuid-runtime acl libpng-dev libmagickwand-dev; \
    pip3 install httpie; \
    pip3 install awscli; \
    pip3 install awscli-plugin-endpoint;

RUN apt-get install --no-install-recommends -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y --force-yes \
    php$PHP_VERSION \
    php$PHP_VERSION-fpm \
    php$PHP_VERSION-cli \
    php$PHP_VERSION-dev \
    php$PHP_VERSION-pgsql \
    php$PHP_VERSION-sqlite3 \
    php$PHP_VERSION-gd \
    php$PHP_VERSION-curl \
    php$PHP_VERSION-memcached \
    php$PHP_VERSION-imap \
    php$PHP_VERSION-mysql \ 
    php$PHP_VERSION-mbstring \
    php$PHP_VERSION-xml \
    php$PHP_VERSION-zip \
    php$PHP_VERSION-bcmath \
    php$PHP_VERSION-soap \
    php$PHP_VERSION-intl \
    php$PHP_VERSION-readline \
    php$PHP_VERSION-msgpack \
    php$PHP_VERSION-igbinary \
    php$PHP_VERSION-gmp \
    php$PHP_VERSION-swoole;

RUN ln -sf /usr/share/zoneinfo/UTC /etc/localtime;

RUN useradd $HOST_USER; \
    adduser $HOST_USER sudo;

RUN echo "$HOST_USER ALL=NOPASSWD: /usr/sbin/service php$PHP_VERSION-fpm reload" > /etc/sudoers.d/php-fpm; \
    echo "$HOST_USER ALL=NOPASSWD: /usr/sbin/service nginx *" >> /etc/sudoers.d/nginx; \
    echo "$HOST_USER ALL=NOPASSWD: /usr/bin/supervisorctl *" >> /etc/sudoers.d/supervisor;

COPY php/php$PHP_VERSION.ini /etc/php/$PHP_VERSION/cli/php.ini
 
RUN echo "Configuring PHPRedis"; \
    echo "extension=redis.so" > /etc/php/$PHP_VERSION/mods-available/redis.ini; \
    yes '' | apt install "php$PHP_VERSION-redis";

RUN apt-get install -y --force-yes libmagickwand-dev; \
    echo "extension=imagick.so" > /etc/php/$PHP_VERSION/mods-available/imagick.ini; \
    yes '' | apt install "php$PHP_VERSION-imagick";

RUN sed -i "s/^user = www-data/user = $HOST_USER/" /etc/php/$PHP_VERSION/fpm/pool.d/www.conf; \
    sed -i "s/^group = www-data/group = $HOST_USER/" /etc/php/$PHP_VERSION/fpm/pool.d/www.conf; \
    sed -i "s/;listen\.owner.*/listen.owner = $HOST_USER/" /etc/php/$PHP_VERSION/fpm/pool.d/www.conf; \
    sed -i "s/;listen\.group.*/listen.group = $HOST_USER/" /etc/php/$PHP_VERSION/fpm/pool.d/www.conf; \
    sed -i "s/;listen\.mode.*/listen.mode = 0666/" /etc/php/$PHP_VERSION/fpm/pool.d/www.conf; \
    sed -i "s/;request_terminate_timeout.*/request_terminate_timeout = 60/" /etc/php/$PHP_VERSION/fpm/pool.d/www.conf;

RUN LINE="ALL=NOPASSWD: /usr/sbin/service php$PHP_VERSION-fpm reload"; \
    FILE="/etc/sudoers.d/php-fpm"; \
    grep -qF -- "$HOST_USER $LINE" "$FILE" || echo "$HOST_USER $LINE" >> "$FILE";

RUN chmod 733 /var/lib/php/sessions; \
    chmod +t /var/lib/php/sessions;

RUN if [ ! -f /usr/local/bin/composer ]; then \
    curl -sS https://getcomposer.org/installer | php; \
    mv composer.phar /usr/local/bin/composer; \
    fi;

RUN update-alternatives --set php /usr/bin/php$PHP_VERSION; \
    apt-get install -y --force-yes --no-install-recommends nginx; \
    openssl dhparam -out /etc/nginx/dhparams.pem 2048;

RUN sed -i "s/user www-data;/user $HOST_USER;/" /etc/nginx/nginx.conf; \
    sed -i "s/worker_processes.*/worker_processes auto;/" /etc/nginx/nginx.conf; \
    sed -i "s/# multi_accept.*/multi_accept on;/" /etc/nginx/nginx.conf; \
    sed -i "s/# server_names_hash_bucket_size.*/server_names_hash_bucket_size 128;/" /etc/nginx/nginx.conf;

COPY nginx/gzip.conf /etc/nginx/conf.d/gzip.conf

RUN rm /etc/nginx/sites-enabled/default; \
    rm /etc/nginx/sites-available/default; \
    mkdir -p /etc/nginx/ssl/;

COPY nginx/ssl/catch-all.invalid.crt /etc/nginx/ssl/catch-all.invalid.crt
COPY nginx/ssl/catch-all.invalid.key /etc/nginx/ssl/catch-all.invalid.key
COPY nginx/sites-available/default /etc/nginx/sites-available/000-default

RUN ln -s /etc/nginx/sites-available/000-default etc/nginx/sites-enabled/000-default; \
    usermod -a -G www-data $HOST_USER; \
    id $HOST_USER; \
    groups $HOST_USER;

RUN curl --silent --location https://deb.nodesource.com/setup_14.x | bash -; \
    apt-get update; \
    apt-get install -y --force-yes --no-install-recommends nodejs; \
    npm install -g pm2; \
    npm install -g gulp; \
    npm install -g yarn;

RUN wget -c https://dev.mysql.com/get/mysql-apt-config_0.8.15-1_all.deb; \
    dpkg --install mysql-apt-config_0.8.15-1_all.deb; \
    rm mysql-apt-config_0.8.15-1_all.deb;

RUN { \
    echo "mysql-community-server mysql-community-server/data-dir select ''"; \
    echo "mysql-community-server mysql-community-server/root-pass password $MYSQL_ROOT_PASSWORD"; \
    echo "mysql-community-server mysql-community-server/re-root-pass password $MYSQL_ROOT_PASSWORD"; \
    echo "mysql-community-server mysql-community-server/remove-test-db select false"; \
    } | debconf-set-selections \
    && apt-get update && apt-get install -y mysql-server

RUN echo "default_password_lifetime = 0" >> /etc/mysql/mysql.conf.d/mysqld.cnf; \
    RAM=$(awk '/^MemTotal:/{printf "%3.0f", $2 / (1024 * 1024)}' /proc/meminfo); \
    MAX_CONNECTIONS=$(( 70 * $RAM )); \
    REAL_MAX_CONNECTIONS=$(( MAX_CONNECTIONS>70 ? MAX_CONNECTIONS : 100 )); \
    sed -i "s/^max_connections.*=.*/max_connections=${REAL_MAX_CONNECTIONS}/" /etc/mysql/my.cnf; \
    sed -i '/^bind-address/s/bind-address.*=.*/bind-address = */' /etc/mysql/mysql.conf.d/mysqld.cnf; \
    service mysql start; \
    mysql --user="root" --password="$MYSQL_ROOT_PASSWORD" -e "CREATE USER 'root'@'%' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';"; \
    mysql --user="root" --password="$MYSQL_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON *.* TO root@'%' WITH GRANT OPTION;"; \
    mysql --user="root" --password="$MYSQL_ROOT_PASSWORD" -e "CREATE USER '$MYSQL_USER_NAME'@'%' IDENTIFIED BY '$MYSQL_USER_PASSWORD';"; \
    mysql --user="root" --password="$MYSQL_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_USER_NAME'@'%' WITH GRANT OPTION;"; \
    mysql --user="root" --password="$MYSQL_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"; \
    mysql --user="root" --password="$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE $MYSQL_DATABASE_NAME CHARACTER SET utf8 COLLATE utf8_unicode_ci;";

RUN usermod -d /var/lib/mysql/ mysql

RUN apt-get install -y --force-yes --no-install-recommends redis-server; \
    sed -i 's/bind 127.0.0.1/bind 0.0.0.0/' /etc/redis/redis.conf; \
    yes '' | pecl install -f redis; \
    if pecl list | grep redis >/dev/null 2>&1; then \
    echo "Configuring PHPRedis"; \
    echo "extension=redis.so" > /etc/php/$PHP_VERSION/mods-available/redis.ini; \
    yes '' | apt install php$PHP_VERSION-redis; \
    fi;

RUN apt-get install -y --force-yes --no-install-recommends memcached; \
    sed -i 's/-l 127.0.0.1/-l 0.0.0.0/' /etc/memcached.conf;

RUN sed -i "s/fs.protected_regular = .*/fs.protected_regular = 0/" /usr/lib/sysctl.d/protect-links.conf; \
    sysctl --system; \
    apt-get install -y --force-yes --no-install-recommends unattended-upgrades;

COPY ubuntu/50unattended-upgrades /etc/apt/apt.conf.d/50unattended-upgrades
COPY ubuntu/10periodic /etc/apt/apt.conf.d/10periodic

RUN if [ ! -f /etc/nginx/ssl/default.crt ]; then \
    openssl genrsa -out "/etc/nginx/ssl/default.key" 2048; \
    openssl req -new -key "/etc/nginx/ssl/default.key" -out "/etc/nginx/ssl/default.csr" -subj "/CN=default/O=default/C=UK"; \
    openssl x509 -req -days 365 -in "/etc/nginx/ssl/default.csr" -signkey "/etc/nginx/ssl/default.key" -out "/etc/nginx/ssl/default.crt"; \
    chmod 644 /etc/nginx/ssl/default.key; \
    fi;

COPY supervisor/supervisord.conf /etc/supervisord.conf
COPY supervisor/supervisord.d /etc/supervisord.d

RUN rm -rf /var/lib/apt/lists/*

COPY startup.sh /opt/startup.sh

RUN sed -i "s/php-fpm/php${PHP_VERSION}-fpm/" /opt/startup.sh; \
    chmod +x /opt/startup.sh;

EXPOSE 80 81 443 3306 33060 9000

WORKDIR /var/www/

CMD /opt/startup.sh
