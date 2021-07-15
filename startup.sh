#!/bin/bash
service mysql start
service cron start
service memcached start
service redis-server start
service supervisor start -n -c /etc/supervisord.conf
service php-fpm start

nginx -g "daemon off;"
