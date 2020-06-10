# Certification Authority (CA) - Docker

This projects builds and provides a container for the Certification
Authority (https://gitlab.com/platynum/certification-authority).

## Configuration

Consult the [documentation of the node-red base image](https://nodered.org/docs/getting-started/docker)
for all possible configuration options.

## Start container

Start the certification authority container and expose HTTP(S) ports:

    $ IMAGE=registry.gitlab.com/platynum/certification-authority-docker:latest
    $ docker run -e NODE_RED_CREDENTIAL_SECRET=password -p 80:80 -p 443:443 $IMAGE

## Access the container

The user interface of the container is available via TCP port 443.
Direct your favorite web browser to: `https://localhost/` to use
the user inerface (UI).

## Create PKCS12/PFX container

The user interface (UI) of the CA is protected via Client Certiciate
Authentication (CCA). The key/certificate is generated automatically
during startup. To generate a PKCCS12/PFX container you have to combine
the generated files with the following shell commands inside the
container:

    $ CAFILE=$(mktemp)
    $ cat Admin/ca.crt.pem Sub/ca.crt.pem Root/ca.crt.pem >${CAFILE}
    $ openssl pkcs12 -in Admin/??[a-f1-9]*.crt.pem -inkey Admin/??[a-f1-9]*.priv.key.pem -export -out Admin.pfx -chain -CAfile ${CAFILE} -password pass:password
