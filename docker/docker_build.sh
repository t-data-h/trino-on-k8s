#!/usr/bin/env bash
#
tagv="$1"
repo="${2:-${DOCKER_REPOSITORY}}"


if [ -z "$tagv" ]; then
    echo "Usage: $0  <image:tag>  [repo]"
    echo "  where <tag> = 'project/tagname:version' "
    echo "  and  [repo] = will push the image."
    echo ""
    echo " eg. $0 project/tagname:version  docker.io"
    echo " will build and push 'docker.io/project/tagname:version'"
    echo " DOCKER_REPOSITORY can be set as the repo"
    echo ""
    exit 1
fi

( docker build --network=host --rm --tag $tagv . )

if [ -n "$repo" ]; then
    echo " -> External repo set to '$repo'"
    ( docker tag $tagv ${repo}/${tagv} )
    ( docker push ${repo}/${tagv} )
fi

exit $?