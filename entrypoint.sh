#!/bin/sh

DATADIR=/data

# Change workdir to /data so that files (ie. certificates) are going to be
# created there
cd "${DATADIR}" || exit 1

apache2() {
    APACHE2_SSL_CONF=/etc/apache2/conf.d/ssl.conf

    while [ ! -f "${DATADIR}/Sub/https.crt.pem" ]; do
        sleep 3
    done

    SSLCertificateChainFile=$(awk '/^SSLCertificateChainFile/ { print $2 }' "${APACHE2_SSL_CONF}")
    ln -sf "${DATADIR}/$(openssl x509 -in "${DATADIR}/Sub/https.crt.pem" -noout -text | awk '/CA Issuers/ { print $4 }' | sed 's#.*\(Sub/[a-f0-9]\{64\}\)/ca.crt.cer#\1/ca.crt.pem#')" "${SSLCertificateChainFile}"

    while ! find "${DATADIR}/Admin" -name ca.crt.pem >/dev/null 2>&1; do
        sleep 3
    done

    SSLCACertificatePath=$(awk '/^SSLCACertificatePath/ { print $2 }' "${APACHE2_SSL_CONF}")
    if [ ! -d "${SSLCACertificatePath}" ]; then
        mkdir -p "${SSLCACertificatePath}"
    else
        rm "${SSLCACertificatePath}/"*
    fi
    for crt in $(find "${DATADIR}/Root" "${DATADIR}/Admin" -name ca.crt.pem); do
        if [ ! -f "${crt}.revoked" ]; then
            hash="$(openssl x509 -noout -in "${crt}" -hash)"
            ln -s "${crt}" "${SSLCACertificatePath}/${hash}.0"
        fi
    done

    SSLCARevocationPath=$(awk '/^SSLCARevocationPath/ { print $2 }' "${APACHE2_SSL_CONF}")
    if [ ! -d "${SSLCARevocationPath}" ]; then
        mkdir -p "${SSLCARevocationPath}"
    else
        rm "${SSLCARevocationPath}/"*
    fi
    for crl in $(find "${DATADIR}" -name crl.pem); do
        hash="$(openssl crl -noout -in "${crl}" -hash)"
        ln -s "${crl}" "${SSLCARevocationPath}/${hash}.r0"
    done

    /usr/sbin/httpd -k start
    sleep 5
    tail /var/log/apache2/*.log
}
/usr/sbin/httpd -v

# This creates a zombie
apache2 &

exec su -c "node $NODE_OPTIONS /usr/src/node-red/node_modules/node-red/red.js --userDir /data $FLOWS" node-red
