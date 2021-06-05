#!/usr/bin/env node

function check_response(res) {
    console.log(`STATUS: ${res.statusCode}`);
    if ((res.statusCode >= 200) && (res.statusCode < 400)) {
        process.exit(0);
    }
    else {
        process.exit(1);
    }
}

var user = process.env['HEALTH_USERNAME'];
var pass = process.env['HEALTH_PASSWORD'];

var request;
if (process.env['CONTAINER_ENABLE_APACHE'] !== 'false') {

    var tls = require('tls');
    var https = require('https');

    //process.env['NODE_EXTRA_CA_CERTS'] = '/data/Root/[a-f0-9]\{64\}/certificates/ca.crt.pem';
    process.env['NODE_TLS_REJECT_UNAUTHORIZED'] = 0;

    var hostname = process.env['HOSTNAME'];
    var httpsOptions = {
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
    var http = require('http');
    var httpOptions = {
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

