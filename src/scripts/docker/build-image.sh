#!/bin/bash

if [[ "$IMAGE_TAG_OVERRIDE" == "" ]]; then
    IMAGE_TAG="k8s-$CIRCLE_SHA1"
else
    IMAGE_TAG="$IMAGE_TAG_OVERRIDE"
fi
IMAGE_NAME="$IMAGE_REPO:$IMAGE_TAG"
# Semantic release from the current tags
if [[ "$CIRCLE_BRANCH" == "master" || "$CIRCLE_BRANCH" == "production" ]]; then
    # Update the new tags
    git fetch --tags
    SEM_VER=$(git describe --abbrev=0 --tags)
    if [[ ! -z "$PACKAGE" ]]; then
    SEM_VER=$(git describe --abbrev=0 --tags --match "@voiceflow/$PACKAGE@*" $CIRCLE_SHA1)
    SEM_VER=$(echo ${SEM_VER##*@})
    fi
else
    SEM_VER=$CIRCLE_BRANCH-$CIRCLE_SHA1
fi
echo -e "Building with SEM_VER=$SEM_VER"

if [ -z "$MONOREPO_DIRECTORY" ]; then
    REGISTRY_ARG="--build-arg NPM_TOKEN=//registry.npmjs.org/:_authToken=${NPM_TOKEN}"
else
    REGISTRY_ARG="--network host --build-arg build_REGISTRY_URL=http://localhost:4873"
fi

docker build \
    $REGISTRY_ARG \
    --build-arg build_BUILD_NUM=${CIRCLE_BUILD_NUM} \
    --build-arg build_BUILD_URL=${CIRCLE_BUILD_URL}	\
    --build-arg build_GITHUB_TOKEN=${GITHUB_TOKEN} \
    --build-arg build_GIT_SHA=${CIRCLE_SHA1} \
    --build-arg build_SEM_VER=${SEM_VER} \
    -f ${BUILD_CONTEXT}/${DOCKERFILE} \
    -t $IMAGE_NAME ${BUILD_CONTEXT}