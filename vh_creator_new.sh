#!/bin/bash
#   PARAMETERS
#
# $usr          - User
# $dir          - directory of web files
# $servn        - webserver address without www.
# $cname        - cname of webserver
#
# EXAMPLE
# Web directory = /var/www/
# ServerName    = domain.com
# cname            = devel
#
#
# Check if you execute the script as root user
#
# This will check if directory already exist then create it with path : /directory/you/choose/domain.com
# Set the ownership, permissions and create a test index.php file
# Create a vhost file domain in your /etc/httpd/conf.d/ directory.
# And add the new vhost to the hosts.
#
#
# if [ "$(whoami)" != 'root' ]; then
# echo "Dude, you should execute this script as root user..."
# exit 1;
# fi
echo "First of all, is this server an Ubuntu or is it a CentOS or you want to use it for docker?"
read -p "ubuntu or centos or docker (lowercase, please) : " osname

echo "Enter the server name you want"
read -p "e.g. mydomain.tld (without www) : " servn
echo "Enter a CNAME"
read -p "e.g. www or dev for dev.website.com : " cname
echo "Enter the path of directory you wanna use (for *.conf file)"
read -p "e.g. /var/www/, dont forget the / : " dir

if [ "$osname" == "docker" ]; then
  echo "Enter the path of directory you wanna use (where *.conf file will be created for docker)"
  read -p "e.g. {full_path_to_project}/etc/apache/, dont forget the / : " docker_dir
fi

echo "Enter the name of the document root folder"
read -p "e.g. htdocs : " docroot
echo "Enter the user you wanna use"
read -p "e.g. apache/www-data : " usr
echo "Enter the listened IP for the web server"
read -p "e.g. * : " listen
echo "Enter the port on which the web server should respond"
read -p "e.g. 80 : " port

echo "Would you like to configure log paths and names for web server [y/n]? "
read q
if [[ "${q}" == "yes" ]] || [[ "${q}" == "y" ]]; then
    echo "Enter the path to access log files"
    read -p "e.g. /var/log/apache : " access_log_path
    echo "Enter the path to error log files"
    read -p "e.g. /var/log/apache : " error_log_path
    echo "Enter the path to custom log files"
    read -p "e.g. /var/log/apache : " custom_log_path
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
  echo "Sorry mate but I only support ubuntu or centos or docker"
  echo " "
  echo "By the way, are you sure you have entered 'centos' or 'ubuntu' all lowercase???"
  exit 1;
fi



if [[ "$osname" != "docker" ]]; then
  if ! mkdir -p $dir$cname_$servn/$docroot; then
    echo "Web directory already Exist !"
  else
    echo "Web directory created with success !"
  fi
  echo "<h1>$cname $servn</h1>" > $dir$cname_$servn/$docroot/index.html
  chown -R $usr:$usr $dir$cname_$servn/$docroot
  chmod -R '775' $dir$cname_$servn/$docroot
  mkdir /var/log/$cname_$servn
elif [[ "$osname" == "docker" ]]; then
  if ! mkdir -p docker_dir; then
    echo "Web directory already Exist !"
  else
    echo "Web directory created with success !"
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
echo "Virtual host wasn't created !"
else
echo "Virtual host created !"
fi
# echo "Would you like me to create ssl virtual host [y/n]? "
# read q
# if [[ "${q}" == "yes" ]] || [[ "${q}" == "y" ]]; then
# openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $VHOST_PATH/$cname_$servn.key -out $VHOST_PATH/$cname_$servn.crt
# if ! echo -e $VHOST_PATH/$cname_$servn.key; then
# echo "Certificate key wasn't created !"
# else
# echo "Certificate key created !"
# fi
# if ! echo -e $VHOST_PATH/$cname_$servn.crt; then
# echo "Certificate wasn't created !"
# else
# echo "Certificate created !"
# if [ "$osname" == "ubuntu" ]; then
#   echo "Enabling Virtual host..."
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
# echo "SSL Virtual host wasn't created !"
# else
# echo "SSL Virtual host created !"
# if [ "$osname" == "ubuntu" ]; then
#   echo "Enabling SSL Virtual host..."
#   sudo a2ensite ssl.$cname_$servn.conf
# fi
# fi
# fi

# echo "127.0.0.1 $servn" >> /etc/hosts
# if [ "$alias" != "$servn" ]; then
# echo "127.0.0.1 $alias" >> /etc/hosts
# fi
# echo "Testing configuration"
# sudo $CFG_TEST
# echo "Would you like me to restart the server [y/n]? "
# read q
# if [[ "${q}" == "yes" ]] || [[ "${q}" == "y" ]]; then
# service $SERVICE_ restart
# fi
echo "======================================"
echo "All works done!"
echo ""
