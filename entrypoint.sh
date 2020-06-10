#!/bin/sh

# Change workdir to /data so that files (ie. certificates) are going to be
# created there
cd /data

apache2() {
    while [ ! -f Sub/https.crt.pem ] && [ ! -f Admin/ca.crt.pem ]; do
        sleep 3
    done
    openssl rehash $(awk '/^SSLCACertificatePath/ { print $2 }')
    openssl rehash $(awk '/^SSLCARevocationPath/ { print $2 }')
    /usr/sbin/httpd -k start
    sleep 5
    tail /var/log/apache2/*.log
}
/usr/sbin/httpd -v

# This creates a zombie
apache2 &

exec su -c "node $NODE_OPTIONS /usr/src/node-red/node_modules/node-red/red.js --userDir /data $FLOWS" node-red
