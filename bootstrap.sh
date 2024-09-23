#!/usr/bin/env bash

pass='agora'

# size of swapfile in megabytes
swapsize=2000

echo 'Add repository ondrej/php'
sudo add-apt-repository ppa:ondrej/php &> /dev/null

echo 'Update packages'
sudo apt-get update &> /dev/null
sudo apt-get autoremove -y  &> /dev/null

echo 'Install base packages'
sudo apt-get install -y ghostscript imagemagick vsftpd openssl zip unzip &> /dev/null

echo 'Install PHP 8.3'
sudo apt-get install -y libapache2-mod-php8.3 php8.3-common php8.3-ldap php8.3-zip php8.3-imap php8.3-intl php8.3-mbstring php8.3-mysql php8.3-pgsql php8.3-xml php8.3-gd php8.3-xmlrpc php8.3-curl php8.3-soap php8.3-sqlite3 php-imagick php8.3-gettext &> /dev/null

echo 'Log permissions'
sudo chmod -R 777 /var/log

echo 'Install locales'
sudo locale-gen ca_ES  &> /dev/null
sudo locale-gen ca_ES.UTF-8  &> /dev/null
sudo locale-gen es_ES  &> /dev/null
sudo locale-gen es_ES.UTF-8  &> /dev/null
sudo dpkg-reconfigure -f noninteractive locales &> /dev/null

echo 'Set Timezone'
sudo echo "Europe/Madrid" | sudo tee /etc/timezone  &> /dev/null
sudo dpkg-reconfigure -f noninteractive tzdata &> /dev/null

echo 'PHP Configuration'
sudo sed -i '$ a\date.timezone = "Europe/Madrid"' /etc/php/8.3/apache2/php.ini
sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/8.3/apache2/php.ini
sudo sed -i "s/memory_limit = .*/memory_limit = 256M/" /etc/php/8.3/apache2/php.ini
sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php/8.3/apache2/php.ini
sudo sed -i "s/display_startup_errors = .*/display_startup_errors = On/" /etc/php/8.3/apache2/php.ini
sudo sed -i "s/post_max_size = .*/post_max_size = 100M/" /etc/php/8.3/apache2/php.ini
sudo sed -i "s/upload_max_filesize = .*/upload_max_filesize = 100M/" /etc/php/8.3/apache2/php.ini
sudo sed -i "s/;max_input_vars = .*/max_input_vars = 6000/" /etc/php/8.3/apache2/php.ini
sudo sed -i "s/allow_url_fopen = .*/allow_url_fopen = Off/" /etc/php/8.3/apache2/php.ini
sudo sed -i "s/;error_log = php_errors.log/error_log = \/var\/log\/apache2\/php_errors.log/" /etc/php/8.3/apache2/php.ini
sudo sed -i "s/max_execution_time = .*/max_execution_time = 300/" /etc/php/8.3/apache2/php.ini

sudo sed -i '$ a\date.timezone = "Europe/Madrid"' /etc/php/8.3/cli/php.ini
sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/8.3/cli/php.ini
sudo sed -i "s/memory_limit = .*/memory_limit = 256M/" /etc/php/8.3/cli/php.ini
sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php/8.3/cli/php.ini
sudo sed -i "s/display_startup_errors = .*/display_startup_errors = On/" /etc/php/8.3/cli/php.ini
# Next line is commented on cli to allow composer install
#sudo sed -i "s/allow_url_fopen = .*/allow_url_fopen = Off/" /etc/php/8.3/cli/php.ini
sudo sed -i "s/;error_log = php_errors.log/error_log = \/var\/log\/apache2\/php_errors.log/" /etc/php/8.3/cli/php.ini
sudo sed -i "s/max_execution_time = .*/max_execution_time = 300/" /etc/php/8.3/cli/php.ini

sudo sed -i "s/www-data/ubuntu/g" /etc/apache2/envvars

# Log
sudo sed -i "s/create 640.*/create 777 vagrant vagrant/" /etc/logrotate.d/apache2
sudo chmod -R 777 /var/log/apache2/
sudo chown -R vagrant:vagrant /var/log/apache2/

# Make Vagrant execute apache
sudo sed -i "s/export APACHE_RUN_USER=.*/export APACHE_RUN_USER=vagrant/" /etc/apache2/envvars
sudo chown -R vagrant /var/lock/apache2
sudo adduser vagrant www-data

sudo service apache2 restart

echo 'Increase swapsize'
# Does the swap file already exist?
grep -q "swapfile" /etc/fstab

# If not, create it
if [ $? -ne 0 ]; then
  echo 'swapfile not found. Adding swapfile.'
  fallocate -l ${swapsize}M /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap defaults 0 0' >> /etc/fstab
else
  echo 'swapfile found. No changes made.'
fi

echo 'Configure MySQL'
export DEBIAN_FRONTEND="noninteractive"
sudo debconf-set-selections <<< "mysql-server-8.0 mysql-server/root_password password $pass"
sudo debconf-set-selections <<< "mysql-server-8.0 mysql-server/root_password_again password $pass"

sudo apt-get update &> /dev/null

echo 'Install MySQL server 8.0'
sudo apt-get install -y mysql-server-8.0 &> /dev/null

sudo sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo sed -i 's/\[mysqld\]/\[mysqld\]\nwait_timeout = 100\nmax_connections=500/g' /etc/mysql/mysql.conf.d/mysqld.cnf

sudo service mysql restart

echo 'Configure phpMyAdmin'
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password $pass"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password $pass"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password $pass"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"

echo 'Install phpMyAdmin'
sudo apt-get install -y phpmyadmin &> /dev/null

sudo sed -i "s/.*\['auth_type'\].*/\$cfg['Servers'][\$i]['auth_type'] = 'config';\n\$cfg['Servers'][\$i]['user'] = 'root';\n\$cfg['Servers'][\$i]['password'] = 'agora';/" /etc/phpmyadmin/config.inc.php
sudo sed -i '/^.*open_basedir/ s/$/:\/tmp\//' /etc/apache2/conf-available/phpmyadmin.conf

echo 'Install postgreSQL'
sudo apt-get install -y postgresql postgresql-contrib &> /dev/null

echo 'Process completed successfully'

