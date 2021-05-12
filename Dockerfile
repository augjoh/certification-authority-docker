FROM node:lts-alpine AS base

LABEL org.opencontainers.image.url="https://registry.gitlab.com/platynum/certification-authority/container" \
org.opencontainers.image.documentation="https://platynum.gitlab.io/certification-authority/documentation/" \
org.opencontainers.image.source="https://gitlab.com/platynum/certification-authority/container" \
      org.opencontainers.image.version="0.8.0" \
      org.opencontainers.image.vendor="https://platynum.ch/" \
      org.opencontainers.image.licenses="AGPL-3.0" \
      org.opencontainers.image.title="platynum certification authority" \
      org.opencontainers.image.description="Certification authority based on Node-RED"

# Install tools, create Node-RED app and data dir, add user and set rights
RUN set -ex && \
    apk add --no-cache \
        apache2-proxy \
        apache2-ssl \
        ca-certificates \
        tzdata \
        iputils \
        jq \
        curl \
        openssl \
        openssh-client && \
    mkdir -p /usr/src/node-red /data && \
    deluser --remove-home node && \
    adduser -h /usr/src/node-red -D -H node-red -u 1000 && \
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

COPY --chown=node-red:node-red settings.js /data/settings.js
COPY --chown=node-red:node-red flows/flows.json /data/flows.json

COPY flows/package.json flows/package-lock.json /usr/src/node-red/
RUN npm ci --production

# Setup healthcheck
COPY healthcheck.js /usr/bin/
RUN chmod 755 /usr/bin/healthcheck.js
HEALTHCHECK --start-period=120s \
    CMD /usr/bin/healthcheck.js

# Configure apache reverse proxy and CCA
COPY httpd.conf /etc/apache2/httpd.conf
COPY httpd-ssl.conf /etc/apache2/conf.d/ssl.conf
RUN rm -f /etc/ssl/apache2/server.{key,pem} \
 && ln -sf /data/Sub/https/https.crt.pem /etc/ssl/apache2/server.pem \
 && ln -sf /data/Sub/https/https.priv.key.pem /etc/ssl/apache2/server.key \
 && ln -sf /data/Sub/https/ca.crt.pem /etc/ssl/apache2/server-ca.pem

# Expose the listening port of apache/node-red
EXPOSE 80 1880 3180 443

COPY entrypoint.sh /usr/bin/
RUN chmod 755 /usr/bin/entrypoint.sh
ENTRYPOINT ["/usr/bin/entrypoint.sh"]
