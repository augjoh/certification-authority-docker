# Certification Authority (CA) - Docker

This projects builds and provides a container for the Certification
Authority (https://gitlab.com/platynum/certification-authority).

## Configuration

Consult the [documentation of the node-red](https://nodered.org/docs/user-guide/runtime/configuration)
for all possible configuration options. Some of them have been mapped
to environment variables. If you are using docker, you can specify them
using the `-e` command line flag.

The following configuration items in settings.js can be configured using
environment variables:

 * `credentialSecret`: `NODE_RED_CREDENTIAL_SECRET`, this setting has
   **no default**
 * `logging.console.level`: `NODE_RED_LOGGING_CONSOLE_LEVEL` defaults to
   `info`
 * `httpAdminRoot`: `NODE_RED_HTTP_ADMIN_ROOT` || defaults to '/admin'

The following settings should not be changed, unless you know what your
are doing, otherwise the Apache reverse proxy might not function
correctly!

 * `uiHost`: `NODE_RED_UI_HOST`, defaults to `127.0.0.1`
 * `uiPort`: `NODE_RED_UI_PORT`, defaults to `1880`
 * `disableEditor`: `NODE_RED_DISABLE_EDITOR`, defaults to `true`
 * `editorTheme.projects.enabled`: `NODE_RED_ENABLE_PROJECTS`, defaults
   to `false`

The [page of node-red's docker container](https://nodered.org/docs/getting-started/docker)
contains additional information about the base image for this container.

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
during startup. To generate a PKCS12/PFX container you have to combine
the generated files with the following shell commands inside the
container:

    $ CAFILE=$(mktemp)
    $ cat Admin/ca.crt.pem Sub/ca.crt.pem Root/ca.crt.pem >${CAFILE}
    $ openssl pkcs12 -in Admin/??[a-f1-9]*.crt.pem -inkey Admin/??[a-f1-9]*.priv.key.pem -export -out Admin.pfx -chain -CAfile ${CAFILE} -password pass:password

## Import PKCS12/PFX container

Import this container into the certificate store:

    PS C:\>$mypwd = Get-Credential -UserName 'Enter password below' -Message 'Enter password below'
    PS C:\>Import-PfxCertificate -FilePath C:\Admin.pfx -CertStoreLocation Cert:\CurrentUser\My -Password $mypwd.Password

# License

Certification Authority (CA) docker source code files are made
available under GNU Affero General Public License, Version 3.0,
located in the [LICENSE](LICENSE) file.

