#!/usr/bin/env bash
#
#  Sets up configuration values for kustomize
#
env="$1"
version="v21.07"

metacfg="metastore-site.xml"
corecfg="core-site.xml"
hiveinit="hive-init-schema.yaml"
trinocm="trino-configmap.yaml"

export TRINO_NAMESPACE="${TRINO_NAMESPACE:-trino}"
export S3_ENDPOINT="${S3_ENDPOINT:-${MINIO_ENDPOINT}}"
export S3_ACCESS_KEY="${S3_ACCESS_KEY:-${MINIO_ACCESS_KEY}}"
export S3_SECRET_KEY="${S3_SECRET_KEY:-${MINIO_SECRET_KEY}}"
export MYSQLD_USER="${MYSQLD_USER:-root}"
MYSQLD_ROOT_PASSWORD="${MYSQLD_ROOT_PASSWORD}"

if [[ -z "$S3_ENDPOINT" || -z "$S3_ACCESS_KEY" || -z "$S3_SECRET_KEY" ]]; then
    echo "Error locating S3 credentials.."
    exit 1
fi

if [[ ! -f conf/${metacfg}.template || ! -f conf/${corecfg}.template ]]; then
    echo "Error locating hive configurations in ./conf/ "
    echo " -> Ensure this script is run relative to project root"
    exit 1
fi

if [ -z "$MYSQLD_ROOT_PASSWORD" ]; then
    export MYSQLD_ROOT_PASSWORD=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | fold -w 8 | head -n 1)
    echo " # MYSQLD_ROOT_PASSWORD not set. Using auto-generated password: '${MYSQLD_ROOT_PASSWORD}'"
fi

if [ -z "$env" ]; then
    echo " #  Creating metastore config './hive-metastore/base/${metacfg}' "
    ( cat conf/${metacfg}.template | envsubst > hive-metastore/base/${metacfg} )

    echo " #  Creating Hadoop core config './hive-metastore/base/${corecfg}' "
    ( cat conf/${corecfg}.template | envsubst > hive-metastore/base/${corecfg} )

    echo " #  Creating '${hiveinit}' "
    ( cat conf/${hiveinit}.template | envsubst > ${hiveinit} )

    echo " #  Creating trino ConfigMap './trino/base/${trinocm}' "
    ( cat conf/${trinocm}.template | envsubst > trino/base/${trinocm} )
fi

echo " #  Environment variable configuration:"
echo "
export S3_ENDPOINT=\"$S3_ENDPOINT\"
export S3_ACCESS_KEY=\"$S3_ACCESS_KEY\"
export S3_SECRET_KEY=\"$S3_SECRET_KEY\"
export MYSQLD_USER=\"$MYSQLD_USER\"
export MYSQLD_ROOT_PASSWORD=\"$MYSQLD_ROOT_PASSWORD\"
export TRINO_NAMESPACE=\"$TRINO_NAMESPACE\"
"

if [ -n "$env" ]; then
    echo ' # Run `eval $(./bin/setup.sh)` to configure the current environment.'
fi 

exit 0
