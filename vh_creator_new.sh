#!/bin/bash
#   PARAMETERS
#
# $usr          - Користувач
# $dir          - Рут директорія
# $servn        - ім'я веб серверу без www.
# $cname        - префікс до імені (www або develop або stage наприклад)
#
# Приклад
# Рут директорія            = /var/www/
# ім'я веб серверу без www  = domain.com
# префікс до імені          = devel
#
#
# Перевірте чи ви виконуєте скрипт від імені суперкористувача (root user)
# Якщо ви плануєте перезавантажувати веб-сервер чи виконувати команди які вимагають права адміністратора
# тоді розкоментайте наступну перевірку
# if [ "$(whoami)" != 'root' ]; then
# echo "You should execute this script as root user..."
# exit 1;
# fi

echo "Данний сервер буде використовуватися для Ubuntu чи для CentOS чи ви хочете його використати для докеру?"
read -p "ubuntu чи centos чи docker (в нижньому регістрі) : " osname

echo "Введіть ім'я для серверу"
read -p "напр. mydomain.tld (без www) : " servn
echo "Введіть префікс CNAME"
read -p "напр. www чи dev для dev.website.com : " cname
echo "Введіть шлях до директорії яку ви хочете використовувати (для *.conf файлу)"
read -p "напр. /var/www/, не забудьте / : " dir

if [ "$osname" == "docker" ]; then
  echo "Введіть шлях до директорії яку ви хочете використовувати (де *.conf файл буде створено для docker)"
  read -p "напр. {повний_шлях_до_проекту}/etc/apache/, не забудьте / : " docker_dir
fi

echo "Введіть ім'я головної директорії проекту"
read -p "напр. htdocs : " docroot
echo "Введіть ім'я користувача якого ви хочете використовувати для доступу"
read -p "напр. apache/www-data : " usr
echo "Введіть IP для веб-серверу"
read -p "напр. *  або 127.0.0.1 : " listen
echo "Введіть порт для веб-серверу"
read -p "напр. 80 : " port

echo "Чи хочете ви наконфігурувати шлях до логів для веб-серверу [y/n]? "
read q
if [[ "${q}" == "yes" ]] || [[ "${q}" == "y" ]]; then
    echo "Введіть шлях до якого будуть зберігатися лог файли доступу"
    read -p "напр. /var/log/apache : " access_log_path
    echo "Введіть шлях до якого будуть зберігатися лог файли помилок"
    read -p "напр. /var/log/apache : " error_log_path
    echo "Введіть шлях до якого будуть зберігатися кастомні лог файли "
    read -p "напр. /var/log/apache : " custom_log_path
    access_log_name="${cname}_${servn}_access.log"
    error_log_name="${cname}_${servn}_error.log"
    custom_log_name="${cname}_${servn}_custom.log"
fi


SERVICE_=""
VHOST_PATH="$docker_dir"
CFG_TEST=""
DOCUMENT_ROOT="$docroot"
DIRECTORY_="$dir"
if [ "$osname" == "centos" ]; then
  SERVICE_="httpd"
  VHOST_PATH="/etc/httpd/conf.d"
  CFG_TEST="service httpd configtest"
  DIRECTORY_="$dir$cname_$servn/$docroot"
  DOCUMENT_ROOT="$dir$cname_$servn/$docroot"
elif [ "$osname" == "ubuntu" ]; then
  SERVICE_="apache2"
  VHOST_PATH="/etc/apache2/sites-available"
  CFG_TEST="apachectl -t"
  DIRECTORY_="$dir$cname_$servn/$docroot"
  DOCUMENT_ROOT="$dir$cname_$servn/$docroot"
elif [ "$osname" != "ubuntu" ] && [ "$osname" != "centos" ] && [ "$osname" != "docker" ]; then
  echo "Вибачай але я підтримую лише ubuntu, centos або docker"
  echo " "
  echo "Ви впевнені що Ви ввели 'centos' чи 'ubuntu' чи 'docker' у нижньому регістрі???"
  exit 1;
fi



if [[ "$osname" != "docker" ]]; then
  if ! mkdir -p $dir$cname_$servn/$docroot; then
    echo "Веб директорія вже існує !"
  else
    echo "Веб директорія успішно створена !"
  fi
  echo "<h1>$cname $servn</h1>" > $dir$cname_$servn/$docroot/index.html
  chown -R $usr:$usr $dir$cname_$servn/$docroot
  chmod -R '775' $dir$cname_$servn/$docroot
  mkdir /var/log/$cname_$servn
elif [[ "$osname" == "docker" ]]; then
  if ! mkdir -p docker_dir; then
    echo "Веб директорія вже існує !"
  else
    echo "Веб директорія успішно створена !"
  fi
fi


alias=$cname.$servn
if [[ "${cname}" == "" ]]; then
alias=$servn
fi

access_logs=""
custom_logs=""
error_logs=""
logs=""
if [ "$access_log_name" != "" ]; then
    access_logs="AccessLog $access_log_path/$access_log_name"
fi
if [ "$custom_log_name" != "" ]; then
    custom_logs="CustomLog $custom_log_path/$custom_log_name"
fi
if [ "$error_log_name" != "" ]; then
    error_logs="ErrorLog $error_log_path/$error_log_name"
fi

logs="$access_logs\n\t$custom_logs\n\t$error_logs"

echo -e "#### $cname $servn
<VirtualHost $listen:$port>

    ServerName $servn
    ServerAlias $alias
    DocumentRoot $DOCUMENT_ROOT

    $logs

    <Directory $DIRECTORY_>
        Options Indexes FollowSymLinks MultiViews
        AllowOverride All
        Order allow,deny
        Allow from all
        Require all granted
    </Directory>

</VirtualHost>" > $VHOST_PATH/$cname_$servn.conf
if ! echo -e $VHOST_PATH/$cname_$servn.conf; then
echo "Віртуальни хост НЕ БУВ створнеий !"
else
echo "Вірткальний хост СТВОРЕНО !"
fi

# echo "Ви хочете створити ssl віртуальний хост [y/n]? "
# read q
# if [[ "${q}" == "yes" ]] || [[ "${q}" == "y" ]]; then
# openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $VHOST_PATH/$cname_$servn.key -out $VHOST_PATH/$cname_$servn.crt
# if ! echo -e $VHOST_PATH/$cname_$servn.key; then
# echo "Ключ сертифікату НЕ БУВ створений !"
# else
# echo "Ключ сертифікату СТВОРЕНО !"
# fi
# if ! echo -e $VHOST_PATH/$cname_$servn.crt; then
# echo "Сертифікат НЕ БУВ створений !"
# else
# echo "Сертифікат СТВОРЕНО !"
# if [ "$osname" == "ubuntu" ]; then
#   echo "Підключення віртуального хосту ..."
#   sudo a2ensite $cname_$servn.conf
# fi
# fi

# echo "#### ssl $cname $servn
# <VirtualHost $listen:443>
# SSLEngine on
# SSLCertificateFile $VHOST_PATH/$cname_$servn.crt
# SSLCertificateKeyFile $VHOST_PATH/$cname_$servn.key
# ServerName $servn
# ServerAlias $alias
# DocumentRoot $dir$cname_$servn/$docroot
# <Directory $dir$cname_$servn/$docroot>
# Options Indexes FollowSymLinks MultiViews
# AllowOverride All
# Order allow,deny
# Allow from all
# Satisfy Any
# </Directory>
# </VirtualHost>" > $VHOST_PATH/ssl.$cname_$servn.conf
# if ! echo -e $VHOST_PATH/ssl.$cname_$servn.conf; then
# echo "SSL Віртуальний хост НЕ БУЛО створено!"
# else
# echo "SSL Віртуальний хост СТВОРЕНО !"
# if [ "$osname" == "ubuntu" ]; then
#   echo "Підключення SSL Віртуального хосту..."
#   sudo a2ensite ssl.$cname_$servn.conf
# fi
# fi
# fi

# echo "127.0.0.1 $servn" >> /etc/hosts
# if [ "$alias" != "$servn" ]; then
# echo "127.0.0.1 $alias" >> /etc/hosts
# fi
# echo "Тестування конфігурації"
# sudo $CFG_TEST
# echo "Хочете перезапустити сервер [y/n]? "
# read q
# if [[ "${q}" == "yes" ]] || [[ "${q}" == "y" ]]; then
# service $SERVICE_ restart
# fi
echo "======================================"
echo "Робота виконана успішно!"
echo ""
