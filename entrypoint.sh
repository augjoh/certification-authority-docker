#!/bin/sh

DATADIR=/data

# Change workdir to /data so that files (ie. certificates) are going to be
# created there
cd "${DATADIR}" || exit 1

apache2() {
    APACHE2_SSL_CONF=/etc/apache2/conf.d/ssl.conf
    APACHE2_HTTPD_PID=/var/run/apache2/httpd.pid

    rm -f "${APACHE2_HTTPD_PID}"

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
    # Does node-red listen on socket?
    if printf "%s" "${NODE_RED_UI_HOST}" | grep -q -E "^/"; then
        while [ ! -S "${NODE_RED_UI_HOST}" ]; do
           sleep 3;
        done
        chmod 775 "${NODE_RED_UI_HOST}";
        APACHE_DEFINES="-DForwardToSocket ${APACHE_DEFINES}";
    fi
    /usr/sbin/httpd ${APACHE_DEFINES} -k start
    sleep 5
    tail -q /var/log/apache2/*.log
}

# Create 256*256 blacklist directories if requested (nodejs is too slow)
if [ -n "${CA_BLACKLIST_DEPTH}" ] && [ "${CA_BLACKLIST_DEPTH}" -eq "2" ]; then
    if [ ! -d "${DATADIR}/blacklist/ff/ff" ]; then
        echo "$(date "+%d %b %H:%M:%S") - [info] Creating blacklist directories ... (depth=${CA_BLACKLIST_DEPTH})"
        seq 0 255 | while read -r x; do
            seq 0 255 | while read -r y; do
                printf "${DATADIR}/blacklist/%02x/%02x\n" "${x}" "${y}";
            done
        done | su -c "xargs -n 256 -- mkdir -p" node-red
    fi
fi

if printf "%s" "${NODE_RED_UI_HOST}" | grep -q -E "^/"; then
    SOCKET_DIRECTORY=$(dirname "${NODE_RED_UI_HOST}")
    if [ ! -d "${SOCKET_DIRECTORY}" ]; then
        mkdir -p "${SOCKET_DIRECTORY}"
        chown node-red:www-data "${SOCKET_DIRECTORY}"
        chmod 2755 "${SOCKET_DIRECTORY}"
    fi
    # Maybe a container restart, delete leftover
    rm -f "${NODE_RED_UI_HOST}"
fi
if [ "${CONTAINER_ENABLE_APACHE}" != "false" ]; then
    /usr/sbin/httpd -v | sed "s/^/$(date "+%d %b %H:%M:%S") - [info] /"
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

exec su -c "node ${NODE_OPTIONS} /usr/src/node-red/node_modules/node-red/red.js --userDir ${DATADIR} ${FLOWS}" node-red
