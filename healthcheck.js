#!/usr/bin/env node

function check_response(res) {
    let data = '';
    res.on('data', (chunk) => {
        data += chunk;
    });
    res.on('end', () => {
        let ret = 0;
        console.log(`STATUS: ${res.statusCode}`);
        if ((res.statusCode >= 200) && (res.statusCode < 400)) {
            if (process.argv[2]) {
                let health = JSON.parse(data);
                for (let service of process.argv[2].split(',')) {
                    if (health[service] !== 'ok') {
                        console.log('ERROR', `service ${service} is ${health[service]}`);
                        ret = 1;
                    }
                }
            }
        }
        else {
            ret = 1;
        }
        process.exit(ret);
    });
}

function check() {
    const user = process.env['HEALTH_USERNAME'];
    const pass = process.env['HEALTH_PASSWORD'];

    let request;
    if (process.env['CONTAINER_ENABLE_APACHE'] !== 'false') {

        const tls = require('node:tls');
        const https = require('node:https');

        //process.env['NODE_EXTRA_CA_CERTS'] = '/data/Root/[a-f0-9]\{64\}/certificates/ca.crt.pem';
        process.env['NODE_TLS_REJECT_UNAUTHORIZED'] = 0;

        const hostname = process.env['HOSTNAME'];
        let httpsOptions = {
            host: 'localhost',
            port: 443,
            path: '/health',
            timeout: 4000,
            checkServerIdentity: function(host, cert) {
                return tls.checkServerIdentity(hostname, cert);
            }
        };
        if (user && pass)
            httpsOptions.auth = user + ':' + pass;
        request = https.request(httpsOptions, check_response);
    }
    else {
        const http = require('node:http');
        let httpOptions = {
            host: process.env.NODE_RED_UI_HOST || "127.0.0.1",
            port: process.env.NODE_RED_UI_PORT || 1880,
            path: '/health',
            timeout: 4000
        };
        if (user && pass)
            httpOptions.auth = user + ':' + pass;
        request = http.request(httpOptions, check_response);
    }

    request.on('error', function(err) {
        console.log('ERROR', err);
        process.exit(1);
    });

    request.end();
}

if (require.main == module)
    check();
else
    exports.check = check;
