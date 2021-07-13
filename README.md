# Docker LEMP Configuration 

Basic configuration to work with
- Nginx
- PHP
- MySQL
- Memcached
- Redis
- Supervisor

Nginx configured to work with Laravel as default, root path look on `/var/www/html/public`
You can use volumes to share internal project with container.
If you want to update any from these envs:
HOST_NAME=lemp_host
HOST_USER=lemp_user
HOST_USER_PASSWORD=123321

GIT_USER=DevOPS
GIT_EMAIL=devops@mail.com

PHP_VERSION=7.4
PHP_MEMORY_LIMIT=512M
PHP_DISPLAY_ERRORS=On
PHP_ERROR_REPORTING=E_ALL
PHP_TIMEZONE=UTC
PHP_PATHINFO=0

MYSQL_USER_NAME=lemp_user
MYSQL_USER_PASSWORD=123321
MYSQL_ROOT_PASSWORD=123321
MYSQL_DATABASE_NAME=lemp_db
