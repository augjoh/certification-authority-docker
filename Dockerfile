FROM nodered/node-red:latest

COPY flows/settings.js /data/settings.js
COPY flows/flows_nodejs.json /data/flows.json
COPY flows/package.json .
RUN npm install --only=production \
 && sed -i 's/alg:"SHA1withRSA"/alg:this.asn1SignatureAlg.nameAlg/' /usr/src/node-red/node_modules/jsrsasign/lib/jsrsasign.js

# We'll likely need to add SSL root certificates
USER root
RUN apk --no-cache add apache2-ssl \
                       apache2-utils \
                       apache2-proxy \
                       ca-certificates \
                       openssl
COPY entrypoint.sh /usr/bin/
COPY httpd.conf /etc/apache2/httpd.conf
RUN chmod 755 /usr/bin/entrypoint.sh \
 && rm -f /etc/ssl/apache2/server.{key,pem} \
 && ln -sf /data/Sub/https.crt.pem /etc/ssl/apache2/server.pem \
 && ln -sf /data/Sub/https.priv.key.pem /etc/ssl/apache2/server.key \
 && ln -sf /data/Sub/ca.crt.pem /etc/ssl/apache2/server-ca.pem \
 && sed -i 's|^#SSLCertificateChainFile.*$|SSLCertificateChainFile /etc/ssl/apache2/server-ca.pem|' /etc/apache2/conf.d/ssl.conf

EXPOSE 80 318 443

ENTRYPOINT ["/usr/bin/entrypoint.sh"]