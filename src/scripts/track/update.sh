#!/bin/bash

# Load IMAGE_EXISTS variable from file previously stored in the tmp folder
source "/tmp/IMAGE_STATUS"
# Load TRACK_EXISTS variable from file previously stored in the tmp folder
source "/tmp/TRACK_STATUS"

BRANCH_NAME=$CIRCLE_BRANCH
if [[ -z "$CIRCLE_BRANCH" && ! -z "$CIRCLE_TAG" ]]; then
    BRANCH_NAME="master"
fi

if [[ $TRACK_EXISTS == "true" ]]; then
    if [[ "$IMAGE_TAG_OVERRIDE" == "" ]]; then
    IMAGE_TAG="k8s-$CIRCLE_SHA1"
    else
    IMAGE_TAG="$IMAGE_TAG_OVERRIDE"
    fi

    IMAGE_NAME="$IMAGE_REPO:$IMAGE_TAG"
    # Get the tag that is running right now
    if [[ "$CIRCLE_BRANCH" == "master" || "$CIRCLE_BRANCH" == "production" ]]; then
        # Update the tags
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

    if [ -z "$LOCAL_REGISTRY" ]; then
        REGISTRY_ARG="--build-arg NPM_TOKEN=//registry.npmjs.org/:_authToken=${NPM_TOKEN}"
    else
        REGISTRY_ARG="--network host --build-arg build_REGISTRY_URL=http://localhost:4873"
    fi

    if [[ $IMAGE_EXISTS == "false" || "$CIRCLE_BRANCH" == "master" || "$CIRCLE_BRANCH" == "production" ]]; then
    # Build Docker Image
    echo "Image not found, building..."
    read -r -d '' BUILD_COMMAND << EOF
    docker build \
        --build-arg build_BUILD_NUM=${CIRCLE_BUILD_NUM} \
        --build-arg build_GITHUB_TOKEN=${GITHUB_TOKEN} \
        --build-arg build_BUILD_URL=${CIRCLE_BUILD_URL} \
        --build-arg build_GIT_SHA=${CIRCLE_SHA1} \
        --build-arg build_SEM_VER=${SEM_VER} \
        $REGISTRY_ARG \
        $BUILD_ARGS \
        -f ${BUILD_CONTEXT}/${DOCKERFILE} \
        -t $IMAGE_NAME ${BUILD_CONTEXT}
    EOF
    /bin/bash -c "$BUILD_COMMAND"
    docker push $IMAGE_NAME

    # Signing Docker Image
    cosign sign --key $KMS_KEY $IMAGE_NAME

    # if a tag is set, do not push to latest-$BRANCH_NAME
    if [[ "$IMAGE_TAG_OVERRIDE" == "" ]]; then
        # Change all non alphanumeric characters to -
        BRANCH_NAME=$(echo $CIRCLE_BRANCH | sed 's/[^a-zA-Z0-9]/-/g')
        if [[ -z "$CIRCLE_BRANCH" && ! -z "$CIRCLE_TAG" ]]; then
        BRANCH_NAME="master"
        fi

        docker tag $IMAGE_NAME $IMAGE_REPO:latest-$BRANCH_NAME
        docker push $IMAGE_REPO:latest-$BRANCH_NAME

        # Signing Docker Image
        cosign sign --key $KMS_KEY $IMAGE_REPO:latest-$BRANCH_NAME
    fi
    fi

    # Pull the image to get the sha is needed.
    # If the image has been built, the following command will not pull the image because it exists locally
    TMPFILE=$(mktemp)
    docker pull $IMAGE_NAME | tee -a "$TMPFILE"
    # Get image SHA
    IMAGE_SHA=$(awk '/Digest: / {print $2}' "$TMPFILE")
    # Remove the sha256: string
    IMAGE_SHA=$(echo $IMAGE_SHA | sed 's/sha256://')
    rm "$TMPFILE"

    # update the track
    TRACK="tracks/${COMPONENT}/$CIRCLE_BRANCH"
    echo $TRACK
    pip3 install yq
    # the file /tmp/$TRACK is downloaded in the check_track_exists step
    yq -y -i --arg tag "${IMAGE_TAG}" ".\"${COMPONENT}\".image.tag=\$tag" /tmp/$TRACK
    yq -y -i --arg sha "${IMAGE_SHA}" ".\"${COMPONENT}\".image.sha=\$sha" /tmp/$TRACK
    aws s3 cp /tmp/$TRACK s3://${BUCKET}/$TRACK

else
    echo "Track does not exist! avoiding update!"
fi