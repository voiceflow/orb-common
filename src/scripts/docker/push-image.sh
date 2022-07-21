#!/bin/bash

if [[ "$IMAGE_TAG_OVERRIDE" == "" ]]; then
    IMAGE_TAG="k8s-$CIRCLE_SHA1"
else
    IMAGE_TAG="$IMAGE_TAG_OVERRIDE"
fi
IMAGE_NAME="$IMAGE_REPO:$IMAGE_TAG"
docker push $IMAGE_NAME

# Signing Docker Image
cosign sign --key $KMS_KEY $IMAGE_NAME

# if a tag is set, do not push to latest-$BRANCH_NAME
if [[ "$IMAGE_TAG_OVERRIDE" == "" ]]; then
    BRANCH_NAME=$(echo $CIRCLE_BRANCH | sed 's/[^a-zA-Z0-9]/-/g')
    if [[ -z "$CIRCLE_BRANCH" && ! -z "$CIRCLE_TAG" ]]; then
    BRANCH_NAME="master"
    fi
    docker tag $IMAGE_NAME $IMAGE_REPO:latest-$BRANCH_NAME
    docker push $IMAGE_REPO:latest-$BRANCH_NAME

    # Signing Docker Image
    cosign sign --key $KMS_KEY $IMAGE_REPO:latest-$BRANCH_NAME
fi