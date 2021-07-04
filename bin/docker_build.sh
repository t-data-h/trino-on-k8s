#!/usr/bin/env bash
#
tagv="$1"
pvtrepo="${DOCKER_REPOSITORY}"

if [ -z "$tagv" ]; then
    echo "Usage: $0 <tag> "
    echo "Example: $0 tarland/hive-metastore:3.0.0"
    echo " set DOCKER_REPOSITORY to configure a private repo."
    exit 1
fi

( docker build --network=host --rm --tag $tagv . )

if [ -n "$pvtrepo" ]; then
    docker tag $tagv ${pvtrepo}/${tagv}
    docker push ${pvtrepo}/${tagv}
fi

exit $?