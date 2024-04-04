#!/usr/bin/env bash
#
#  Set up configuration values for kustomize templates.
#  source a secret.env with values needed.
#
PNAME=${0##*\/}
VERSION="v24.04.04"

metacfg="hive-site.xml"
corecfg="core-site.xml"
hiveinit="hive-init-schema.yaml"
trinocm="trino-configmap.yaml"
showenv=0
dryrun=0
install=0
env="test"
ns="trino"
apply="apply"

components=("mysql-server" "hive-metastore" "trino")

# -------------------------

export HIVE_DEFAULT_IMAGE="quay.io/tcarland/hive:v3.1.3-fenrir-2402.28"
export HIVE_IMAGE="${HIVE_IMAGE:-${HIVE_DEFAULT_IMAGE}}"

export TRINO_NAMESPACE="${TRINO_NAMESPACE:-${ns}}"
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
  -h|--help            : Show usage info and exit.
  -e|--showenv         : Show environment configuration only.
  -I|--install         : Run kustomize to install the complete stack. 
                         An overlay of <envname> is used if it exists.
  -U|--uninstall       : Runs kustomize to delete all resources.
  -n|--dry-run         : Enable dry-run, no manifests are applied.
  -N|--namespace <ns>  : Override namespace default of '$ns'.
  -V|--version         : Show version info and exit.

  <envname>            : Name of the deployment or environment.

Supported environment variables:

  HIVE_IMAGE           : Overrides the default Hive image: 
                        '$HIVE_DEFAULT_IMAGE'
  TRINO_NAMESPACE      : Override the default namespace of '$ns'
  MYSQLD_ROOT_PASSWORD : Defaults to a generated random pw if not provided.

The S3 variables all support using the MINIO_XX variants.
  S3_ENDPOINT          : S3 Endpoint for object storage (or MINIO_ENDPOINT).
  S3_ACCESS_KEY        : S3 Credentials access key (or MINIO_ACCESS_KEY)
  S3_SECRET_KEY        : S3 Credentials secret key (or MINIO_SECRET_KEY)
"

# -------------------------

mysql_secrets="
MYSQLD_ROOT_PASSWORD=\${MYSQLD_ROOT_PASSWORD}
"
hive_secrets="
S3_ACCESS_KEY=\${S3_ACCESS_KEY}
S3_SECRET_KEY=\${S3_SECRET_KEY}
"
trino_secrets="
S3_ACCESS_KEY=\${S3_ACCESS_KEY}
S3_SECRET_KEY=\${S3_SECRET_KEY}
MYSQLD_ROOT_PASSWORD=\${MYSQLD_ROOT_PASSWORD}
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
    -I|--install)
        install=1
        ;;
    -U|--uninstall)
        install=1
        apply="delete"
        ;;
    -n|--dry-run|--dryrun)
        dryrun=1
        ;;
    -N|--namespace)
        ns="$2"
        export TRINO_NAMESPACE="${ns}"
        shift
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
    exit 1
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
    echo "# MYSQLD_ROOT_PASSWORD not set. Using auto-generated password: '${MYSQLD_ROOT_PASSWORD}'"
fi

export MYSQLD_ROOT_PASSWORD
export TRINO_ENV="${env}"

if [ $showenv -eq 0 ]; then
    echo " #  Creating configs from templates:" 
    echo " #  TRINO_ENV=${TRINO_ENV}"
    echo " #  Creating metastore config './hive-metastore/base/${metacfg}' "
    ( cat conf/${metacfg}.template | envsubst > hive-metastore/base/${metacfg} )

    echo " #  Creating Hadoop core config './hive-metastore/base/${corecfg}' "
    ( cat conf/${corecfg}.template | envsubst > hive-metastore/base/${corecfg} )

    echo " #  Creating init job './hive-metastore/base/${hiveinit}' "
    ( cat conf/${hiveinit}.template | envsubst > hive-metastore/base/${hiveinit} )

    echo " #  Creating trino ConfigMap './trino/base/${trinocm}' "
    ( cat conf/${trinocm}.template | envsubst > trino/base/${trinocm} )

    echo " #  Creating secrets './**/base/secrets.env' "
    ( echo "$mysql_secrets" | envsubst > mysql-server/base/secrets.env )
    ( echo "$hive_secrets" | envsubst > hive-metastore/base/secrets.env )
    ( echo "$trino_secrets" | envsubst > trino/base/secrets.env )
fi

echo "
#  Environment configuration:"
echo "
export S3_ENDPOINT=\"$S3_ENDPOINT\"
export S3_ACCESS_KEY=\"$S3_ACCESS_KEY\"
export S3_SECRET_KEY=\"$S3_SECRET_KEY\"
export MYSQLD_USER=\"$MYSQLD_USER\"
export MYSQLD_ROOT_PASSWORD=\"$MYSQLD_ROOT_PASSWORD\"
"

if [ $showenv -gt 0 ]; then
    echo ""
    echo " # Copy and paste the above or eval this script"
    exit 0
fi

rt=0
# Install components via kustomize
if [ $install -eq 1 ]; then
    for app in ${components[@]}; do
        ol="$app/"
        if [[ $name != "base" && -d $app/overlays/$env ]]; then
            ol="$app/overlays/$env/"
        fi

        echo " -> kustomize build $ol"

        if [ $dryrun -eq 0 ]; then
            kustomize build $ol | kubectl $apply -f -
            rt=$?
        fi

        if [ $rt -ne 0 ]; then
            echo "$PNAME Error in kustomize"
            break
        fi

        if [[ $dryrun -eq 0 && $apply == "apply" ]]; then
            kubectl wait deployment $app --for=condition=Available=true --timeout=120s -n $ns 
            rt=$?
            if [ $rt -ne 0 ]; then
                break
            fi
        fi
    done
fi

exit $rt
