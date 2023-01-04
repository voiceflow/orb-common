#!/bin/bash

if [[ "$IMAGE_TAG_OVERRIDE" == "" ]]; then
    IMAGE_TAG="k8s-$CIRCLE_SHA1"
else
    IMAGE_TAG="$IMAGE_TAG_OVERRIDE"
fi
IMAGE_NAME="$IMAGE_REPO:$IMAGE_TAG"

echo "Pushing $IMAGE_NAME"
docker push "$IMAGE_NAME"

# Signing Docker Image
cosign sign --key "$KMS_KEY" "$IMAGE_NAME"

# if a tag is set, do not push to latest-$BRANCH_NAME
if [[ "$IMAGE_TAG_OVERRIDE" == "" ]]; then
    if [[ -z "$CIRCLE_BRANCH" && -n "$CIRCLE_TAG" ]]; then
        BRANCH_NAME="master"
    else
        BRANCH_NAME="${CIRCLE_BRANCH//[^[:alnum:]]/-}"
    fi
    docker tag "$IMAGE_NAME" "$IMAGE_REPO":latest-"$BRANCH_NAME"
    docker push "$IMAGE_REPO":latest-"$BRANCH_NAME"

    # Signing Docker Image
    cosign sign --key "$KMS_KEY" "$IMAGE_REPO":latest-"$BRANCH_NAME"

    # To not to have untagged images
    docker tag "$IMAGE_NAME" "$IMAGE_REPO":k8s-"$BRANCH_NAME"-"$CIRCLE_SHA1"
    docker push "$IMAGE_REPO":k8s-"$BRANCH_NAME"-"$CIRCLE_SHA1"
    cosign sign --key "$KMS_KEY" "$IMAGE_REPO":k8s-"$BRANCH_NAME"-"$CIRCLE_SHA1"
fi