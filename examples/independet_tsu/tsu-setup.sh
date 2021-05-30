#!/usr/bin/env bash

declare -a INSTANCES=(
    tsu-1
    tsu-2
)

if [ ! -f tsu.env ]; then
cat >tsu.env <<-EOF
	CONTAINER_ENABLE_APACHE=false
	CONTAINER_ENABLE_FLOWS=Initialize|CRL|TSA|Exit
	TSA_CERTIFICATE_VALIDITY=10
	TSA_CERTIFICATE_RENEWAL=-1
	NODE_RED_CREDENTIAL_SECRET=$(openssl rand -hex 16)
	#NODE_RED_UI_HOST=0.0.0.0
	#NODE_RED_DISABLE_EDITOR=false
EOF
fi

if [ ! -d root ]; then
    mkdir root
    chown 1000:1000 root
fi
for instance in "${INSTANCES[@]}"; do
    if [ ! -d "${instance}" ]; then
        mkdir "${instance}"
        chown 1000:1000 "${instance}"
    fi
    set -x
    podman run -it --rm --hostname "${instance}.tsa.my.corp" --name "${instance}" \
               --env-file tsu.env \
               -v "$(pwd)/${instance}:/data/Root/tsa" \
               -v "$(pwd)/root:/data/Root" \
               registry.gitlab.com/platynum/certification-authority/container:development
    { set +x; } 2>/dev/null
done

for instance in "${INSTANCES[@]}"; do
    tar czf "${instance}.$(date +%Y%m%d).tar.gz" --exclude root/keys \
        --transform 's/root/Root/' --transform "s/${instance}/Root\/tsa/" \
        root "${instance}"
done
ls -l ./*.tar.gz
