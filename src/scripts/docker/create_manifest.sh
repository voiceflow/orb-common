#!/bin/bash

# Input params
echo "IMAGE_REPO=${IMAGE_REPO?}"
echo "IMAGE_TAG_OVERRIDE=${IMAGE_TAG_OVERRIDE?}"
echo "COMPONENT=${COMPONENT?}"
echo "KMS_KEY=${KMS_KEY?}"

## Env Vars
IMAGE_TAG="${IMAGE_TAG_OVERRIDE:-"k8s-$CIRCLE_SHA1"}"
IMAGE_NAME="$IMAGE_REPO:$IMAGE_TAG"

echo "IMAGE_TAG=${IMAGE_TAG}"
echo "IMAGE_NAME=${IMAGE_NAME}"

check_track_exist() {
  # Load TRACK_EXISTS variable from file previously stored in the tmp folder
  # shellcheck disable=SC1091
  source "/tmp/TRACK_STATUS"

  if [[ "$TRACK_EXISTS" != "true" && "$CIRCLE_BRANCH" =~ "^gtmq_" ]]; then
    echo "Track does not exist! avoiding update!"
    exit 0
  fi
}

## Functions
getDigestRef() {
  ARCH="${1}"
  JQ=$(
    cat <<EOF
    .manifests
      | map(
        select(.annotations["vnd.docker.reference.type"] != "attestation-manifest")
        | \$image_repo + "@" + .digest
      )[] // ""
EOF
  )
  docker buildx imagetools inspect --raw "${IMAGE_NAME}${ARCH:+-${ARCH}}" \
    | jq -e -r --arg image_repo "${IMAGE_REPO}" "$JQ"
}

create_and_sign() {
  ARM64_DIGEST_REF=$(getDigestRef arm64)
  AMD64_DIGEST_REF=$(getDigestRef amd64)

  DIGESTS=()

  if [[ -n "$ARM64_DIGEST_REF" ]]; then
    DIGESTS+=("${ARM64_DIGEST_REF}")
  fi

  if [[ -n "$AMD64_DIGEST_REF" ]]; then
    DIGESTS+=("${AMD64_DIGEST_REF}")
  fi

  if [[ -z "${#DIGESTS}" ]]; then
    echo "ERROR: no digests found"
    exit 1
  fi

  docker manifest create "${IMAGE_NAME}" "${DIGESTS[@]}" --amend
  IMAGE_DIGEST=$(docker manifest push "${IMAGE_NAME}")

  echo "Pushed ${IMAGE_NAME} with digest: ${IMAGE_DIGEST}"

  cosign sign --key "${KMS_KEY}" --tlog-upload=false "${IMAGE_REPO}@${IMAGE_DIGEST}"
}

add_additional_tags() {
  if [[ -z "$CIRCLE_BRANCH" && -n "$CIRCLE_TAG" ]]; then
    BRANCH_NAME="master"
  else
    BRANCH_NAME="${CIRCLE_BRANCH//[^[:alnum:]]/-}" # Change all non alphanumeric characters to -
  fi

  if [[ -z "$IMAGE_TAG_OVERRIDE" ]]; then
    crane tag "${IMAGE_NAME}" "latest-${BRANCH_NAME}"
    crane tag "${IMAGE_NAME}" "k8s-${BRANCH_NAME}-${CIRCLE_SHA1}"
  fi
}

update_track() {
  ### update the track
  BUCKET="com.voiceflow.ci.assets"
  TRACK="tracks/${COMPONENT}/${CIRCLE_BRANCH}"
  echo "TRACK: $TRACK"

  if ! aws s3 cp "s3://$BUCKET/$TRACK" "/tmp/$TRACK"; then
    echo "Track does not exist"
    exit 0
  fi

  aws s3 cp - "s3://$BUCKET/$TRACK" <<EOF
${COMPONENT}:
  image:
    tag: ${IMAGE_TAG}
    sha: ${IMAGE_DIGEST#sha256:}
EOF
}

## Start
check_track_exist

create_and_sign

add_additional_tags

update_track
