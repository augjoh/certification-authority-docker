#!/bin/sh

apache2() {
    while [ ! -f Sub/https.crt.pem ]; do
      sleep 3
    done
    /usr/sbin/httpd -k start
    sleep 5
    tail /var/log/apache2/*.log
}
/usr/sbin/httpd -v
apache2 &

exec su -c "npm start -- --userDir /data" node-red