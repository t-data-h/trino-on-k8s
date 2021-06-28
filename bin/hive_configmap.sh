#!/usr/bin/env bash
#

metacfg="conf/metastore-site.xml"
corecfg="conf/core-site.xml"
metatmp="metastore-site.xml"
coretmp="core-site.xml"

if [ -z "$MINIO_ENV_SH" ]; then
    . ~/.minio_env.sh
fi

export HIVE_NS="${HIVE_NAMESPACE:-hive-metastore}"
export S3_ENDPOINT="${S3_ENDPOINT:-$(minio_endpoint)}"
export S3_ACCESS_KEY="${S3_ACCESS_KEY:-$(minio_accesskey)}"
export S3_SECRET_KEY="${S3_SECRET_KEY:-$(minio_secretkey)}"
export HIVE_USER="${HIVE_USER:-hive}"
HIVE_PASSWORD="${HIVE_PASSWORD}"

if [[ -z "$S3_ENDPOINT" || -z "$S3_ACCESS_KEY" || -z "$S3_SECRET_KEY" ]]; then
    echo "Error locating S3 credentials.."
    exit 1
fi

if [[ ! -f $metacfg || ! -f $corecfg ]]; then
    echo "Error locating hive config."
    echo "  Ensure this script is run relative to project root"
    exit 1
fi

if [ -z "$HIVE_PASSWORD" ]; then
    export HIVE_PASSWORD=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | fold -w 8 | head -n 1)
fi

( cat $metacfg | envsubst > $metatmp )
( cat $corecfg | envsubst > $coretmp )

( kubectl create configmap hive-metastore-cm \
  --dry-run \
  --namespace $HIVE_NS \
  --from-file=$metatmp \
  --from-file=$coretmp -o yaml > hive-metastore-cm.yaml )

( rm -f $metatmp $coretmp )

( kubectl create secret generic hive-secrets \
  --from-literal=access-key="$S3_ACCESS_KEY" \
  --from-literal=secret-key="$S3_SECRET_KEY" \
  -n $HIVE_NS )

exit 0

