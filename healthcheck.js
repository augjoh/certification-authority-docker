#!/usr/bin/env node
var proto = require('https');
var tls = require('tls');

var hostname = process.env['HOSTNAME'];
var options = {
    host: 'localhost',
    port: 443,
    path: '/download/Sub/ca.crt.pem',
    timeout: 4000,
    checkServerIdentity: function(host, cert) {
        return tls.checkServerIdentity(hostname, cert);
    }
};

var request = proto.request(options, (res) => {
    console.log(`STATUS: ${res.statusCode}`);
    if ((res.statusCode >= 200) && (res.statusCode < 400)) {
        process.exit(0);
    }
    else {
        process.exit(1);
    }
});

request.on('error', function(err) {
    console.log('ERROR', err);
    process.exit(1);
});

request.end();
