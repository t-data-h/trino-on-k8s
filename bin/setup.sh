#!/usr/bin/env bash
#
#  Sets up configuration values for kustomize
#
metacfg="metastore-site.xml"
corecfg="core-site.xml"

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

if [[ ! -f conf/$metacfg || ! -f conf/$corecfg ]]; then
    echo "Error locating hive configurations in ./conf/ "
    echo "  Ensure this script is run relative to project root"
    exit 1
fi

if [ -z "$HIVE_PASSWORD" ]; then
    HIVE_PASSWORD=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | fold -w 8 | head -n 1)
    echo " -> HIVE_PASSWORD not set. Using auto-generated password: '$HIVE_PASSWORD'"
fi
export HIVE_PASSWORD

( cat conf/$metacfg | envsubst > hive-metastore/base/$metacfg )
( cat conf/$corecfg | envsubst > hive-metastore/base/$corecfg )

( cat hive-initschema.tmpl | envsubst > hive-init-schema.yaml )

exit 0
