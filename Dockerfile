FROM nodered/node-red:latest

COPY settings.js /data/settings.js
COPY flows/flows.json /data/flows.json
COPY flows/package.json .
RUN npm install --only=production

USER root
RUN apk --no-cache add apache2-ssl \
                       apache2-proxy \
                       ca-certificates \
                       openssl
COPY entrypoint.sh /usr/bin/
COPY healthcheck.js /
RUN chmod 755 /usr/bin/entrypoint.sh \
              /healthcheck.js

# Overwrite healthcheck from node-red, target apache2 instead of nodejs
HEALTHCHECK --start-period=120s \
    CMD sh -c 'NODE_EXTRA_CA_CERTS=/data/Root/ca.crt.pem node /healthcheck.js'

# Configure apache reverse proxy and CCA
COPY httpd.conf /etc/apache2/httpd.conf
COPY httpd-ssl.conf /etc/apache2/conf.d/ssl.conf
RUN rm -f /etc/ssl/apache2/server.{key,pem} \
 && ln -sf /data/Sub/https.crt.pem /etc/ssl/apache2/server.pem \
 && ln -sf /data/Sub/https.priv.key.pem /etc/ssl/apache2/server.key

EXPOSE 80 3180 443

ENTRYPOINT ["/usr/bin/entrypoint.sh"]
