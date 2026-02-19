#!/usr/bin/env bash

echo 'Update packages'

sudo add-apt-repository ppa:ondrej/php &> /dev/null
sudo apt update &> /dev/null
sudo apt-get autoremove -y &> /dev/null

echo 'Install base packages'
sudo apt-get install -y ghostscript imagemagick vsftpd &> /dev/null

echo 'Install PHP 5.6'
sudo apt-get install -y php5.6 libapache2-mod-php5.6 php5.6-mysql php5.6-xml &> /dev/null

echo 'Log permissions'
sudo chmod -R 777 /var/log

echo 'Install locales'
sudo locale-gen ca_ES  &> /dev/null
sudo locale-gen ca_ES.UTF-8  &> /dev/null
sudo locale-gen es_ES  &> /dev/null
sudo locale-gen es_ES.UTF-8  &> /dev/null
sudo dpkg-reconfigure locales &> /dev/null

echo 'Set Timezone'
sudo echo "Europe/Madrid" | sudo tee /etc/timezone  &> /dev/null
sudo dpkg-reconfigure -f noninteractive tzdata &> /dev/null

echo 'PHP Configuration'
sudo sed -i '$ a\date.timezone = "Europe/Madrid"' /etc/php/5.6/apache2/php.ini
sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/5.6/apache2/php.ini
sudo sed -i "s/memory_limit = .*/memory_limit = 256M/" /etc/php/5.6/apache2/php.ini
sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php/5.6/apache2/php.ini
sudo sed -i "s/display_startup_errors = .*/display_startup_errors = On/" /etc/php/5.6/apache2/php.ini
sudo sed -i "s/post_max_size = .*/post_max_size = 100M/" /etc/php/5.6/apache2/php.ini
sudo sed -i "s/upload_max_filesize = .*/upload_max_filesize = 100M/" /etc/php/5.6/apache2/php.ini
sudo sed -i "s/allow_url_fopen = .*/allow_url_fopen = Off/" /etc/php/5.6/apache2/php.ini
sudo sed -i "s/;error_log = php_errors.log/error_log = \/var\/log\/apache2\/php_errors.log/" /etc/php/5.6/apache2/php.ini
sudo sed -i "s/max_execution_time = .*/max_execution_time = 300/" /etc/php/5.6/apache2/php.ini

# Configure files encoded in ISO-8859-1 to be correctly read by PHP.
sudo sed -i 's/^;*default_charset =.*/default_charset = "ISO-8859-1"/g' /etc/php/5.6/apache2/php.ini

sudo sed -i '$ a\date.timezone = "Europe/Madrid"' /etc/php/5.6/cli/php.ini
sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/5.6/cli/php.ini
sudo sed -i "s/memory_limit = .*/memory_limit = 256M/" /etc/php/5.6/cli/php.ini
sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php/5.6/cli/php.ini
sudo sed -i "s/display_startup_errors = .*/display_startup_errors = On/" /etc/php/5.6/cli/php.ini
# Next line is commented on cli to allow composer install
#sudo sed -i "s/allow_url_fopen = .*/allow_url_fopen = Off/" /etc/php/5.6/cli/php.ini
sudo sed -i "s/;error_log = php_errors.log/error_log = \/var\/log\/apache2\/php_errors.log/" /etc/php/5.6/cli/php.ini
sudo sed -i "s/max_execution_time = .*/max_execution_time = 300/" /etc/php/5.6/cli/php.ini

sudo service apache2 restart &> /dev/null

echo 'Increase swapsize'
# size of swapfile in megabytes
swapsize=2000

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

pass='agora'

echo 'Configure MariaDB'
export DEBIAN_FRONTEND="noninteractive"

sudo apt-get update &> /dev/null

echo 'Install MariaDB server 10.6'
sudo apt-get install -y mariadb-server-10.6 &> /dev/null

echo 'Configuring root password...'
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${pass}';"
sudo mysql -e "FLUSH PRIVILEGES;"

echo 'Configuring settings...'
sudo sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/mariadb.conf.d/50-server.cnf
sudo sed -i 's/\[mysqld\]/\[mysqld\]\nwait_timeout = 100\nmax_connections=500/g' /etc/mysql/mariadb.conf.d/50-server.cnf

sudo systemctl restart mariadb &> /dev/null

echo 'Install and Configure phpMyAdmin 4.9 LTS'
PMA_VERSION="4.9.11"
wget https://files.phpmyadmin.net/phpMyAdmin/${PMA_VERSION}/phpMyAdmin-${PMA_VERSION}-all-languages.tar.gz -q

tar xzf phpMyAdmin-${PMA_VERSION}-all-languages.tar.gz
sudo mv phpMyAdmin-${PMA_VERSION}-all-languages /usr/share/phpmyadmin
rm phpMyAdmin-${PMA_VERSION}-all-languages.tar.gz

sudo cp /usr/share/phpmyadmin/config.sample.inc.php /usr/share/phpmyadmin/config.inc.php

SECRET=$(openssl rand -base64 22)
sudo sed -i "s/\['blowfish_secret'\] = '';/\['blowfish_secret'\] = '$SECRET';/" /usr/share/phpmyadmin/config.inc.php

sudo chown -R www-data:www-data /usr/share/phpmyadmin
sudo mkdir -p /var/lib/phpmyadmin/tmp
sudo chown -R www-data:www-data /var/lib/phpmyadmin

sudo bash -c 'cat > /etc/apache2/conf-available/phpmyadmin.conf << EOF
Alias /phpmyadmin /usr/share/phpmyadmin

<Directory /usr/share/phpmyadmin>
    Options SymLinksIfOwnerMatch
    DirectoryIndex index.php
    AllowOverride All
    Require all granted
</Directory>
EOF'

sudo a2enconf phpmyadmin &> /dev/null
sudo systemctl restart apache2 &> /dev/null

echo 'Process completed successfully'
