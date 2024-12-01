#!/usr/bin/env bash
#
#  Set up configuration values for kustomize templates.
#  source a secret.env with values needed.
#
PNAME=${0##*\/}
VERSION="v24.12.01"

binpath=$(dirname "$0")
project=$(dirname "$(realpath "$binpath")")

metacfg="hive-site.xml"
corecfg="core-site.xml"
hiveinit="hive-init-schema.yaml"
trinocm="trino-configmap.yaml"
groups="${TRINO_GROUPS_FILE:-conf/trino-groups.txt}"
rules="${TRINO_RULES_FILE:-conf/trino-rules.json}"
showenv=0
dryrun=0
install=0
env="${TRINO_ENV:-test}"
ns="trino"
apply="apply"
psk_length=128
pwfile="trino/base/password.db"

components=("mysql-server" "hive-metastore" "trino")

# -------------------------

export HIVE_DEFAULT_IMAGE="quay.io/tcarland/hive:v3.1.3-fenrir-2410.02"
export HIVE_IMAGE="${HIVE_IMAGE:-${HIVE_DEFAULT_IMAGE}}"

export TRINO_NAMESPACE="${TRINO_NAMESPACE:-${ns}}"
export HIVE_NAMESPACE="${HIVE_NAMESPACE:-${TRINO_NAMESPACE}}"

export S3_ENDPOINT="${S3_ENDPOINT:-${MINIO_ENDPOINT}}"
export S3_ACCESS_KEY="${S3_ACCESS_KEY:-${MINIO_ACCESS_KEY}}"
export S3_SECRET_KEY="${S3_SECRET_KEY:-${MINIO_SECRET_KEY}}"
export S3_BUCKET_NAME="${S3_BUCKET_NAME:-hive}"

export TRINO_DBUSER="${TRINO_DBUSER:-root}"

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
  -g|--groups  <file>  : Overrides default groups file or the env setting.
  -r|--rules   <file>  : Overrides default rules file or the env setting.
  -I|--install         : Run kustomize to install the complete stack. 
                         An overlay of <envname> is used if it exists.
  -U|--uninstall       : Runs kustomize to delete all resources.
  -n|--dry-run         : Enable dry-run, no manifests are applied.
  -N|--namespace <ns>  : Override namespace default of '$ns'.
  -P|--password <user> : Create or update the trino password of a user. 
                         Prompts for pw unless TRINO_PASSWORD is defined.
  -V|--version         : Show version info and exit.

  <envname>            : Name of the deployment or environment.

Supported environment variables:

  HIVE_IMAGE           : Overrides the default Hive image: 
                        '$HIVE_DEFAULT_IMAGE'
  HIVE_NAMESPACE       : Defaults to the same namespace as Trino.
  TRINO_NAMESPACE      : Override the default namespace of '$ns'
       ---             : These settings relate to the backing Metastore DB
  TRINO_DBUSER         : Database user for the metastore, default is 'root' 
  TRINO_DBPASSWORD     : Defaults to a generated random pw, if not provided.
  TRINO_DOMAINNAME     : Optional setting for creating an ingress manifest.
       ---
  TRINO_USER           : Trino account user name.
  TRINO_PASSWORD       : Trino account password.
  TRINO_PASSWORD_FILE  : A source 'password.db' to be used (auto-created).
  TRINO_GROUPS_FILE    : The 'groups' file, def: 'conf/trino-groups.txt'
  TRINO_RULES_FILE     : The 'rules.json' file, def: 'conf/trino-rules.txt'

The S3 variables all support using the MINIO_XX variants.
  S3_ENDPOINT          : S3 Endpoint for object storage (or MINIO_ENDPOINT).
  S3_ACCESS_KEY        : S3 Credentials access key (or MINIO_ACCESS_KEY)
  S3_SECRET_KEY        : S3 Credentials secret key (or MINIO_SECRET_KEY)
  S3_BUCKET_NAME       : The S3 bucket for the data warehouse
"

# -------------------------

mysql_secrets="
MYSQLD_ROOT_PASSWORD=\${TRINO_DBPASSWORD}
"
pgsql_secrets="
POSTGRES_DB=metastore_db
POSTGRES_USER=\${TRINO_DBUSER}
POSTGRES_PASSWORD=\${TRINO_DBPASSWORD}
"
hive_secrets="
S3_ACCESS_KEY=\${S3_ACCESS_KEY}
S3_SECRET_KEY=\${S3_SECRET_KEY}
"
trino_secrets="
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
    -I|--install)
        install=1
        ;;
    -U|--uninstall)
        install=1
        apply="delete"
        ask "Are you sure you wish to delete all components? (y/n)"
        if [ $? -ne 0 ]; then
            echo "$PNAME aborting.."
            exit 0
        fi 
        ;;
    -n|--dry-run|--dryrun)
        dryrun=1
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

if [ -z "$TRINO_DBPASSWORD" ]; then
    TRINO_DBPASSWORD=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | fold -w 8 | head -n 1)
    echo "# TRINO_DBPASSWORD not set. Using auto-generated password: '${TRINO_DBPASSWORD}'"
fi

export TRINO_DBUSER
export TRINO_DBPASSWORD
export TRINO_ENV="${env}"
export TRINO_PSK="$(openssl rand $psk_length | base64 -w0)"

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

    if [ -d env/${env}/configs ]; then
        for f in $(ls -1 env/${env}/configs/*.properties); do
            echo " #  Appending '$f' to $trinocm"
            cat $f >> trino/base/${trinocm}
        done
    fi

    if [ -d env/${env}/files ]; then
        if [ ! -d trino/overlays/${env} ]; then
            echo " #  Warning: overlay directory missing"
            echo " #  overlay dir created. Be sure to update the kustomization.yaml"
            ( mkdir -p trino/overlays/${env} )
        fi
        for f in $(ls -1 env/${env}/files/); do
            ( cp env/${env}/files/${f} overlays/${env}/ )
        done
    fi

    if [ -d env/${env}/base ]; then
        for f in $(ls -1 env/${env}/base/); do
            ( cp env/${env}/base/$f trino/base/ )
        done
    fi

    if [ -r env/${env}/auth/trino-groups.txt ]; then
        groups="env/${env}/auth/trino-groups.txt"
    fi

    if [ -r env/$env/auth/trino-rules.json ]; then
        rules="env/${env}/auth/trino-rules.json"
    fi

    echo " #  Creating trino groups config from $groups"
    ( cp $groups trino/base/ )
    echo " #  Creating trino rules config from $rules"
    ( cp $rules trino/base/ )

    echo " #  Creating secrets './**/base/secrets.env' "
    ( echo "$mysql_secrets" | envsubst > mysql-server/base/secrets.env )
    ( echo "$pgsql_secrets" | envsubst > postgresdb/base/secrets.env )
    ( echo "$hive_secrets" | envsubst > hive-metastore/base/secrets.env )
    ( echo "$trino_secrets" | envsubst > trino/base/secrets.env )

    if [ -n "$TRINO_DOMAINNAME" ]; then 
        echo " #  Creating ingress config"
        ( cat trino/resources/istio/base/params.env.template | envsubst > trino/resources/istio/base/params.env )
        ( cat trino/resources/nginx/base/params.env.template | envsubst > trino/resources/nginx/base/params.env )
    fi

    if [[ -z "$TRINO_PASSWORD_FILE" && -r "env/${env}/auth/password.db" ]]; then
        TRINO_PASSWORD_FILE="env/${env}/auth/password.db"
    fi

    if [ -n "$TRINO_PASSWORD_FILE" ]; then
        echo " #  Copying password db from '$TRINO_PASSWORD_FILE"
        ( cp "$TRINO_PASSWORD_FILE" trino/base/password.db )
    fi

    if [[ -n "$TRINO_USER" && -n "$TRINO_PASSWORD" ]]; then
        echo " #  Setting trino admin user in the password.db"
        set_user_passwd "$TRINO_USER"
    elif [[ ! -e trino/base/password.db ]]; then
        echo ""
        echo "# WARNING! 'password.db' is missing from 'trino/base'! "
        echo "# Be sure to create a trino account via -P before applying/installing manifests."
    fi
fi

echo "
#  Environment configuration:"
echo "
export S3_ENDPOINT=\"$S3_ENDPOINT\"
export S3_ACCESS_KEY=\"$S3_ACCESS_KEY\"
export S3_SECRET_KEY=\"$S3_SECRET_KEY\"
export TRINO_DBUSER=\"$TRINO_DBUSER\"
export TRINO_DBPASSWORD=\"$TRINO_DBPASSWORD\"
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
            echo "$PNAME Error in 'kustomize build $ol'" >&2
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
