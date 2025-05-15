#!/usr/bin/env bash
#
# Install nginx as the ingress controller via helm
#
PNAME=${0##*\/}
VERSION="v25.05"
bindir=$(dirname "$(readlink -f "$0")")
name="ingress-nginx"
chart_version="4.11.4"

action="$1"
ip="${2}"
ns="${3:-ingress-nginx}"

NGINX_CHART_REPO="${NGINX_CHART_REPO:-https://kubernetes.github.io/ingress-nginx}"
NGINX_CHART_VERSION="${NGINX_CHART_VERSION:-${chart_version}}"

conf="
controller:
  hostNetwork: true
  service:
    type: LoadBalancer
    loadBalancerIP: $ip
  nodeSelector:
    node-role.kubernetes.io/worker: ""

defaultBackend:
  nodeSelector:
    node-role.kubernetes.io/worker: ""
"

# ----------------------------------------

if [[ "$action" == "delete" || "$action" == "uninstall" ]]; then
    echo "Deleting $name"
    ( helm uninstall "$name" --namespace $ns )
    exit $?
fi

if [[ -z "$action" || -z "$ip" ]]; then
    echo "Usage: $PNAME [install|delete] [elb_ip] <namespace=$ns>"
    exit 0
fi

if [ "$action" != "install" ]; then
    echo "Unknown action, showing install commands as dryrun"
    echo "
        helm repo add "${name}" "${NGINX_CHART_REPO}"
        helm upgrade --install --wait "${name}" \\
          --version ${NGINX_CHART_VERSION} \\
          --values /tmp/nginx-values.yaml \\
          ingress-nginx/ingress-nginx \\
          --create-namespace \\
          --namespace $ns
    "
    exit 0
fi

# ----------

rt=0
conftmp=$(mktemp /tmp/nginx-values-XXXXXX.yaml)

echo "$conf" > $conftmp

args=("--version" "${NGINX_CHART_VERSION}"
      "--values" "$conftmp")

if ! helm repo list | grep "${name}" >/dev/null 2>&1 ; then
	helm repo add "${name}" "${NGINX_CHART_REPO}"
fi

if ! helm status "${name}" >/dev/null 2>&1; then
	helm repo update
	helm upgrade --install --wait "${name}" \
      "${args[@]}" \
      ingress-nginx/ingress-nginx \
      --create-namespace \
      --namespace $ns
    rt=$?
fi

unlink $conftmp

exit $rt
