FROM ubuntu:20.04

ENV HOST_NAME=lemp_host \
    HOST_USER=lemp_user \
    HOST_USER_PASSWORD=123321 \
    \
    GIT_USER=DevOPS \
    GIT_EMAIL=devops@flexmade.com \
    \
    PHP_VERSION=7.4 \
    PHP_MEMORY_LIMIT=512M \
    PHP_DISPLAY_ERRORS=On \
    PHP_ERROR_REPORTING=E_ALL \
    PHP_TIMEZONE=UTC \
    PHP_PATHINFO=0 \
    \
    MYSQL_USER_NAME=lemp_user \
    MYSQL_USER_PASSWORD=123321 \
    MYSQL_ROOT_PASSWORD=123321 \
    MYSQL_DATABASE_NAME=lemp_db

RUN set -eux; \
    apt-get update; \
    apt-get upgrade -y; \
    apt-get install -y --force-yes software-properties-common; \
    apt-add-repository ppa:ondrej/nginx -y; \
    apt-add-repository ppa:ondrej/php -y; \
    apt-get update; \
    add-apt-repository universe; \
    apt-get install -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y --force-yes build-essential sudo curl pkg-config fail2ban gcc g++ git libmcrypt4 libpcre3-dev \
    make python3 python3-pip wget sendmail supervisor mc zip unzip whois zsh ncdu bash cron logrotate uuid-runtime acl libpng-dev libmagickwand-dev; \
    pip3 install httpie; \
    pip3 install awscli; \
    pip3 install awscli-plugin-endpoint;

RUN apt-get install -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y --force-yes \
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

RUN sed -i "s/error_reporting = .*/error_reporting = $PHP_ERROR_REPORTING/" /etc/php/$PHP_VERSION/cli/php.ini; \
    sed -i "s/display_errors = .*/display_errors = $PHP_DISPLAY_ERRORS/" /etc/php/$PHP_VERSION/cli/php.ini; \
    sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=$PHP_PATHINFO/" /etc/php/$PHP_VERSION/cli/php.ini; \
    sed -i "s/memory_limit = .*/memory_limit = $PHP_MEMORY_LIMIT/" /etc/php/$PHP_VERSION/cli/php.ini; \
    sed -i "s/;date.timezone.*/date.timezone = $PHP_TIMEZONE/" /etc/php/$PHP_VERSION/cli/php.ini;

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
    apt-get install -y --force-yes nginx; \
    systemctl enable nginx.service; \
    openssl dhparam -out /etc/nginx/dhparams.pem 2048;

RUN sed -i "s/user www-data;/user $HOST_USER;/" /etc/nginx/nginx.conf; \
    sed -i "s/worker_processes.*/worker_processes auto;/" /etc/nginx/nginx.conf; \
    sed -i "s/# multi_accept.*/multi_accept on;/" /etc/nginx/nginx.conf; \
    sed -i "s/# server_names_hash_bucket_size.*/server_names_hash_bucket_size 128;/" /etc/nginx/nginx.conf;

RUN echo '\n\
gzip_comp_level 5;\n\
gzip_min_length 256;\n\
gzip_proxied any;\n\
gzip_vary on;\n\
gzip_http_version 1.1;\n\
gzip_types \n\
application/atom+xml\n\
application/javascript\n\
application/json\n\
application/ld+json\n\
application/manifest+json\n\
application/rss+xml\n\
application/vnd.geo+json\n\
application/vnd.ms-fontobject\n\
application/x-font-ttf\n\
application/x-web-app-manifest+json\n\
application/xhtml+xml\n\
application/xml\n\
font/opentype\n\
image/bmp\n\
image/svg+xml\n\
image/x-icon\n\
text/cache-manifest\n\
text/css\n\
text/plain\n\
text/vcard\n\
text/vnd.rim.location.xloc\n\
text/vtt\n\
text/x-component\n\
text/x-cross-domain-policy;'>> /etc/nginx/conf.d/gzip.conf

RUN rm /etc/nginx/sites-enabled/default; \
    rm /etc/nginx/sites-available/default; \
    service nginx restart; \
    mkdir -p /etc/nginx/ssl/;

RUN echo '-----BEGIN CERTIFICATE-----\n\
MIIC1TCCAb2gAwIBAgIJAOzFtsytI2mWMA0GCSqGSIb3DQEBBQUAMBoxGDAWBgNV\n\
BAMTD3d3dy5leGFtcGxlLmNvbTAeFw0yMTA1MDMxNTU4MTVaFw0zMTA1MDExNTU4\n\
MTVaMBoxGDAWBgNVBAMTD3d3dy5leGFtcGxlLmNvbTCCASIwDQYJKoZIhvcNAQEB\n\
BQADggEPADCCAQoCggEBALqkjykou8/yD6rUuz91ZvKC0b7HOZrGmZoenZD1qI85\n\
fHg1v7aavJPaXvhXHstUq6Vu6oTR/XDLhqKAOUfiRMFF7i2al8cB0VOmNtH8IGfh\n\
c5EGZO2uvQRwPUhipdkJWGFDPlME8fNsnCJcUKebaiwYlen00GEgwKUTNrYNLcBN\n\
POTLm9FdiEtTmSIbm7DmVFEVqF1zD/mOzEvU9exeZM8bn0GYAu+/qEUBDYtNWnnr\n\
eQQIhjH1CBagvZn+JRpfNydASIMbu7oMVR7GiooR5KwqJBCqRMSHJEMeMIksP04G\n\
myMQG0lSS3bnXxm2pVnFW8Xstu7q+4RkPyNP8tS77TECAwEAAaMeMBwwGgYDVR0R\n\
BBMwEYIPd3d3LmV4YW1wbGUuY29tMA0GCSqGSIb3DQEBBQUAA4IBAQA8veEEhCEj\n\
evVUpfuh74SgmAWfBQNjSnwqPm20NnRiT3Khp7avvOOgapep31CdGI4cd12PFrqC\n\
wh9ov/Y28Cw191usUbLSoYvIs2VUrv8jNXh/V20s6rKICz292FMmNvKtBVf3dGz6\n\
dYmbW9J9H44AH/q/y3ljQgCmxFJgAAvAAiKgD9Bf5Y8GvFP7EFyqWOwWTwls91QL\n\
lDDbKOegoD1KRRpFZV8qVhMx6lzyAqzK0U9GZGCANv6II5zEgDDXGKt1OVL+90ri\n\
KuGJW+cmqv00F+/bgvNNhIu2tZt/wN3oPEJVjEj0Z5d8+gvo0NHwlwGYrgjHlSpV\n\
2G5KyvZe5dES\n\
-----END CERTIFICATE-----'>> /etc/nginx/ssl/catch-all.invalid.crt;\
echo '-----BEGIN RSA PRIVATE KEY-----\n\
MIIEpAIBAAKCAQEAuqSPKSi7z/IPqtS7P3Vm8oLRvsc5msaZmh6dkPWojzl8eDW/\n\
tpq8k9pe+Fcey1SrpW7qhNH9cMuGooA5R+JEwUXuLZqXxwHRU6Y20fwgZ+FzkQZk\n\
7a69BHA9SGKl2QlYYUM+UwTx82ycIlxQp5tqLBiV6fTQYSDApRM2tg0twE085Mub\n\
0V2IS1OZIhubsOZUURWoXXMP+Y7MS9T17F5kzxufQZgC77+oRQENi01aeet5BAiG\n\
MfUIFqC9mf4lGl83J0BIgxu7ugxVHsaKihHkrCokEKpExIckQx4wiSw/TgabIxAb\n\
SVJLdudfGbalWcVbxey27ur7hGQ/I0/y1LvtMQIDAQABAoIBAQCoJUycRgg9pNOc\n\
kZ5H41rlrBmOCCnLWJRVFrPZPpemwKF0IugeeHTftuHMVaB2ikdA+RXqpsvu7EzU\n\
5TO1oRFUFc4n45hNP0P4WkwVDVGchK36v4n532yGLR/osIa9av/mUBA79r6LERPw\n\
mL5I4WjbZSLZ7SY1+q3TieXGSUUocmHGzgtSQ5lIKGC6ppE/3GBqoSJB24sEhpqp\n\
qnRs3mPe8q6ZhZLAqoEWni/4XrDycVE/BTgVb3qbZe+/4orPvSxLXEQIdvuxI4Mh\n\
MqKZHeS2DSAQd845YgiR2MjlgjPJU7LaIQSjWkfgDIw9iHIbUcaLYEcMtfCu+xPE\n\
d9eZNJQBAoGBAO6RbNavi1w/VjNsmgiFmXIAz5cn1bxkLWpoCq1oXN9uRMKPvBcG\n\
xuKdAVVewvXVD9WEM1CSKeqWSH3mcxxqHaOyqy0aZrk98pphMSvo9QCaoaZP+68H\n\
NQ1g/Ws82HUS7bVPULgMHFkLu1t1DcfYADjvVrgYuTrrL9yBeyj3b1ORAoGBAMhH\n\
1mWaMK3hySMhlfQ7DMfrwsou4tgvALrnkyxyr1FgXCZGJ5ckaVVBmwLns3c5A6+1\n\
MDlMVoXWKI7DSjEh7RPxa02QQTS2FWR0ARvf/Wm8WdGyh7k+0L/y+K+66fZjwLsa\n\
Gjiq7BnvQAt5NgJI9i8wxxWqTVcGKHeM7No7dO+hAoGAalDYphv5CRUYvzYItv+C\n\
0HFYEc6oy5oBO0g+aeT2boPflK0lb0WP4HGDpJ3kWFWpBsgxbhiVIXvztle6uND5\n\
gHghHKqFWMwoj2/8z8qzVJ+Upl9ClE+r7thoVx/4fsP+tywvlrWe9Hfr+OgDSioS\n\
f0z54nTyJzWkUKpLTohmTmECgYASIAY0HbcoFVXpmwGCH9HxSdHQEFwxKlfLkmeM\n\
Tzi0iZ7tS84LbJ0nvQ81PRjNwlgmD6S0msb9x7rV6LCPL73P3zpRw6tTBON8us7a\n\
4fOCHSyXwKttxVSI+oktBiJkTPTFOgCDflxtoGxQXYDYxheZf7WUrVvgc0s4PoW0\n\
3kqf4QKBgQCvFTk0uBaZ9Aqslty0cPA2LoVclmQZenbxPSRosEYVQJ6urEpoolss\n\
W2v3zRTw+Pv3bXxS2F6z6C5whOeaq2V8epF4LyXDBZhiF+ayxUgA/hJAZqoeSrMB\n\
ziOvF1n30W8rVLx3HjfpA5eV2BbT/4NChXwlPTbCd9xy11GimqPsNQ==\n\
-----END RSA PRIVATE KEY-----' >> /etc/nginx/ssl/catch-all.invalid.key;

RUN echo '\n\
server {\n\
    listen 80 default_server;\n\
    listen [::]:80 default_server;\n\
    listen 443 ssl default_server;\n\
    server_name _;\n\
    \n\
    ssl_certificate /etc/nginx/ssl/catch-all.invalid.crt;\n\
    ssl_certificate_key /etc/nginx/ssl/catch-all.invalid.key;\n\
    \n\
    add_header X-Frame-Options "SAMEORIGIN";\n\
    add_header X-XSS-Protection "1; mode=block";\n\
    add_header X-Content-Type-Options "nosniff";\n\
    \n\
    root /var/www/html/public;\n\
    \n\
    index index.html index.htm index.php;\n\
    \n\
    charset utf-8;\n\
    \n\
    location / {\n\
    try_files $uri $uri/ /index.php?$query_string;\n\
    }\n\
    \n\
    location = /favicon.ico { access_log off; log_not_found off; }\n\
    location = /robots.txt  { access_log off; log_not_found off; }\n\
    \n\
    location ~ \.php$ {\n\
        fastcgi_pass unix:/var/run/php/php-fpm.sock;\n\
        fastcgi_index index.php;\n\
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;\n\
        include fastcgi_params;\n\
    }\n\
    \n\
    location ~ /\.(?!well-known).* {\n\
        deny all;\n\
    }\n\
    \n\
    error_page 404 /index.php;\n\
    \n\
    access_log /var/log/nginx/access.log combined;\n\
    error_log  /var/log/nginx/error.log error;\n\
}' >> /etc/nginx/sites-available/000-default; \
sed -i "s/php-fpm/php${PHP_VERSION}-fpm/" /etc/nginx/sites-available/000-default; \
ln -s /etc/nginx/sites-available/000-default /etc/nginx/sites-enabled/000-default;

RUN NGINX=$(ps aux | grep nginx | grep -v grep); \
    if [[ -z $NGINX ]]; then \
    service nginx start; \
    echo "Started Nginx"; \
    else \
    service nginx reload; \
    echo "Reloaded Nginx"; \
    fi;

RUN PHP=$(ps aux | grep php-fpm | grep -v grep);\
    if [[ ! -z $PHP ]]; then \
    service php$PHP_VERSION-fpm restart > /dev/null 2>&1; \
    fi;

RUN usermod -a -G www-data $HOST_USER; \
    id $HOST_USER; \
    groups $HOST_USER;

RUN curl --silent --location https://deb.nodesource.com/setup_14.x | bash -; \
    apt-get update; \
    apt-get install -y --force-yes nodejs; \
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
    echo "" >> /etc/mysql/my.cnf; \
    echo "[mysqld]" >> /etc/mysql/my.cnf; \
    echo "default_authentication_plugin=mysql_native_password" >> /etc/mysql/my.cnf; \
    echo "skip-log-bin" >> /etc/mysql/my.cnf; \
    RAM=$(awk '/^MemTotal:/{printf "%3.0f", $2 / (1024 * 1024)}' /proc/meminfo); \
    MAX_CONNECTIONS=$(( 70 * $RAM )); \
    REAL_MAX_CONNECTIONS=$(( MAX_CONNECTIONS>70 ? MAX_CONNECTIONS : 100 )); \
    sed -i "s/^max_connections.*=.*/max_connections=${REAL_MAX_CONNECTIONS}/" /etc/mysql/my.cnf; \
    sed -i '/^bind-address/s/bind-address.*=.*/bind-address = */' /etc/mysql/mysql.conf.d/mysqld.cnf; \
    mysql --user="root" --password="$MYSQL_ROOT_PASSWORD" -e "CREATE USER 'root'@'%' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';"; \
    mysql --user="root" --password="$MYSQL_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON *.* TO root@'%' WITH GRANT OPTION;"; \
    service mysql restart; \
    mysql --user="root" --password="$MYSQL_ROOT_PASSWORD" -e "CREATE USER '$MYSQL_USER_NAME'@'%' IDENTIFIED BY '$MYSQL_USER_PASSWORD';"; \
    mysql --user="root" --password="$MYSQL_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_USER_NAME'@'%' WITH GRANT OPTION;"; \
    mysql --user="root" --password="$MYSQL_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"; \
    mysql --user="root" --password="$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE $MYSQL_DATABASE_NAME CHARACTER SET utf8 COLLATE utf8_unicode_ci;";

RUN service mysql stop; \
    usermod -d /var/lib/mysql/ mysql; \
    service mysql start;

RUN apt-get install -y --force-yes redis-server; \
    sed -i 's/bind 127.0.0.1/bind 0.0.0.0/' /etc/redis/redis.conf; \
    service redis-server restart; \
    systemctl enable redis-server; \
    yes '' | pecl install -f redis; \
    if pecl list | grep redis >/dev/null 2>&1; then \
    echo "Configuring PHPRedis"; \
    echo "extension=redis.so" > /etc/php/$PHP_VERSION/mods-available/redis.ini; \
    yes '' | apt install php$PHP_VERSION-redis; \
    fi;

RUN apt-get install -y --force-yes memcached; \
    sed -i 's/-l 127.0.0.1/-l 0.0.0.0/' /etc/memcached.conf; \
    service memcached restart;

RUN systemctl enable supervisor.service; \
    service supervisor start;

RUN sed -i "s/fs.protected_regular = .*/fs.protected_regular = 0/" /usr/lib/sysctl.d/protect-links.conf; \
    sysctl --system; \
    apt-get install -y --force-yes unattended-upgrades;

RUN echo '\n\
Unattended-Upgrade::Allowed-Origins {\n\
"Ubuntu focal-security";\n\
};\n\
Unattended-Upgrade::Package-Blacklist {\n\
};' >> /etc/apt/apt.conf.d/50unattended-upgrades

RUN echo 'APT::Periodic::Update-Package-Lists "1";\n\
APT::Periodic::Download-Upgradeable-Packages "1";\n\
APT::Periodic::AutocleanInterval "7";\n\
APT::Periodic::Unattended-Upgrade "1";' >> /etc/apt/apt.conf.d/10periodic

RUN if [ ! -f /etc/nginx/ssl/default.crt ]; then \
    openssl genrsa -out "/etc/nginx/ssl/default.key" 2048; \
    openssl req -new -key "/etc/nginx/ssl/default.key" -out "/etc/nginx/ssl/default.csr" -subj "/CN=default/O=default/C=UK"; \
    openssl x509 -req -days 365 -in "/etc/nginx/ssl/default.csr" -signkey "/etc/nginx/ssl/default.key" -out "/etc/nginx/ssl/default.crt"; \
    chmod 644 /etc/nginx/ssl/default.key; \
    fi;

EXPOSE 80 81 443 3306 33060 9000

WORKDIR /var/www/

RUN service mysql start; \
    service redis-server start;

RUN echo '#!/bin/bash\n\
\n\
service mysql start\n\
service cron start\n\
service memcached start\n\
service redis-server start\n\
service supervisor start\n\
service php-fpm start\n\
nginx -g "daemon off;"\n\' >> /opt/startup.sh; \
sed -i "s/php-fpm/php${PHP_VERSION}-fpm/" /opt/startup.sh; \
chmod +x /opt/startup.sh;

CMD /opt/startup.sh
