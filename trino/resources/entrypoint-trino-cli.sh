#!/usr/bin/env bash
#
uri="${TRINO_URI:-http://trino-coordinator-service.trino.svc.cluster.local:8080}"
user="${TRINO_USER:-trino}"

args=("--server" "$uri"
      "--user" "$user")

if [ -n "$TRINO_PASSWORD" ]; then
    args+=("--password")
fi

if [ -n "$TRINO_CATALOG" ]; then
    args+=("--catalog" "$TRINO_CATALOG")
fi 

app_suffix=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | fold -w 5 | head -n 1)
app_suffix="$(random_letter)${app_suffix}$(random_letter)"
pod_name="trino-cli-${app_suffix,,}"

echo "trino-cli ${args[@]}"
exec trino-cli ${args[@]}
