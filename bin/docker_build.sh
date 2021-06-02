#!/usr/bin/env bash
#
tagv="$1"
pvtrepo="${DOCKER_REPOSITORY}"


( docker build --rm --tag $tagv . )

if [ -n "$pvtrepo" ]; then
    docker tag $tagv ${pvtrepo}/${tagv}
    docker push ${pvtrepo}/${tagv}
fi

exit $?