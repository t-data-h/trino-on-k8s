#!/usr/bin/env bash
#

metacfg="conf/metastore-site.xml"
corecfg="conf/core-site.xml"

if [ -z "$MINIO_ENV_SH" ]; then
    . ~/.minio_env.sh
fi

HIVE_NS="${HIVE_NAMESPACE:-hive}"
S3_ENDPOINT="${S3_ENDPOINT:-$(minio_endpoint)}"
S3_ACCESS_KEY="${S3_ACCESS_KEY:-$(minio_accesskey)}"
S3_SECRET_KEY="${S3_SECRET_KEY:-$(minio_secretkey)}"
HIVE_USER="${HIVE_USER:-hive}"
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
    HIVE_PASSWORD=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | fold -w 8 | head -n 1)
fi

cfg_suffix=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n 1)
metatmp="meta-site-${cfg_suffix}.xml"
coretmp="core-site-${cfg_suffix}.xml"

( cat $metacfg | envsubst > $metatmp )
( cat $corecfg | envsubst > $coretmp )

( kubectl create configmap hive-metastore-cm \
  --dry-run \
  --namespace $HIVE_NS \
  --from-file=$metatmp \
  --from-file=$coretmp -o yaml > hive-metastore-cm.yaml )

( rm -f $metatmp $coretmp )

( kubectl create secret generic hive-s3-keys \
  --from-literal=access-key="$S3_ACCESS_KEY" \
  --from-literal=secret-key="$S3_SECRET_KEY" \
  -n $HIVE_NS )

exit 0

