#! /bin/bash
# tem que dar o comandos a seguir antes de rodar o script
# sudo chmod +x install_laravel.sh
# sudo su
###########################################################
# ------------- On CentOS/RHEL 7.x ------------- 
rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-7.rpm

#  'Update and Upgrade'
yum -y update && yum -y upgrade
#  'instala uns programas básicos'
yum -y install lsb-release apt-transport-https ca-certificates wget redis-server nginx unzip libcurl4-openssl-dev
#  'adicliona mais lista de pacotes'
# wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
# echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
#  'update novamente'
yum update -y
#  'instala php 8'
yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum -y install https://rpms.remirepo.net/enterprise/remi-release-7.rpm
yum -y install https://extras.getpagespeed.com/release-el7-latest.rpm
rpm -ivh http://rpms.famillecollet.com/enterprise/remi-release-7.rpm

yum -y install yum-utils
yum-config-manager --disable 'remi-php*'
yum-config-manager --enable remi-php80
yum -y install php php-{common,mysql,xml,xmlrpc,curl,gd,imagick,cli,dev,imap,mbstring,opcache,soap,zip,intl,bcmath,ldap,sqlite,fpm,pear,devel}
#  'instala extensions'
yum -y install curl git unzip supervisor gcc glibc-headers gcc-c++ openssl-devel epel-release
#  'COMPOSER'
# curl -sS https://getcomposer.org/installer | php 
sudo mv composer.phar /usr/bin/composer
chmod +x/usr/bin/composer

# Instala Laravel
cd /var/www/
# composer create-project --no-interaction --prefer-dist laravel/laravel laravel
git clone http://172.16.10.33:80/FBB/SIGA-Nova.git laravel
cd laravel
composer install --no-dev
cp .env.example .env

# da permissoes
chown -R nginx:root /var/www/laravel/storage/
chown -R nginx:root /var/www/laravel/bootstrap/cache/
chown -R nginx:nginx /var/www/laravel
chown -R nginx:nginx /var/www/laravel/storage/
chmod -R 755 storage
chmod -R 755 bootstrap/cache

# Configura nginx
sudo systemctl stop  nginx
sudo systemctl enable nginx
rm -rf /var/www/html
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
cp laravel.conf /etc/nginx/conf.d/laravel.conf
cp laravel.conf /etc/nginx/nginx.conf

#Install 'policycoreutils-python' 
yum -y install policycoreutils-python

#change the context of the laravel project directories
semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/laravel(/.*)?'
semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/laravel/public(/.*)?'
semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/laravel/storage(/.*)?'
semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/laravel/app(/.*)?'
semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/laravel/bootstrap(/.*)?'
semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/laravel/config(/.*)?'
semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/laravel/database(/.*)?'
semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/laravel/resources(/.*)?'
semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/laravel/routes(/.*)?'
semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/laravel/vendor(/.*)?'
semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/laravel/tests(/.*)?'

#run SELinux restorecon command
restorecon -Rv '/var/www/laravel/'

#============= INSTALL REDIS ==============
#1. install redis (make sure EPEL repository is already installed)
yum -y install redis
#2. start redis service
systemctl start redis
#3. start redis on server boot
systemctl enable redis


#===== INSTALL SUPERVISOR ======
yum -y install supervisor

# Queue workers
bash -c 'printf "[program:laravel-worker]
process_name=laravel_worker
command=php /var/www/laravel/artisan queue:work --sleep=3 --tries=3
autostart=true
autorestart=true
user=root
numprocs=1
redirect_stderr=true
stdout_logfile=/var/www/laravel/storage/logs/worker.log
stopwaitsecs=3600" > /etc/supervisord.d/laravel-worker.ini'

supervisord -c /etc/supervisord.conf

# 4. read the newly edited config file:
supervisorctl reread

# 5. update the config:
supervisorctl update

# 6. start the queue worker:
supervisorctl start laravel-worker:*

#pra ver se esta funcionandoo
#supervisorctl status
#laravel-worker:laravel_worker    RUNNING   pid 105535, uptime 0:00:03

# Lembrar de alterar o usuário no final do comando
bash -c 'echo "* * * * * /var/www/laravel && php artisan schedule:run >> /dev/null 2>&1" >>  /var/spool/cron/crontabs/root'
service cron start
apt autoremove -y

# Adiciona algumas coisas no supervisor

# Inicia servicos
systemctl start nginx
systemctl enable nginx
exit