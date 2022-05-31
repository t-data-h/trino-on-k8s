#!/usr/bin/env bash
#
tagv="$1"
repo="${2:-${DOCKER_REPOSITORY}}"


if [ -z "$tagv" ]; then
    echo "Usage: $0  <image:tag>  [repo]"
    echo "  where <image:tag> = 'project/image:tag' "
    echo "  or [repo]/image:tag if additonal string provided."
    echo ""
    echo " eg. $0 project/tagname:version  docker.io"
    echo " will build and tag as 'docker.io/project/tagname:version'"
    echo " DOCKER_REPOSITORY is honored as the repo, but the"
    echo " command-line option takes precedence."
    echo ""
    exit 1
fi

( docker build --network=host --rm --tag $tagv . )

if [ -n "$repo" ]; then
    echo " -> External repo set to '$repo'"
    ( docker tag $tagv ${repo}/${tagv} )
fi

exit $?