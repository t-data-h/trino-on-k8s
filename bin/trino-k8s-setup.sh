#!/usr/bin/env bash
#
#  Set up configuration values for kustomize templates.
#  source a secret.env with values needed.
#
PNAME=${0##*\/}
VERSION="v22.10.20"

metacfg="hive-site.xml"
corecfg="core-site.xml"
hiveinit="hive-init-schema.yaml"
trinocm="trino-configmap.yaml"
showenv=0
env="test"

# -------------------------

export HIVE_DEFAULT_IMAGE="quay.io/tcarland/hive:v3.1.3-tethys-2206.01"
export HIVE_IMAGE="${HIVE_IMAGE:-${HIVE_DEFAULT_IMAGE}}"

export TRINO_NAMESPACE="${TRINO_NAMESPACE:-trino}"
export HIVE_NAMESPACE="${HIVE_NAMESPACE:-${TRINO_NAMESPACE}}"

export S3_ENDPOINT="${S3_ENDPOINT:-${MINIO_ENDPOINT}}"
export S3_ACCESS_KEY="${S3_ACCESS_KEY:-${MINIO_ACCESS_KEY}}"
export S3_SECRET_KEY="${S3_SECRET_KEY:-${MINIO_SECRET_KEY}}"

export MYSQLD_USER="${MYSQLD_USER:-root}"

# -------------------------

usage="
Trino setup script for configuring deployment yamls for a given
cluster, relying on environment variables for configuring the 
templates.

Synopsis:
$PNAME [-hV] [--showenv] <envname>

Options:
  -h|--help     : Show usage info and exit.
  -V|--version  : Show version info and exit.
  -e|--showenv  : Show environment configuration only.

  <envname>     : Name of the deployment or environment.

Supported environment variables:

  HIVE_IMAGE           : Overrides the default Hive image: 
                        '$HIVE_DEFAULT_IMAGE'
  TRINO_NAMESPACE      : Override the default namespace of 'trino'
  MYSQLD_ROOT_PASSWORD : Defaults to a generated random pw if not provided.

The S3_ variables all support using the MINIO_ variants.
  S3_ENDPOINT          : S3 Endpoint for object storage (or MINIO_ENDPOINT).
  S3_ACCESS_KEY        : S3 Credentials access key (or MINIO_ACCESS_KEY)
  S3_SECRET_KEY        : S3 Credentials secret key (or MINIO_SECRET_KEY)
"

# -------------------------
# MAIN
# 
while [ $# -gt 0 ]; do
    case "$1" in
        'help'|-h|--help)
            echo "$usage"
            exit 0
            ;;
        'showenv'|-e|--showenv)
            showenv=1
            ;;
        'version'|-V|--version)
            echo "$PNAME $VERSION"
            exit 0
            ;;
        *)
            env="$1"
            shift
            ;;
    esac
    shift
done

if [ -z "$S3_ENDPOINT" ]; then
    echo "$PNAME Error, S3_ENDPOINT not defined." >&2
fi

if [[ -z "$S3_ACCESS_KEY" || -z "$S3_SECRET_KEY" ]]; then
    echo "$PNAME Error, S3 credentials not defined." >&2
    exit 1
fi

if [[ ! -f conf/${metacfg}.template || ! -f conf/${corecfg}.template ]]; then
    echo "$PNAME Error locating the hive templates in ./conf/ " >&2
    echo " -> Ensure this script is run relative to the project root" >&2
    exit 1
fi


if [ -z "$MYSQLD_ROOT_PASSWORD" ]; then
    MYSQLD_ROOT_PASSWORD=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | fold -w 8 | head -n 1)
    echo " # MYSQLD_ROOT_PASSWORD not set. Using auto-generated password: '${MYSQLD_ROOT_PASSWORD}'"
fi
export MYSQLD_ROOT_PASSWORD
export TRINO_ENV="${env}"

if [ $showenv -eq 0 ]; then
    echo " #  TRINO_ENV=${TRINO_ENV}"
    echo " #  Creating metastore config './hive-metastore/base/${metacfg}' "
    ( cat conf/${metacfg}.template | envsubst > hive-metastore/base/${metacfg} )

    echo " #  Creating Hadoop core config './hive-metastore/base/${corecfg}' "
    ( cat conf/${corecfg}.template | envsubst > hive-metastore/base/${corecfg} )

    echo " #  Creating init job './hive-metastore/base/${hiveinit}' "
    ( cat conf/${hiveinit}.template | envsubst > hive-metastore/base/${hiveinit} )

    echo " #  Creating trino ConfigMap './trino/base/${trinocm}' "
    ( cat conf/${trinocm}.template | envsubst > trino/base/${trinocm} )
fi


echo " #  Environment configuration:"
echo "
export S3_ENDPOINT=\"$S3_ENDPOINT\"
export S3_ACCESS_KEY=\"$S3_ACCESS_KEY\"
export S3_SECRET_KEY=\"$S3_SECRET_KEY\"
export MYSQLD_USER=\"$MYSQLD_USER\"
export MYSQLD_ROOT_PASSWORD=\"$MYSQLD_ROOT_PASSWORD\"
"

if [ "$showenv" -gt 0 ]; then
    echo " # Copy the above or run \`eval $(./bin/$PNAME)\` to configure the current environment."
fi 

exit 0
