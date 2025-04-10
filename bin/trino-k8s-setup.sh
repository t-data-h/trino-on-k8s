#!/usr/bin/env bash
#
#  Set up configuration values for kustomize templates.
#  source a secret.env with values needed.
#
PNAME=${0##*\/}
VERSION="v25.04.10"

binpath=$(dirname "$0")
project=$(dirname "$(realpath "$binpath")")

metacfg="hive-site.xml"
corecfg="core-site.xml"
hiveinit="hive-init-schema.yaml"
trinocm="trino-configmap.yaml"
groups="${TRINO_GROUPS_FILE:-conf/trino-groups.txt}"
rules="${TRINO_RULES_FILE:-conf/trino-rules.json}"
env="${TRINO_ENV}"
ns="trino"
psk_length=128
pwfile="trino/base/password.db"
showenv=0

# -------------------------

export HIVE_DEFAULT_IMAGE="quay.io/tcarland/hive:v3.1.3-aegir-2503.08"
export HIVE_IMAGE="${HIVE_IMAGE:-${HIVE_DEFAULT_IMAGE}}"

export TRINO_NAMESPACE="${TRINO_NAMESPACE:-${ns}}"
export HIVE_NAMESPACE="${HIVE_NAMESPACE:-${TRINO_NAMESPACE}}"

export S3_ENDPOINT="${S3_ENDPOINT:-${MINIO_ENDPOINT}}"
export S3_REGION="${S3_REGION:-us-west-2}"
export S3_ACCESS_KEY="${S3_ACCESS_KEY:-${MINIO_ACCESS_KEY}}"
export S3_SECRET_KEY="${S3_SECRET_KEY:-${MINIO_SECRET_KEY}}"

export HIVE_DBHOST="${HIVE_DBHOST:-postgres-service.${HIVE_NAMESPACE}.svc.cluster.local:5432}"
export HIVE_DBNAME="${HIVE_DBNAME:-metastore_db}"
export HIVE_DBUSER="${HIVE_DBUSER:-root}"
export HIVE_S3_BUCKET="${HIVE_S3_BUCKET:-hive}"

export TRINO_JVM_MEMORY_GB="${TRINO_JVM_MEMORY_GB:-16}"
export TRINO_JVM_HEADROOM="${TRINO_JVM_HEADROOM:-0.3}"
export TRINO_MIN_CORES=${TRINO_MIN_CORES:-2}
export TRINO_MAX_CORES=${TRINO_MAX_CORES:-4}

# -------------------------

usage="
Trino setup script for configuring deployment yamls for a given
cluster, relying on environment variables for configuring the
templates.

Synopsis:
$PNAME [-hV] [--showenv] <envname>

Options:
  -h|--help            : Show usage info and exit.
  -e|--showenv         : Show environment config and exit.
  -g|--groups  <file>  : Overrides default groups file or the env setting.
  -r|--rules   <file>  : Overrides default rules file or the env setting.
  -N|--namespace <ns>  : Override namespace default of '$ns'.
  -P|--password <user> : Create or update the trino password of a user.
                         Prompts for pw unless TRINO_PASSWORD is defined.
  -V|--version         : Show version info and exit.

   <envname>           : Name of the deployment or environment.

Supported environment variables:

  HIVE_IMAGE           : Overrides the default Hive image:
                        '$HIVE_DEFAULT_IMAGE'
  HIVE_NAMESPACE       : Defaults to the same namespace as Trino.
  TRINO_NAMESPACE      : Override the default namespace of '$ns'
       ---             : These settings relate to the backing Metastore DB
  HIVE_DBHOST          : Override the db host, defaults to the k8s service.
  HIVE_DBNAME          : Override the db name, defaults to 'metastore_db'
  HIVE_DBUSER          : Database user for the metastore, default is 'root'
  HIVE_DBPASSWORD      : Defaults to a generated random pw, if not provided.
  HIVE_S3_BUCKET       : The S3 bucket name for the data warehouse.
       ---
  TRINO_JVM_MEMORY_GB  : The total memory in GB to configure for the Trino JVM.
  TRINO_JVM_HEADROOM   : The percentage of JVM memory to reserve, default=0.3
  TRINO_MIN_CORES      : The minimum number of cores to use for Trino tasks.
  TRINO_MAX_CORES      : The maximum number of cores to use for Trino tasks.
       ---
  TRINO_ENV            : The Trino deployment environment name.
  TRINO_USER           : Trino account user name.
  TRINO_PASSWORD       : Trino account password.
  TRINO_DOMAINNAME     : Optional setting for creating an ingress manifest.

The S3 variables all support using the MINIO_XX variants.
  S3_ENDPOINT          : S3 Endpoint for object storage (or MINIO_ENDPOINT).
  S3_REGION            : S3 Region is required for the S3 client.
  S3_ACCESS_KEY        : S3 Credentials access key (or MINIO_ACCESS_KEY)
  S3_SECRET_KEY        : S3 Credentials secret key (or MINIO_SECRET_KEY)
"

# -------------------------

mysql_secrets="
MYSQLD_ROOT_PASSWORD=\${TRINO_DBPASSWORD}
"
pgsql_secrets="
POSTGRES_DB=\${HIVE_DBNAME}
POSTGRES_USER=\${HIVE_DBUSER}
POSTGRES_PASSWORD=\${HIVE_DBPASSWORD}
"
hive_secrets="
S3_REGION=\${S3_REGION}
S3_ACCESS_KEY=\${S3_ACCESS_KEY}
S3_SECRET_KEY=\${S3_SECRET_KEY}
"
trino_secrets="
S3_REGION=\${S3_REGION}
S3_ACCESS_KEY=\${S3_ACCESS_KEY}
S3_SECRET_KEY=\${S3_SECRET_KEY}
"

set_user_passwd() {
    user="$1"
    args=("-B" "-C 10")

    if [ -z "$user" ]; then
        return 1
    fi
    if [ ! -e $pwfile ]; then
        args+=("-c")
    fi

    if [ -n "$TRINO_PASSWORD" ]; then
        args+=("-i")
        ( echo "$TRINO_PASSWORD" | htpasswd ${args[@]} $pwfile $user >/dev/null 2>&1 )
    else
        ( htpasswd ${args[@]} $pwfile $user )
    fi

    return $?
}


ask()
{
    local msg="$1"
    local ans=

    printf "%s" "$msg"
    read ans

    if [ "${ans,,}" != "y" ]; then
        return 1
    fi

    return 0
}

# -------------------------
# MAIN
#
cd $project
if [ $? -ne 0 ]; then
    echo "$PNAME Error in path permissions for project dir '$project'"
    exit 1
fi

while [ $# -gt 0 ]; do
    case "$1" in
    'help'|-h|--help)
        echo "$usage"
        exit 0
        ;;
    -g|--groups)
        groups="$2"
        if [ ! -r $groups ]; then
            echo "$PNAME Error, cannot read groups file '$groups'"
            exit 1
        fi
        shift
        ;;
    -r|--rules)
        rules="$2"
        if [ ! -r $rules ]; then
            echo "$PNAME Error, cannot read rules file '$rules'"
            exit 1
        fi
        shift
        ;;
    -N|--namespace)
        ns="$2"
        export TRINO_NAMESPACE="${ns}"
        shift
        ;;
    -P|--password)
        set_user_passwd "$2"
        exit $?
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

# validation checks
if ! which yq >/dev/null 2>&1; then
    echo "$PNAME Error, required binary 'yq' not found in PATH." >&2
    echo "  Install yq from https://github.com/mikefarah/yq"
    exit 2
fi

if ! which bc >/dev/null 2>&1; then
    echo "$PNAME Error, required binary 'bc' not found in PATH." >&2
    exit 2
fi

if [ -z "$S3_ENDPOINT" ]; then
    echo "$PNAME Error, S3_ENDPOINT not defined." >&2
    exit 1
fi

if [[ -z "$S3_ACCESS_KEY" || -z "$S3_SECRET_KEY" ]]; then
    echo "$PNAME Error, S3 credentials not defined." >&2
    exit 1
fi

if [ -z "$env" ]; then
    echo "$PNAME Error, TRINO_ENV not defined" >&2
    exit 1
fi

if [[ ! -f conf/${metacfg}.template || ! -f conf/${corecfg}.template ]]; then
    echo "$PNAME Error locating the hive templates in ./conf/ " >&2
    echo " -> Ensure this script is run relative to the project root" >&2
    exit 1
fi

if [ -r env/$env/$env.env ]; then
    . env/$env/$env.env
    env=$TRINO_ENV
fi

if [ -z "$HIVE_DBPASSWORD" ]; then
    HIVE_DBPASSWORD=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | fold -w 8 | head -n 1)
    echo " -> HIVE_DBPASSWORD not set. Using auto-generated password: '${HIVE_DBPASSWORD}'"
fi

# ------------------------------------------------------------------------------

export HIVE_DBPASSWORD
export TRINO_ENV="${env}"
export TRINO_PSK="$(openssl rand $psk_length | base64 -w0)"

if [ $showenv -eq 0 ]; then
    echo " -> TRINO_ENV=${TRINO_ENV}"
    echo " -> Creating configs from templates:"

    echo " -> Creating metastore config './hive-metastore/base/${metacfg}' "
    ( cat conf/${metacfg}.template | envsubst > hive-metastore/base/${metacfg} )

    echo " -> Creating hadoop core config './hive-metastore/base/${corecfg}' "
    ( cat conf/${corecfg}.template | envsubst > hive-metastore/base/${corecfg} )

    echo " -> Creating init job './hive-metastore/base/${hiveinit}' "
    ( cat conf/${hiveinit}.template | envsubst > hive-metastore/base/${hiveinit} )

    if [ ! -d trino/overlays/${env} ]; then
        echo " -> Warning: overlay directory is missing. Copying from example overlay."
        echo " -> Overlay dir created. Be sure to validate/update the kustomization.yaml"
        ( mkdir -p trino/overlays/${env} )
        ( cp trino/overlays/example/kustomization.yaml trino/overlays/${env}/ )
    fi

    if [ -r env/${env}/auth/truststore.jks ]; then
        if [ -z "$LDAP_TRUSTSTORE_PASSWORD" ]; then
            export LDAP_TRUSTSTORE_PASSWORD="changeit"
        fi
        echo " -> Copy truststore to hive and trino base/"
        ( cp env/${env}/auth/truststore.jks trino/base )
        ( cp env/${env}/auth/truststore.jks hive-metastore/base )
    fi

    ## Configure memory settings from TRINO_JVM_MEMORY_GB
    rcnt=$(yq -r '.replicas[] | select(.name == "trino-worker") | .count // "3"' trino/overlays/${env}/kustomization.yaml)
    wmem=$(echo "$TRINO_JVM_MEMORY_GB * 0.3" | bc)
    wmem=$(echo "($wmem + 0.999)/1" | bc)
    wmem=$(($TRINO_JVM_MEMORY_GB - $wmem))
    tmem=$(($wmem * $rcnt))
    cfgtmp=$(mktemp $trinocm.XXXXX)

    export QUERY_MAX_MEMORY=$tmem
    export QUERY_MAX_MEMORY_PER_NODE=$wmem

    ( cp conf/${trinocm}.template ${cfgtmp} )
    echo " -> Creating trino ConfigMap template: '$cfgtmp'"

    if [ -d env/${env}/configs ]; then
        for f in $(ls -1 env/${env}/configs/*.properties 2>/dev/null); do
            echo " ->   Appending '$f' to '$cfgtmp'"
            cat $f >> ${cfgtmp}
        done
    fi

    echo " -> Creating trino ConfigMap from template: './trino/base/${trinocm}'"
    ( cat ${cfgtmp} | envsubst > trino/base/${trinocm} )
    unlink $cfgtmp

    if [ -d env/${env}/files ]; then
        echo " -> Copying env files to overlay 'trino/overlays/$env'"
        for f in $(ls -1 env/${env}/files/ 2>/dev/null); do
            ( cp env/${env}/files/${f} trino/overlays/${env}/ )
        done
    fi

    if [ -d env/${env}/base ]; then
        echo " -> Copying env base files to 'trino/base/'"
        for f in $(ls -1 env/${env}/base/ 2>/dev/null); do
            ( cp env/${env}/base/$f trino/base/ )
        done
    fi

    if [ -r env/${env}/auth/trino-groups.txt ]; then
        groups="env/${env}/auth/trino-groups.txt"
    fi

    if [ -r env/$env/auth/trino-rules.json ]; then
        rules="env/${env}/auth/trino-rules.json"
    fi

    echo " -> Creating trino groups config from '$groups'"
    ( cp $groups trino/base/ )
    echo " -> Creating trino rules config from '$rules'"
    ( cp $rules trino/base/ )

    echo " -> Creating secrets files './**/base/secrets.env' "
    ( echo "$mysql_secrets" | envsubst > mysql-server/base/secrets.env )
    ( echo "$pgsql_secrets" | envsubst > postgresdb/base/secrets.env )
    ( echo "$hive_secrets" | envsubst > hive-metastore/base/secrets.env )
    ( echo "$trino_secrets" | envsubst > trino/base/secrets.env )

    if [ -n "$HIVE_DOMAINNAME" ]; then
        echo " -> Creating hive ingress config in 'hive-metastore/resources/'"
        ( cat hive-metastore/resources/istio/base/params.env.template | envsubst > hive-metastore/resources/istio/base/params.env )
        ( cat hive-metastore/resources/nginx/base/params.env.template | envsubst > hive-metastore/resources/nginx/base/params.env )
    fi
    if [ -n "$TRINO_DOMAINNAME" ]; then
        echo " -> Creating trino ingress config in 'trino/resources/'"
        ( cat trino/resources/istio/base/params.env.template | envsubst > trino/resources/istio/base/params.env )
        ( cat trino/resources/nginx/base/params.env.template | envsubst > trino/resources/nginx/base/params.env )
    fi

    if [[ -z "$TRINO_PASSWORD_FILE" && -r "env/${env}/auth/password.db" ]]; then
        TRINO_PASSWORD_FILE="env/${env}/auth/password.db"
    fi

    if [ -n "$TRINO_PASSWORD_FILE" ]; then
        echo " -> Copying password db from '$TRINO_PASSWORD_FILE"
        ( cp "$TRINO_PASSWORD_FILE" trino/base/password.db )
    fi

    if [[ -n "$TRINO_USER" && -n "$TRINO_PASSWORD" ]]; then
        echo " -> Setting trino admin user in the password.db"
        set_user_passwd "$TRINO_USER"
    elif [[ ! -e trino/base/password.db ]]; then
        echo ""
        echo " -> WARNING! 'password.db' is missing from 'trino/base'! "
        echo " -> Be sure to create a trino account via -P before applying/installing manifests."
    fi
fi

echo "
Environment configuration:"
echo "
 TRINO_ENV='$TRINO_ENV'

 S3_ENDPOINT='$S3_ENDPOINT'
 S3_REGION='$S3_REGION'
 S3_ACCESS_KEY='$S3_ACCESS_KEY'
 S3_SECRET_KEY='***********'

 HIVE_DBHOST='$HIVE_DBHOST'
 HIVE_DBNAME='$HIVE_DBNAME'
 HIVE_DBUSER='$HIVE_DBUSER'
 HIVE_DBPASSWORD='************'
 HIVE_S3_BUCKET='$HIVE_S3_BUCKET'

 TRINO_USER='$TRINO_USER'
 TRINO_PASSWORD='***********'
 TRINO_DOMAINNAME='$TRINO_DOMAINNAME'

 TRINO_JVM_MEMORY_GB="$TRINO_JVM_MEMORY_GB"
 TRINO_MIN_CORES=$TRINO_MIN_CORES
 TRINO_MAX_CORES=$TRINO_MAX_CORES
"

exit 0
