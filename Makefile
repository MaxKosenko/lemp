build:
	docker build \
	--build-arg HOST_NAME=lemp_host \
	--build-arg HOST_USER=lemp_user \
	--build-arg HOST_USER_PASSWORD=123321 \
	--build-arg PHP_VERSION=7.4 \
	--build-arg MYSQL_USER_NAME=lemp_user \
	--build-arg MYSQL_USER_PASSWORD=123321 \
	--build-arg MYSQL_ROOT_PASSWORD=123321 \
	--build-arg MYSQL_DATABASE_NAME=lemp_db \
	-t lemp .
run:
	docker run -p 80:80 -p 3306:3306 -v /Users/maxkosenko/Projects/TMP/DockerLemp/src:/var/www/html -w /var/www/html --privileged --name web -it --rm -d lemp 
bash:
	docker run -p 80:80 -p 3306:3306 -v /Users/maxkosenko/Projects/TMP/DockerLemp/src:/var/www/html -w /var/www/html --privileged --name web -it --rm lemp bash 
stop:
	docker stop web
exec:
	docker exec -it web bash