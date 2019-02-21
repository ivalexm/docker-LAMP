#!/usr/bin/env bash
set -eu -o pipefail

# enable/disable non-https (unencrypted over port 80) apache access
if [ "$APACHE_ENABLE_PORT_80" = true ] ; then
  sed -i 's,^#Listen 80,Listen 80,g' /etc/httpd/conf/httpd.conf
else
  sed -i 's,^Listen 80,#Listen 80,g' /etc/httpd/conf/httpd.conf
fi

# the systemd services generally create these folders, make them now manually
mkdir -p /run/httpd

# make sure apache knows the proper server name
sed -i "s/^ServerName .*/ServerName $(hostname --fqdn)/g" /etc/httpd/conf/httpd.conf

[ "$START_MYSQL" = true ] && cd /usr && /usr/bin/mysqld_safe --datadir=/var/lib/mysql&
[ "$START_MYSQL" = true ] && sleep 1 && nohup /usr/bin/mysqld '--basedir=/usr' '--datadir=/var/lib/mysql' '--plugin-dir=/usr/lib64/mysql/plugin' '--user=mysql' '--log-error=/var/lib/mysql/log.err' '--socket=/run/mysqld/mysqld.sock' '--port=3306'&
[ "$DO_SSL_SELF_GENERATION" = true ] && setup-apache-ssl-key
[ "$START_APACHE" = true ] && apachectl start
[ "$DO_SSL_LETS_ENCRYPT_FETCH" = true ] && setup-apache-ssl-key
[ "$USE_EXISTING_LETS_ENCRYPT" = true ] && setup-apache-ssl-key
[ "$ENABLE_CRON" = true ] && crond
