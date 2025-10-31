#!/usr/bin/env bash
#
# java entrypoint
set -ex

CMD=(java -jar jmx_prometheus_standalone-${APP_VERSION}.jar)

exec /usr/bin/tini -s -- "${CMD[@]}" "$@"
