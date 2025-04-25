#!/usr/bin/env bash
#
ver="${TRINO_VERSION:-475}"
image="${TRINO_IMAGE:-quay.io/tcarland/trino-cli:${ver}}"
ns=${TRINO_NAMESPACE:-trino}
catalog="${TRINO_CATALOG:-iceberg}"
envstr="TRINO_CATALOG=$catalog"

function random_letter()
{
    rand=$(echo $(( $RANDOM % 26 )))
    printf "\\$(printf '%03o' $((97 + $rand)))"
}

app_suffix=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | fold -w 5 | head -n 1)
app_suffix="$(random_letter)${app_suffix}$(random_letter)"
pod_name="trino-cli-${app_suffix,,}"

if [ -n "$TRINO_URI" ]; then
    envstr="${envstr},TRINO_URI=${TRINO_URI}"
fi
if [ -n "$TRINO_USER" ]; then
    envstr="${envstr},TRINO_USER=${TRINO_USER}"
fi
if [ -n "$TRINO_PASSWORD" ]; then
    envstr="${envstr},TRINO_PASSWORD=${TRINO_PASSWORD}"
fi

( kubectl run -n $ns -i --tty $pod_name \
  --restart=Never \
  --rm \
  --image $image \
  --env "$envstr"
)

exit $?
