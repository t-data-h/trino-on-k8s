#!/usr/bin/env bash
#
#  Sets up configuration values for kustomize
#
metacfg="metastore-site.xml"
corecfg="core-site.xml"

export HIVE_NS="${HIVE_NAMESPACE:-hive-metastore}"
export TRINO_NAMESPACE=${TRINO_NAMESPACE:-trino}"
export S3_ENDPOINT="${S3_ENDPOINT:-${MINIO_ENDPOINT}}"
export S3_ACCESS_KEY="${S3_ACCESS_KEY:-${MINIO_ACCESS_KEY}}"
export S3_SECRET_KEY="${S3_SECRET_KEY:-${MINIO_SECRET_KEY}}"
export MYSQLD_USER="${MYSQLD_USER:-root}"
MYSQLD_ROOT_PASSWORD="${MYSQLD_ROOT_PASSWORD}"

if [[ -z "$S3_ENDPOINT" || -z "$S3_ACCESS_KEY" || -z "$S3_SECRET_KEY" ]]; then
    echo "Error locating S3 credentials.."
    exit 1
fi

if [[ ! -f conf/$metacfg || ! -f conf/$corecfg ]]; then
    echo "Error locating hive configurations in ./conf/ "
    echo " -> Ensure this script is run relative to project root"
    exit 1
fi

if [ -z "$MYSQLD_ROOT_PASSWORD" ]; then
    export MYSQLD_ROOT_PASSWORD=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | fold -w 8 | head -n 1)
    echo " -> MYSQLD_ROOT_PASSWORD not set. Using auto-generated password: '$MYSQLD_ROOT_PASSWORD'"
fi


echo " -> Creating metastore config './hive-metastore/base/$metacfg' "
( cat conf/$metacfg | envsubst > hive-metastore/base/$metacfg )

echo " -> Creating Hadoop core config './hive-metastore/base/$corecfg' "
( cat conf/$corecfg | envsubst > hive-metastore/base/$corecfg )

echo " -> Creating 'hive-init-schema.yaml' "
( cat hive-metastore/hive-init-schema.yaml.template | envsubst > hive-init-schema.yaml )

echo " -> Creating trino './trino/base/configmap.yaml' "
( cat trino/configmap.yaml.template | envsubst > trino/base/configmap.yaml )


echo " -> hive-metastore environment variables needed prior to running kustomize:"
echo "
export S3_ENDPOINT=\"$S3_ENDPOINT\"
export S3_ACCESS_KEY=\"$S3_ACCESS_KEY\"
export S3_SECRET_KEY=\"$S3_SECRET_KEY\"
export MYSQLD_USER=\"$MYSQLD_USER\"
export MYSQLD_ROOT_PASSWORD=\"$MYSQLD_ROOT_PASSWORD\"
export HIVE_NAMESPACE=\"$HIVE_NAMESPACE\"
export TRINO_NAMESPACE=\"$TRINO_NAMESPACE\"
"

exit 0
