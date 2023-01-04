#!/bin/bash

# Expected env vars
echo SEM_VER_OVERRIDE
echo IMAGE_TAG_OVERRIDE
echo IMAGE_REPO
echo PACKAGE
echo BUILD_CONTEXT
echo DOCKERFILE

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
        SEM_VER=$(git describe --abbrev=0 --tags --match "@voiceflow/$PACKAGE@*")
        SEM_VER=$(echo ${SEM_VER##*@})
    fi
else
    SEM_VER=$CIRCLE_BRANCH-$CIRCLE_SHA1
fi

if [[ "$SEM_VER_OVERRIDE" != "" ]]; then
    SEM_VER=$SEM_VER_OVERRIDE
fi

if [[ ! -f "$BUILD_CONTEXT/yarn.lock" && -f "yarn.lock" ]]; then
    echo "Copying yarn.lock file from root"
    cp yarn.lock $BUILD_CONTEXT/yarn.lock
fi

echo -e "Building with SEM_VER=$SEM_VER"

if [ -z "$MONOREPO_DIRECTORY" ]; then
    REGISTRY_ARG="--build-arg NPM_TOKEN=//registry.npmjs.org/:_authToken=${NPM_TOKEN}"
else
    REGISTRY_ARG="--network host --build-arg build_REGISTRY_URL=http://localhost:4873"
fi

if [ -n "$PACKAGE"]; then
    PACKAGE_ARG="--build-arg APP_NAME=$PACKAGE"
fi

docker build \
    $REGISTRY_ARG \
    $ PACKAGE_ARG \
    --build-arg build_BUILD_NUM=${CIRCLE_BUILD_NUM} \
    --build-arg build_BUILD_URL=${CIRCLE_BUILD_URL}	\
    --build-arg build_GITHUB_TOKEN=${GITHUB_TOKEN} \
    --build-arg build_GIT_SHA=${CIRCLE_SHA1} \
    --build-arg build_SEM_VER=${SEM_VER} \
    -f $BUILD_CONTEXT/$DOCKERFILE \
    -t $IMAGE_NAME $BUILD_CONTEXT