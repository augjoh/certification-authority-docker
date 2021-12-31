#!/bin/sh

DATADIR=/data

# Change workdir to /data so that files (ie. certificates) are going to be
# created there
cd "${DATADIR}" || exit 1

apache2() {
    APACHE2_SSL_CONF=/etc/apache2/conf.d/ssl.conf

    while [ ! -f "${DATADIR}/Sub/https/https-EC.crt.pem" ]; do
        sleep 3
    done

    while [ ! -f "${DATADIR}/Sub/https/https-RSA.crt.pem" ]; do
        sleep 3
    done

    while ! find "${DATADIR}/Admin/crls/" -name crl.pem >/dev/null 2>&1; do
        sleep 3
    done

    SSLCACertificatePath=$(awk '/^SSLCACertificatePath/ { print $2 }' "${APACHE2_SSL_CONF}")
    if [ -d "${SSLCACertificatePath}" ]; then
        rm "${SSLCACertificatePath}/"*
    else
        mkdir -p "${SSLCACertificatePath}"
    fi
    for crt in $(find "${DATADIR}/Root/" "${DATADIR}/Admin/" -name ca.crt.pem); do
        hash="$(openssl x509 -noout -in "${crt}" -hash)"
        if [ -f "${crt}.revoked" ]; then
            rm -f "${SSLCACertificatePath}/${hash}.0"
        else
            ln -sf "${crt}" "${SSLCACertificatePath}/${hash}.0"
        fi
    done

    SSLCARevocationPath=$(awk '/^SSLCARevocationPath/ { print $2 }' "${APACHE2_SSL_CONF}")
    if [ -d "${SSLCARevocationPath}" ]; then
        rm "${SSLCARevocationPath}/"*
    else
        mkdir -p "${SSLCARevocationPath}"
    fi
    for crl in $(find -L "${DATADIR}" -name crl.pem); do
        hash="$(openssl crl -noout -in "${crl}" -hash)"
        ln -sf "${crl}" "${SSLCARevocationPath}/${hash}.r0"
    done

    APACHE_DEFINES=""
    if [ "${APACHE_OCSP_STAPLING}" = "true" ]; then
        APACHE_DEFINES="-DSSLUseStapling ${APACHE_DEFINES}"
    fi
    /usr/sbin/httpd ${APACHE_DEFINES} -k start
    sleep 5
    tail -q /var/log/apache2/*.log
}

if [ "${CONTAINER_ENABLE_APACHE}" != "false" ]; then
    /usr/sbin/httpd -v
    # This creates a zombie
    apache2 &
fi

# Disable unused flows
if [ -n "${CONTAINER_ENABLE_FLOWS}" ]; then
    echo "$(date "+%d %b %H:%M:%S") - [info] Enabling flows matching '${CONTAINER_ENABLE_FLOWS}', only."
    cp -a "${DATADIR}/${FLOWS}" "${DATADIR}/${FLOWS}.bck"
    jq "[ .[] |
	    (select(.type == \"tab\") | if ( .label | test(\"${CONTAINER_ENABLE_FLOWS}\")) then
                                            . + {\"disabled\": false}
				        else
                                            . + {\"disabled\": true}
				        end),
             select(.type != \"tab\") ]" "${DATADIR}/${FLOWS}.bck" > "${DATADIR}/${FLOWS}"
fi

exec su -c "node ${NODE_OPTIONS} /usr/src/node-red/node_modules/node-red/red.js --verbose --userDir ${DATADIR} ${FLOWS}" node-red
