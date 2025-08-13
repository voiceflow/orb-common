#!/bin/bash
set -eE

BUCKET="com.voiceflow.ci.assets"

echo "IMAGE_REGISTRY=${IMAGE_REGISTRY}"
echo "BUCKET=${BUCKET}"

< <(echo "$COMPONENT_NAMES") read -r -a COMPONENT_NAMES
echo "COMPONENT_NAMES: ${COMPONENT_NAMES[*]}"

TMP_DIR="$(mktemp -d)"

get_master_tracks() {
  local DIR
  local TRACK_PATH

  DIR="${1?}"
  shift 1

  echo "Fetching tracks to ${DIR}..."

  for COMPONENT in "$@"; do
    TRACK_PATH="tracks/${COMPONENT}/master"

    echo "  $COMPONENT..."

    mkdir -p "$(dirname "${DIR}/${TRACK_PATH}")"

    aws s3 cp --no-progress "s3://${BUCKET}/${TRACK_PATH}" "${DIR}/${TRACK_PATH}"
  done
}

parse_tag() {
  local DIR
  local COMPONENT
  local TRACK_PATH_ABSOLUTE

  DIR="${1?}"
  COMPONENT="${2?}"

  TRACK_PATH_ABSOLUTE="${DIR}/tracks/${COMPONENT}/master"

  if [[ "${COMPONENT}" == "database-cli" ]]; then
    # The full contents of database-cli track is the image tag
    cat "${TRACK_PATH_ABSOLUTE}"
  else
    yq ".[\"$COMPONENT\"].image.tag" "${TRACK_PATH_ABSOLUTE}"
  fi
}

add_production_tags() {
  local SERVICE
  local IMAGE_TAG
  local IMAGE_NAME

  SERVICE="${1?}"
  IMAGE_TAG="${2?}"

  IMAGE_NAME="${IMAGE_REGISTRY}/${SERVICE}:${IMAGE_TAG}"

  crane tag "${IMAGE_NAME}" "latest-production"

  if [[ "$SERVICE" = "database-cli" ]]; then
    crane tag "${IMAGE_NAME}" "latest"
  fi
}

copy_track() {
  local DIR
  local COMPONENT
  local MASTER_TRACK
  local PRODUCTION_TRACK

  DIR="${1?}"
  COMPONENT="${2?}"

  ### update the track
  MASTER_TRACK="${DIR}/tracks/${COMPONENT}/master"
  PRODUCTION_TRACK="tracks/${COMPONENT}/production"
  echo "Copying ${COMPONENT} master track from ${DIR} to production..."
  aws s3 cp --no-progress "${MASTER_TRACK}" "s3://${BUCKET}/${PRODUCTION_TRACK}"
}

get_master_tracks "${TMP_DIR}" "${COMPONENT_NAMES[@]}"

echo "Adding production tag and updating tracks for..."

for INDEX in "${!COMPONENT_NAMES[@]}"; do
  NAME="${COMPONENT_NAMES[$INDEX]}"
  TAG="$(parse_tag "$TMP_DIR" "${NAME}")"

  add_production_tags "${NAME}" "${TAG}"
  copy_track "${TMP_DIR}" "${NAME}"
done
