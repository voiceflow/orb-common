#!/bin/bash

# Expected env vars
echo "SEM_VER_OVERRIDE: $SEM_VER_OVERRIDE"
echo "IMAGE_TAG_OVERRIDE: $IMAGE_TAG_OVERRIDE"
echo "IMAGE_REPO: $IMAGE_REPO"
echo "PACKAGE: $PACKAGE"
echo "BUILD_CONTEXT: $BUILD_CONTEXT"
echo "DOCKERFILE: $DOCKERFILE"
echo "MONOREPO_DIRECTORY: $MONOREPO_DIRECTORY"
echo "INJECT_AWS_CREDENTIALS: $INJECT_AWS_CREDENTIALS"

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
    if [[ -n "$PACKAGE" ]]; then
        SEM_VER=$(git describe --abbrev=0 --tags --match "@voiceflow/$PACKAGE@*")
        SEM_VER="${SEM_VER##*@}"
    fi
elif [[ "$SEM_VER_OVERRIDE" != "" ]]; then
    SEM_VER=$SEM_VER_OVERRIDE
else
    SEM_VER=$CIRCLE_BRANCH-$CIRCLE_SHA1
fi

echo -e "Building with SEM_VER=$SEM_VER"

if [[ ! -f "$BUILD_CONTEXT/yarn.lock" && -f "yarn.lock" ]]; then
    echo "Copying yarn.lock file from root"
    cp yarn.lock "$BUILD_CONTEXT"/yarn.lock
fi

if [ -z "$MONOREPO_DIRECTORY" ]; then
    REGISTRY_ARG=(--build-arg NPM_TOKEN=//registry.npmjs.org/:_authToken="${NPM_TOKEN}")
else
    REGISTRY_ARG=(--network host --build-arg build_REGISTRY_URL=http://localhost:4873)
fi

if [[ -n "$PACKAGE" ]]; then
    PACKAGE_ARG=(--build-arg APP_NAME="$PACKAGE")
fi

if (( INJECT_AWS_CREDENTIALS )); then
    AWS_CREDENTIALS_ARG=(--build-arg AWS_REGION="${AWS_REGION}" --build-arg AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" --build-arg AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}")
fi

docker build \
    "${REGISTRY_ARG[@]}" \
    "${PACKAGE_ARG[@]}" \
    "${AWS_CREDENTIALS_ARG[@]}" \
    --build-arg build_BUILD_NUM="${CIRCLE_BUILD_NUM}" \
    --build-arg build_BUILD_URL="${CIRCLE_BUILD_URL}"	\
    --build-arg build_GITHUB_TOKEN="${GITHUB_TOKEN}" \
    --build-arg build_GIT_SHA="${CIRCLE_SHA1}" \
    --build-arg build_SEM_VER="${SEM_VER}" \
    -f "$BUILD_CONTEXT"/"$DOCKERFILE" \
    -t "$IMAGE_NAME" "$BUILD_CONTEXT"
