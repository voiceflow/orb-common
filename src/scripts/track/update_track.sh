#!/bin/bash
# shellcheck disable=SC2086

# Expected env vars
echo "IMAGE_REPO: ${IMAGE_REPO?}"
echo "IMAGE_TAG_OVERRIDE: ${IMAGE_TAG_OVERRIDE?}"
echo "KMS_KEY: ${KMS_KEY?}"
echo "PACKAGE: ${PACKAGE?}"
echo "BUILD_CONTEXT: ${BUILD_CONTEXT?}"
echo "COMPONENT: ${COMPONENT?}"
echo "BUCKET: ${BUCKET?}"
echo "LOCAL_REGISTRY: ${LOCAL_REGISTRY?}"
echo "DOCKERFILE: ${DOCKERFILE?}"
echo "INJECT_AWS_CREDENTIALS: ${INJECT_AWS_CREDENTIALS?}"
echo "PLATFORM: ${PLATFORM?}"
echo "USE_BUILDKIT: ${USE_BUILDKIT?}"
echo "BUILDER_NAME: ${BUILDER_NAME-}"
echo "EXTRA_BUILD_ARGS: ${EXTRA_BUILD_ARGS[*]}"
echo "ENABLE_CACHE_TO: ${ENABLE_CACHE_TO:=0}"

# force string to array
read -r -a EXTRA_BUILD_ARGS <<< "$EXTRA_BUILD_ARGS"

# Load IMAGE_EXISTS variable from file previously stored in the tmp folder
# shellcheck disable=SC1091
source "/tmp/IMAGE_STATUS"
# Load TRACK_EXISTS variable from file previously stored in the tmp folder
# shellcheck disable=SC1091
source "/tmp/TRACK_STATUS"

if [[ "$TRACK_EXISTS" != "true" ]]; then
    echo "Track does not exist! avoiding update!"
    exit 0
fi

BRANCH_NAME="$CIRCLE_BRANCH"
if [[ -z "$CIRCLE_BRANCH" && -n "$CIRCLE_TAG" ]]; then
    BRANCH_NAME="master"
    CACHE_BRANCH_NAME="master"
else
    CACHE_BRANCH_NAME="${CIRCLE_BRANCH//[^[:alnum:]]/-}" # Change all non alphanumeric characters to -
fi

IMAGE_TAG="${IMAGE_TAG_OVERRIDE:-"k8s-$CIRCLE_SHA1"}"

IMAGE_NAME="$IMAGE_REPO:$IMAGE_TAG"
# Get the tag that is running right now
if [[ "$CIRCLE_BRANCH" == "master" || "$CIRCLE_BRANCH" == "production" ]]; then
    # Update the tags
    git fetch --tags
    if [[ -n "$PACKAGE" ]]; then
        SEM_VER=$(git describe --abbrev=0 --tags --match "@voiceflow/$PACKAGE@*")
        SEM_VER="${SEM_VER##*@}"
    else
        SEM_VER=$(git describe --abbrev=0 --tags)
    fi
else
    SEM_VER="$CIRCLE_BRANCH-$CIRCLE_SHA1"
fi

# In a monorepo we need to copy the yarn lock file from root
if [[ ! -f "$BUILD_CONTEXT/yarn.lock" && -f "yarn.lock" ]]; then
    echo "Copying yarn.lock file from root"
    cp yarn.lock "$BUILD_CONTEXT/yarn.lock"
fi

echo -e "Building with SEM_VER=$SEM_VER"

if [[ $IMAGE_EXISTS == "false" || "$CIRCLE_BRANCH" == "master" || "$CIRCLE_BRANCH" == "production" ]]; then
    # Build Docker Image
    echo "Image not found, building..."

    if (( LOCAL_REGISTRY )); then
        REGISTRY_ARG=(--network host --build-arg build_REGISTRY_URL=http://localhost:4873)
    else
        REGISTRY_ARG=(--build-arg NPM_TOKEN=//registry.npmjs.org/:_authToken="${NPM_TOKEN}")
    fi

    if [[ -n "$PACKAGE" ]]; then
        PACKAGE_ARG=(--build-arg APP_NAME="$PACKAGE")
    fi

    if (( INJECT_AWS_CREDENTIALS )); then
        AWS_CREDENTIALS_ARG=(--build-arg AWS_REGION="${AWS_REGION}" --build-arg AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" --build-arg AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}")
    fi

    for arg in "${EXTRA_BUILD_ARGS[@]}" ; do
      BUILD_ARGS+=(--build-arg "${arg}")
    done

    BUILD_COMMAND="build"
    if (( USE_BUILDKIT )); then
        # NOTE: think of this as the CircleCI DLC key
        echo "BUILDER_NAME: ${BUILDER_NAME:=buildy-${CACHE_BRANCH_NAME-}}"

        BUILDER_ARGS=(--name "${BUILDER_NAME-}")
        docker buildx create --use --platform="$PLATFORM" \
          "${BUILDER_ARGS[@]}"
        docker buildx inspect --bootstrap
        BUILD_COMMAND="buildx build --load"
        NPM_TOKEN_SECRET=(--secret id=NPM_TOKEN)

        CACHE_FROM_ARG=(--cache-from "${IMAGE_REPO-}:cache-master")
        if [ "${CACHE_BRANCH_NAME}" != "master" ] ; then
          CACHE_FROM_ARG+=(--cache-from "${IMAGE_REPO-}:cache-${CACHE_BRANCH_NAME-}")
        fi

        if [[ "${ENABLE_CACHE_TO-}" -eq 1  && "${CACHE_BRANCH_NAME}" == "master" ]] ; then
          CACHE_TO_ARG=(--cache-to "mode=max,image-manifest=true,oci-mediatypes=true,type=registry,ref=${IMAGE_REPO-}:cache-${CACHE_BRANCH_NAME-}")
        fi

        BUILD_ARGS+=( "${CACHE_FROM_ARG[@]}" )
        BUILD_ARGS+=( "${CACHE_TO_ARG[@]}" )
    fi

    docker $BUILD_COMMAND \
        --build-arg build_BUILD_NUM="${CIRCLE_BUILD_NUM}" \
        --build-arg build_GITHUB_TOKEN="${GITHUB_TOKEN}" \
        --build-arg build_BUILD_URL="${CIRCLE_BUILD_URL}" \
        --build-arg build_GIT_SHA="${CIRCLE_SHA1}" \
        --build-arg build_SEM_VER="${SEM_VER}" \
        "${REGISTRY_ARG[@]}" \
        "${PACKAGE_ARG[@]}" \
        "${AWS_CREDENTIALS_ARG[@]}" \
        "${NPM_TOKEN_SECRET[@]}" \
        "${BUILD_ARGS[@]}" \
        --platform "$PLATFORM" \
        -f "$BUILD_CONTEXT/$DOCKERFILE" \
        -t "$IMAGE_NAME" "$BUILD_CONTEXT"
    echo "BUILD_ARGS: ${BUILD_ARGS[*]} $PLATFORM"
    docker push "$IMAGE_NAME"

    # Signing Docker Image
    cosign sign --key "$KMS_KEY" "$IMAGE_NAME"

    # if a tag is set, do not push to latest-$BRANCH_NAME
    if [[ "$IMAGE_TAG_OVERRIDE" == "" ]]; then
        if [[ -z "$CIRCLE_BRANCH" && -n "$CIRCLE_TAG" ]]; then
            BRANCH_NAME="master"
        else
            BRANCH_NAME="${CIRCLE_BRANCH//[^[:alnum:]]/-}" # Change all non alphanumeric characters to -
        fi

        docker tag "$IMAGE_NAME" "$IMAGE_REPO:latest-$BRANCH_NAME"
        docker push "$IMAGE_REPO:latest-$BRANCH_NAME"

        # Signing Docker Image
        cosign sign --key "$KMS_KEY" "$IMAGE_REPO:latest-$BRANCH_NAME"

        # To not to have untagged images
        docker tag "$IMAGE_NAME" "$IMAGE_REPO:k8s-$BRANCH_NAME-$CIRCLE_SHA1"
        docker push "$IMAGE_REPO:k8s-$BRANCH_NAME-$CIRCLE_SHA1"
        cosign sign --key "$KMS_KEY" "$IMAGE_REPO:k8s-$BRANCH_NAME-$CIRCLE_SHA1"
    fi
fi

# Pull the image to get the sha is needed.
# If the image has been built, the following command will not pull the image because it exists locally
TMPFILE="$(mktemp)"
docker pull "$IMAGE_NAME" | tee -a "$TMPFILE"
# Get image SHA
IMAGE_SHA=$(awk '/Digest: / {print $2}' "$TMPFILE")
# Remove the sha256: string
IMAGE_SHA="${IMAGE_SHA//sha256:/}"
rm "$TMPFILE"

# update the track
TRACK="tracks/$COMPONENT/$CIRCLE_BRANCH"
echo "TRACK: $TRACK"
pip3 install yq
# the file /tmp/$TRACK is downloaded in the check_track_exists step
yq -y -i --arg tag "${IMAGE_TAG}" ".\"$COMPONENT\".image.tag=\$tag" "/tmp/$TRACK"
yq -y -i --arg sha "${IMAGE_SHA}" ".\"$COMPONENT\".image.sha=\$sha" "/tmp/$TRACK"
aws s3 cp "/tmp/$TRACK" "s3://$BUCKET/$TRACK"
