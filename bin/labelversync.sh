#!/usr/bin/env bash
#
version="${1:-v$(date +'%02y.%02m.%02d')}"
shopt -s globstar

case "$version" in
-h|--help|'help')
    echo "Usage: $0 [version_tag]"
    echo "Sets the version label via kustomization.yaml files."
    echo "If no version is provided, the current date is used 'v%02y.%02m.%02d'" 
    exit 0
    ;;
*)
    ;;
esac

manifests=$(ls -1 **/base/kustomization.yaml)

for yaml in $manifests; do
    echo " >$yaml "
    sed -e 's/^[[:blank:]]*$/# __NEWLINE__#/' -i "${yaml}"
    yq ".labels.0.pairs.\"app.kubernetes.io/version\" = \"$version\"" -i "$yaml"; 
    sed -e 's/.*# __NEWLINE__#.*//' -i "${yaml}"
done

exit 0
