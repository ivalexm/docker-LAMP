FROM greyltc/archlinux

# update the container's mirrorlist
RUN get-new-mirrors

ADD install-lamp.sh /usr/sbin/install-lamp
RUN install-lamp

# generate our ssl key
ADD setupApacheSSLKey.sh /usr/sbin/setup-apache-ssl-key
ENV SUBJECT /C=US/ST=CA/L=CITY/O=ORGANIZATION/OU=UNIT/CN=localhost
ENV DO_SSL_LETS_ENCRYPT_FETCH false
ENV USE_EXISTING_LETS_ENCRYPT false
ENV EMAIL fail
ENV DO_SSL_SELF_GENERATION true
RUN setup-apache-ssl-key
ENV DO_SSL_SELF_GENERATION false
ENV CURLOPT_CAINFO /etc/ssl/certs/ca-certificates.crt

# here are the ports that various things in this container are listening on
# for http (apache, only if APACHE_DISABLE_PORT_80 = false)
#EXPOSE 80
# for https (apache)
EXPOSE 443

# start servers
ADD startServers.sh /usr/sbin/start-servers
ENV START_APACHE true
ENV APACHE_ENABLE_PORT_80 false
ENV START_MYSQL false
ENV START_POSTGRESQL false
ENV ENABLE_DAV false
ENV ENABLE_CRON true
CMD start-servers; sleep infinity
