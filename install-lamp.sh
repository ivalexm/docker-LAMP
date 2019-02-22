#!/usr/bin/env bash
set -eu -o pipefail

echo 'v201902221124'
ls -l /usr/lib

# install apache
pacman -S --noprogressbar --noconfirm --needed apache
sed -i "s,#ServerName www.example.com:80,ServerName $(hostname --fqdn):80,g" /etc/httpd/conf/httpd.conf

# enable mod rewrite
sed -i '/^#LoadModule rewrite_module modules\/mod_rewrite.so/s/^#//g' /etc/httpd/conf/httpd.conf

# solve HTTP TRACE vulnerability: http://www.kb.cert.org/vuls/id/867593
sed -i '$a TraceEnable Off' /etc/httpd/conf/httpd.conf

# install php
pacman -S --noprogressbar --noconfirm --needed php php-apache

# setup php
cat > /srv/http/info.php <<EOF
<?php
// Show all information, defaults to INFO_ALL
phpinfo();

// Show just the module information.
// phpinfo(8) yields identical results.
phpinfo(INFO_MODULES);
?>
EOF
sed -i 's,#LoadModule deflate_module modules/mod_deflate.so,LoadModule deflate_module modules/mod_deflate.so,g' /etc/httpd/conf/httpd.conf
sed -i 's,#LoadModule expires_module modules/mod_expires.so,LoadModule expires_module modules/mod_expires.so,g' /etc/httpd/conf/httpd.conf
sed -i 's,LoadModule mpm_event_module modules/mod_mpm_event.so,#LoadModule mpm_event_module modules/mod_mpm_event.so,g' /etc/httpd/conf/httpd.conf
sed -i 's,#LoadModule mpm_prefork_module modules/mod_mpm_prefork.so,LoadModule mpm_prefork_module modules/mod_mpm_prefork.so,g' /etc/httpd/conf/httpd.conf
sed -i 's,LoadModule dir_module modules/mod_dir.so,LoadModule dir_module modules/mod_dir.so\nLoadModule php7_module modules/libphp7.so,g' /etc/httpd/conf/httpd.conf
sed -i '$a Include conf/extra/php7_module.conf' /etc/httpd/conf/httpd.conf
sed -i 's,;extension=iconv,extension=iconv,g' /etc/php/php.ini
sed -i 's,;extension=xmlrpc,extension=xmlrpc,g' /etc/php/php.ini
sed -i 's,;extension=zip,extension=zip,g' /etc/php/php.ini
sed -i 's,;extension=bz2,extension=bz2,g' /etc/php/php.ini
sed -i 's,;extension=curl,extension=curl,g' /etc/php/php.ini
sed -i 's,;extension=ftp,extension=ftp,g' /etc/php/php.ini
sed -i 's,;extension=gettext,extension=gettext,g' /etc/php/php.ini

#link dependency for libphp7.so
pacman -S --noprogressbar --noconfirm --needed  readline
echo '================== READLINE INSTALLED ? ======================='
ls -l /usr/lib

# for php-intl
pacman -S --noprogressbar --noconfirm --needed php-intl
sed -i 's,;extension=intl,extension=intl,g' /etc/php/php.ini

# for PHP caching
sed -i 's,;zend_extension=opcache,zend_extension=opcache,g' /etc/php/php.ini
# TODO: think about setting default values https://secure.php.net/manual/en/opcache.installation.php#opcache.installation.recommended
pacman -S --noprogressbar --noconfirm --needed php-apcu
sed -i 's,;extension=apcu.so,extension=apcu.so,g' /etc/php/conf.d/apcu.ini
sed -i '$a apc.enable_cli=1' /etc/php/conf.d/apcu.ini
sed -i '$a apc.enabled=1' /etc/php/conf.d/apcu.ini
sed -i '$a apc.shm_size=32M' /etc/php/conf.d/apcu.ini
sed -i '$a apc.ttl=7200' /etc/php/conf.d/apcu.ini

# enable APC backwards compatibility
#pacman -S --noconfirm --noprogress --needed php-apcu-bc
#sed -i 's,;extension=apc.so,extension=apc.so,g' /etc/php/conf.d/apcu.ini

# for exif support
pacman -S --noprogressbar --noconfirm --needed exiv2
sed -i 's,;extension=exif,extension=exif,g' /etc/php/php.ini

# for mariadb (mysql) database
groupadd -g 89 mysql &>/dev/null
useradd -u 89 -g 89 -d /var/lib/mysql -s /bin/false mysql &>/dev/null
# here is a hack to prevent an error during install because of missing systemd
ln -s /usr/bin/true /usr/bin/systemd-tmpfiles
pacman -S --noprogressbar --noconfirm --needed mariadb
rm /usr/bin/systemd-tmpfiles
pacman -S --noprogressbar --noconfirm --needed perl-dbd-mysql
sed -i 's,;extension=pdo_mysql,extension=pdo_mysql,g' /etc/php/php.ini
sed -i 's,;extension=mysql,extension=mysql,g' /etc/php/php.ini
mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
sed -i 's,;extension=mysqli,extension=mysqli,g' /etc/php/php.ini
#sed -i 's,mysql.trace_mode = Off,mysql.trace_mode = On,g' /etc/php/php.ini
#sed -i 's,mysql.default_host =,mysql.default_host = localhost,g' /etc/php/php.ini
#sed -i 's,mysql.default_user =,mysql.default_user = root,g' /etc/php/php.ini

# setup ssl
sed -i 's,;extension=openssl,extension=openssl,g' /etc/php/php.ini
sed -i 's,#LoadModule ssl_module modules/mod_ssl.so,LoadModule ssl_module modules/mod_ssl.so,g' /etc/httpd/conf/httpd.conf
sed -i 's,#LoadModule socache_shmcb_module modules/mod_socache_shmcb.so,LoadModule socache_shmcb_module modules/mod_socache_shmcb.so,g' /etc/httpd/conf/httpd.conf
sed -i 's,#Include conf/extra/httpd-ssl.conf,Include conf/extra/httpd-ssl.conf,g' /etc/httpd/conf/httpd.conf
# use Mozilla's recommended ciphersuite (see https://wiki.mozilla.org/Security/Server_Side_TLS):
sed -i 's/^SSLCipherSuite .*/SSLCipherSuite ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!3DES:!MD5:!PSK/g' /etc/httpd/conf/extra/httpd-ssl.conf
# disable super old and vulnerable SSL protocols: SSLv2 and SSLv3 (this breaks IE6 & windows XP)
sed -i '$a SSLProtocol All -SSLv2 -SSLv3' /etc/httpd/conf/extra/httpd-ssl.conf
# let ServerName be inherited
sed -i '/ServerName www.example.com:443/d' /etc/httpd/conf/extra/httpd-ssl.conf

# this is for lets encrypt ssl cert fetching
pacman -S --noprogressbar --noconfirm --needed certbot certbot-apache

# instal cron
pacman -S --noprogressbar --noconfirm --needed cronie

# reduce docker layer size
cleanup-image
