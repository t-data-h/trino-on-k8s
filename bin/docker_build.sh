#!/usr/bin/env bash
#
tagv="$1"
repo="${2:-${DOCKER_REPOSITORY}}"


if [ -z "$tagv" ]; then
    echo "Usage: $0  <tag>  [repo]"
    echo "  where <tag> = 'project/tagname:version' "
    echo "  optional [repo] to tag and push the image"
    echo "       eg. 'repo/project/tagname:version'"
    echo "  or set DOCKER_REPOSITORY envvar as the repo"
    echo ""
    exit 1
fi

( docker build --network=host --rm --tag $tagv . )

if [ -n "$repo" ]; then
    echo " -> External repo set to $repo "
    ( docker tag $tagv ${repo}/${tagv} )
    ( docker push ${repo}/${tagv} )
fi

exit $?