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

echo 'Install PHP 8.4'
sudo apt-get install -y libapache2-mod-php8.4 php8.4-common php8.4-ldap php8.4-zip php8.4-imap php8.4-intl php8.4-mbstring php8.4-mysql php8.4-pgsql php8.4-xml php8.4-gd php8.4-xmlrpc php8.4-curl php8.4-soap php8.4-sqlite3 php8.4-redis php-imagick &> /dev/null

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
sudo sed -i '$ a\date.timezone = "Europe/Madrid"' /etc/php/8.4/apache2/php.ini
sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/8.4/apache2/php.ini
sudo sed -i "s/memory_limit = .*/memory_limit = 256M/" /etc/php/8.4/apache2/php.ini
sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php/8.4/apache2/php.ini
sudo sed -i "s/display_startup_errors = .*/display_startup_errors = On/" /etc/php/8.4/apache2/php.ini
sudo sed -i "s/post_max_size = .*/post_max_size = 100M/" /etc/php/8.4/apache2/php.ini
sudo sed -i "s/upload_max_filesize = .*/upload_max_filesize = 100M/" /etc/php/8.4/apache2/php.ini
sudo sed -i "s/;max_input_vars = .*/max_input_vars = 6000/" /etc/php/8.4/apache2/php.ini
sudo sed -i "s/allow_url_fopen = .*/allow_url_fopen = Off/" /etc/php/8.4/apache2/php.ini
sudo sed -i "s/;error_log = php_errors.log/error_log = \/var\/log\/apache2\/php_errors.log/" /etc/php/8.4/apache2/php.ini
sudo sed -i "s/max_execution_time = .*/max_execution_time = 300/" /etc/php/8.4/apache2/php.ini

sudo sed -i '$ a\date.timezone = "Europe/Madrid"' /etc/php/8.4/cli/php.ini
sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/8.4/cli/php.ini
sudo sed -i "s/memory_limit = .*/memory_limit = 256M/" /etc/php/8.4/cli/php.ini
sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php/8.4/cli/php.ini
sudo sed -i "s/display_startup_errors = .*/display_startup_errors = On/" /etc/php/8.4/cli/php.ini
# Next line is commented on cli to allow composer install
#sudo sed -i "s/allow_url_fopen = .*/allow_url_fopen = Off/" /etc/php/8.4/cli/php.ini
sudo sed -i "s/;error_log = php_errors.log/error_log = \/var\/log\/apache2\/php_errors.log/" /etc/php/8.4/cli/php.ini
sudo sed -i "s/max_execution_time = .*/max_execution_time = 300/" /etc/php/8.4/cli/php.ini
sudo sed -i "s/;max_input_vars = .*/max_input_vars = 6000/" /etc/php/8.4/cli/php.ini

# Log
sudo sed -i "s/create 640.*/create 777 vagrant vagrant/" /etc/logrotate.d/apache2
sudo chmod -R 777 /var/log/apache2/
sudo chown -R vagrant:vagrant /var/log/apache2/

# Make Vagrant execute apache
sudo sed -i "s/export APACHE_RUN_USER=.*/export APACHE_RUN_USER=vagrant/" /etc/apache2/envvars
sudo sed -i "s/export APACHE_RUN_GROUP=.*/export APACHE_RUN_GROUP=vagrant/" /etc/apache2/envvars
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

#echo 'Install MySQL server 8.0'
#sudo apt-get install -y mysql-server-8.0 &> /dev/null

echo 'Install MySQL server 8.4'
sudo apt install wget gnupg -y &> /dev/null
pushd /tmp &> /dev/null || exit
wget https://dev.mysql.com/get/mysql-apt-config_0.8.39-1_all.deb &> /dev/null
echo "mysql-apt-config mysql-apt-config/select-server select mysql-8.4-lts" | sudo debconf-set-selections
echo "mysql-apt-config mysql-apt-config/select-product select Ok" | sudo debconf-set-selections
sudo -E dpkg -i --force-confold mysql-apt-config_0.8.39-1_all.deb &> /dev/null
sudo -E apt update &> /dev/null
echo "mysql-community-server mysql-community-server/root-pass password $pass" | sudo debconf-set-selections
echo "mysql-community-server mysql-community-server/re-root-pass password $pass" | sudo debconf-set-selections
echo "mysql-community-server mysql-community-server/authentication-method select Use Strong Password Encryption (RECOMMENDED)" | sudo debconf-set-selections
sudo -E apt-get install -y mysql-server &> /dev/null
popd &> /dev/null || exit

sudo sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo sed -i 's/\[mysqld\]/\[mysqld\]\nwait_timeout = 100\nmax_connections=500/g' /etc/mysql/mysql.conf.d/mysqld.cnf

sudo service mysql restart

# Download phpMyAdmin from the web instead of using system package to avoid dependencies issues.
echo 'Install phpMyAdmin'
pushd /var/www &> /dev/null || exit
sudo wget https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz &> /dev/null
sudo mkdir phpmyadmin && sudo chown vagrant:vagrant phpmyadmin && tar -xvzf phpMyAdmin-latest-all-languages.tar.gz -C phpmyadmin --strip-components 1 &> /dev/null
sudo rm phpMyAdmin-latest-all-languages.tar.gz &> /dev/null

# Configure phpMyAdmin
cp phpmyadmin/config.sample.inc.php phpmyadmin/config.inc.php
sudo sed -i "s/.*\['auth_type'\].*/\$cfg['Servers'][\$i]['auth_type'] = 'config';\n\$cfg['Servers'][\$i]['user'] = 'root';\n\$cfg['Servers'][\$i]['password'] = 'agora';/" phpmyadmin/config.inc.php
popd &> /dev/null || exit
sudo sed -i '/<\/VirtualHost>/i \    Alias /phpmyadmin /var/www/phpmyadmin\n\n    <Directory /var/www/phpmyadmin>\n        Options Indexes FollowSymLinks\n        AllowOverride All\n        Require all granted\n    </Directory>\n' /etc/apache2/sites-available/000-default.conf

sudo service apache2 restart

#echo 'Install postgreSQL'
#sudo apt-get install -y postgresql postgresql-contrib &> /dev/null

echo 'Process completed successfully'
