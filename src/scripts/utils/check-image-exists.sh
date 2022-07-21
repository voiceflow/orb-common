#!/bin/bash

IMAGE_TAG="k8s-$CIRCLE_SHA1"
IMAGE_NAME="$IMAGE_REPO:$IMAGE_TAG"
set +e
DOCKER_CLI_EXPERIMENTAL=enabled docker manifest inspect $IMAGE_NAME > /dev/null 2>&1
SEARCH_IMAGE_RESULT=$?
set -e

# Store the result on a file in tmp folder to use in future steps
if [[ $SEARCH_IMAGE_RESULT -eq 0 ]]; then
    echo 'export IMAGE_EXISTS="true"' > /tmp/IMAGE_STATUS  # Image exists, skip following steps
else
    echo 'export IMAGE_EXISTS="false"' > /tmp/IMAGE_STATUS  # Image exists, skip following steps
fi