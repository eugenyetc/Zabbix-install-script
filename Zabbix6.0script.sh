#!/bin/bash

# Скрипт установки и базовой конфигурации сервера Zabbix 6.0LTS. 
# В скрипте ставятся дополнительные пакеты для удобства работы как с самим Zabbix так и с OS. В данном примере используется платформа Debian 11.
# (myzabbix дефолтный пароль) пароль root для MariaDB рекомендуется изменить на более сложный.


# Обновление системы
sudo apt update && apt upgrade -y


# Установка доплнительных компонетов и программ для удобства работы с ОС
sudo apt install -y nginx mariadb-server mariadb-client php-fpm php-mysql php-mbstring php-xml snmp mc git mtr sudo


# Скачать Zabbix 6.0 с официального репозитория
sudo wget https://repo.zabbix.com/zabbix/6.0/debian/pool/main/z/zabbix-release/zabbix-release_6.0-1+debian11_all.deb
sudo dpkg -i zabbix-release_6.0-1+debian11_all.deb


# Обновить пакеты из репозитория Zabbix
sudo apt update


# Установка Zabbix server, zabbix agent
sudo apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-nginx-conf zabbix-agent zabbix-sql-scripts


# Скрипт установки MariaDB. Изменить пароль на более сложный.
sudo cat <<EOF > mysql_secure_installation
y
myzabbix
myzabbix
y
y
y
y
EOF


# Создание базы данных и пользовтеля. Изменить имя базы и прароль для безопасности.
sudo mysql -u root -p"myzabbix" -e "CREATE DATABASE IF NOT EXISTS zabbix CHARACTER SET utf8 COLLATE utf8_bin;"
sudo mysql -u root -p"myzabbix" -e "CREATE USER IF NOT EXISTS 'zabbix'@'localhost' IDENTIFIED BY 'zabbix';"
sudo mysql -u root -p"myzabbix" -e "GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';"
sudo mysql -u root -p"myzabbix" -e "FLUSH PRIVILEGES;"
sudo mysql -u root -p"myzabbix" -e "exit"


# Импорт базы данных
sudo zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -p'zabbix' zabbix


# Конфигурация Zabbix server
sudo sed -i "s/# DBPassword=/DBPassword=zabbix/g" /etc/zabbix/zabbix_server.conf


# Конфигурация PHP-FPM добавим свои регион и часовой пояс
sudo sed -i "s/;date.timezone =/date.timezone = Asia\/Vladivostok/g" /etc/php/7.4/fpm/php.ini


# Конфигурация PHP for Zabbix frontend
sudo sed -i 's/max_execution_time = 30/max_execution_time = 300/g' /etc/php/7.4/fpm/php.ini
sudo sed -i 's/max_input_time = 60/max_input_time = 300/g' /etc/php/7.4/fpm/php.ini
sudo sed -i 's/memory_limit = 128M/memory_limit = 256M/g' /etc/php/7.4/fpm/php.ini
sudo sed -i 's/post_max_size = 8M/post_max_size = 16M/g' /etc/php/7.4/fpm/php.ini
sudo sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 8M/g' /etc/php/7.4/fpm/php.ini


# Конфигурация NGINX
sudo cat <<EOF > /etc/nginx/sites-available/default
server {
    listen 80;
    listen [::]:80;

    root /usr/share/zabbix;

    access_log /var/log/nginx/zabbix.access.log;
    error_log /var/log/nginx/zabbix.error.log;

    location / {
        index index.php;
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_pass unix:/run/php/php7.4-fpm.sock;
        fastcgi_index index.php;
    }
}
EOF


# Перезапуск NGINX и дабавление в автозагрузку сервиса
sudo systemctl enable nginx
sudo systemctl restart nginx


# Перезапуск MariaDB и дабавление в автозагрузку сервиса
sudo sed -i "s/#bind-address/bind-address/g" /etc/mysql/mariadb.conf.d/50-server.cnf
sudo systemctl enable mariadb
sudo systemctl restart mariadb

# Старт Zabbix и Zabbix агента, дабавление в автозагрузку
sudo systemctl start zabbix-server zabbix-agent
sudo systemctl enable zabbix-server zabbix-agent

echo "Zabbix 6.0 installation and configuration complete. Autor eugenyetc, eugenyetc@gmail.com"
