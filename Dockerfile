FROM docker.io/library/node:lts-alpine AS base

LABEL org.opencontainers.image.vendor="https://platynum.ch/" \
      org.opencontainers.image.licenses="AGPL-3.0" \
      org.opencontainers.image.title="platynum certification authority"

# Install tools, create Node-RED app and data dir, add user and set rights
RUN set -ex && \
    apk add --no-cache \
        apache2-proxy \
        apache2-ssl \
        ca-certificates \
        git \
        tzdata \
        iputils \
        jq \
        curl \
        openssl \
        openssh-client && \
    mkdir -p /usr/src/node-red /data/ctlogs /data/scripts && \
    deluser --remove-home node && \
    adduser -h /usr/src/node-red -D -H node-red -u 1000 && \
    curl --remote-time -o /data/public_suffix_list.dat https://publicsuffix.org/list/public_suffix_list.dat && \
    curl --remote-time -o /data/ctlogs/apple_log_list.json https://valid.apple.com/ct/log_list/current_log_list.json && \
    curl --remote-time -o /data/ctlogs/chrome_log_list.json https://www.gstatic.com/ct/log_list/v3/log_list.json && \
    curl --remote-time -o /data/ctlogs/chrome_log_list.sig https://www.gstatic.com/ct/log_list/v3/log_list.sig && \
    curl --remote-time -o /data/ctlogs/chrome_log_list_pubkey.pem https://www.gstatic.com/ct/log_list/v3/log_list_pubkey.pem && \
    chown -R node-red:node-red /data
    # chmod -R g+rwX /data && \
    # chown -R node-red:root /usr/src/node-red && chmod -R g+rwX /usr/src/node-red
    # chown -R node-red:node-red /data && \
    # chown -R node-red:node-red /usr/src/node-red

# Set work directory
WORKDIR /usr/src/node-red

# Env variables
ENV NODE_PATH=/usr/src/node-red/node_modules:/data/node_modules \
    FLOWS=flows.json

COPY --chown=node-red:node-red --chmod=644 flows/settings.js /data/settings.js
COPY --chown=node-red:node-red --chmod=644 flows/flows.json /data/flows.json

COPY --chmod=644 flows/package.json flows/[p]ackage-lock.json flows/[n]pm-shrinkwrap.json /usr/src/node-red/
RUN npm ci --omit=dev --omit=optional && \
    npm cache clean --force && \
    chmod -R 755 node_modules && \
    chown -R root:root node_modules
# Override default red.js with patched version
COPY --chown=root:root --chmod=644 flows/bin/node-red-ca.js /usr/src/node-red/node_modules/node-red/red.js

# Setup healthcheck
COPY --chmod=755 healthcheck.js /usr/bin/
HEALTHCHECK --start-period=120s \
    CMD /usr/bin/healthcheck.js

# Configure apache reverse proxy and CCA
COPY httpd.conf /etc/apache2/httpd.conf
COPY httpd-ssl.conf /etc/apache2/conf.d/ssl.conf
RUN rm -f /etc/ssl/apache2/server.{key,pem} \
 && ln -sf /data/Sub/https/https-RSA.crt.pem /etc/ssl/apache2/server.pem \
 && ln -sf /data/Sub/https/https-EC.crt.pem /etc/ssl/apache2/server-ecc.pem \
 && ln -sf /data/Sub/https/https-RSA.priv.key.pem /etc/ssl/apache2/server.key \
 && ln -sf /data/Sub/https/https-EC.priv.key.pem /etc/ssl/apache2/server-ecc.key \
 && ln -sf /data/Sub/https/ca.crt.pem /etc/ssl/apache2/server-ca.pem

# Expose the listening port of apache/node-red
EXPOSE 80 1880 3180 443

COPY --chmod=755 entrypoint.sh /usr/bin/
ENTRYPOINT ["/usr/bin/entrypoint.sh"]
