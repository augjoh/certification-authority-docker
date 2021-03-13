FROM nodered/node-red:latest-minimal

LABEL org.opencontainers.image.url="https://registry.gitlab.com/platynum/certification-authority/container" \
      org.opencontainers.image.documentation="https://platynum.gitlab.io/certification-authority/documentation/" \
      org.opencontainers.image.source="https://gitlab.com/platynum/certification-authority/container" \
      org.opencontainers.image.version="0.8.0" \
      org.opencontainers.image.vendor="https://platynum.ch/" \
      org.opencontainers.image.licenses="AGPL-3.0" \
      org.opencontainers.image.title="platynum certification authority" \
      org.opencontainers.image.description="Certification authority based on Node-RED"

COPY settings.js /data/settings.js
COPY flows/flows.json /data/flows.json

COPY flows/package.json flows/package-lock.json /usr/src/node-red/
RUN npm ci --production

USER root
RUN apk --no-cache add apache2-ssl \
                       apache2-proxy \
                       ca-certificates \
                       jq \
                       openssl
COPY entrypoint.sh /usr/bin/
COPY healthcheck.js /
RUN chmod 755 /usr/bin/entrypoint.sh \
              /healthcheck.js

# Overwrite healthcheck from node-red, target apache2 instead of nodejs
HEALTHCHECK --start-period=120s \
    CMD 'node /healthcheck.js'

# Configure apache reverse proxy and CCA
COPY httpd.conf /etc/apache2/httpd.conf
COPY httpd-ssl.conf /etc/apache2/conf.d/ssl.conf
RUN rm -f /etc/ssl/apache2/server.{key,pem} \
 && ln -sf /data/Sub/https/https.crt.pem /etc/ssl/apache2/server.pem \
 && ln -sf /data/Sub/https/https.priv.key.pem /etc/ssl/apache2/server.key \
 && ln -sf /data/Sub/https/ca.crt.pem /etc/ssl/apache2/server-ca.pem

EXPOSE 80 3180 443

ENTRYPOINT ["/usr/bin/entrypoint.sh"]
