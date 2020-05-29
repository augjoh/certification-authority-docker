#!/bin/sh

# Change workdir to /data so that files (ie. certificates) are going to be
# created there
cd /data

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

exec su -c "node $NODE_OPTIONS /usr/src/node-red/node_modules/node-red/red.js --userDir /data $FLOWS" node-red