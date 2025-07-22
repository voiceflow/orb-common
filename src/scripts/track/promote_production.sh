#!/bin/bash

echo "COMPONENT_NAMES: ${COMPONENT_NAMES[*]}"

IMAGE_TAG="latest-master"
< <(echo "$COMPONENT_NAMES") read -r -a COMPONENT_NAMES

RESULT=0
DIGESTS=()
DEBUG_LOG_FILE="/tmp/promote-production.err"

get_digest() {
  local SERVICE
  local IMAGE_NAME
  local DIGEST

  SERVICE="${1?}"
  IMAGE_NAME="${IMAGE_REGISTRY}/${SERVICE}:${IMAGE_TAG}"
  printf "Check existence of %s..." "${IMAGE_NAME}" >&2
  DIGEST=$(crane digest "${IMAGE_NAME}" 2>&3)
  RESULT="$?"
  if ((RESULT)); then
    printf "fail\n" >&2
    return 1
  else
    printf "success\n" >&2
    echo "$DIGEST"
  fi
}

check_exists() {
  local NAME
  local DIGEST

  DIGESTS=()

  exec 3<>"${DEBUG_LOG_FILE?}"

  set +e
  for i in "${!COMPONENT_NAMES[@]}"; do
    NAME="${COMPONENT_NAMES[$i]}"
    DIGEST=$(get_digest "${NAME}")
    RESULT=$((RESULT + $?))
    DIGESTS+=("$DIGEST")
  done
  set -e

  exec 3>&-

  if ((RESULT)); then
    echo "ERROR: Failed to find all image tags" >&2
    cat "${DEBUG_LOG_FILE?}"
    exit 1
  fi
}

add_production_tags() {
  local SERVICE
  local IMAGE_NAME

  SERVICE="${1?}"
  IMAGE_NAME="${IMAGE_REGISTRY}/${SERVICE}:${IMAGE_TAG}"

  crane tag "${IMAGE_NAME}" "latest-production"
  crane tag "${IMAGE_NAME}" "k8s-production-${CIRCLE_SHA1}"

  if [[ "$SERVICE" = "database-cli" ]]; then
    crane tag "${IMAGE_NAME}" "latest"
  fi
}

update_track() {
  local COMPONENT
  local IMAGE_DIGEST
  local TRACK_PATH
  local BUCKET
  local TRACK
  BUCKET="com.voiceflow.ci.assets"

  COMPONENT="${1?}"
  IMAGE_DIGEST="${2?}"
  TRACK="${CIRCLE_BRANCH}"

  if [[ -z "${CIRCLE_BRANCH}" && -n "${CIRCLE_TAG}" ]]; then
    TRACK="production"
  fi

  TRACK_PATH="tracks/${COMPONENT}/${TRACK}"

  ### update the track
  echo "TRACK_PATH: ${TRACK_PATH}"

  mkdir -p "$(dirname "/tmp/${TRACK_PATH}")"

  if [[ "$COMPONENT" = "database-cli" ]]; then
    echo "New version published: ${IMAGE_TAG}"
    echo "${IMAGE_TAG}" >"/tmp/${TRACK_PATH}"
  else
    cat <<EOF >"/tmp/${TRACK_PATH}"
${COMPONENT}:
  image:
    tag: ${IMAGE_TAG}
    sha: ${IMAGE_DIGEST#sha256:}
EOF
  fi
  aws s3 cp "/tmp/${TRACK_PATH}" "s3://${BUCKET}/${TRACK_PATH}"
}

check_exists

echo "All tags exist"
echo "Adding production tag and updating tracks for..."

for INDEX in "${!COMPONENT_NAMES[@]}"; do
  NAME="${COMPONENT_NAMES[$INDEX]}"
  DIGEST="${DIGESTS[$INDEX]}"

  echo "${NAME}:${DIGEST}"
  add_production_tags "${NAME}"
  update_track "${NAME}" "${DIGEST}"
done
