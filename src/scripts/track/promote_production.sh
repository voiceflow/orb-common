#!/bin/bash
set -eE

BUCKET="com.voiceflow.ci.assets"

# Full command trace is redirected to an artifact file instead of the console,
# so the main log stays readable. Published as the "promote-production-logs"
# CircleCI artifact after the run.
LOG_DIR="/tmp/promote-production-logs"
mkdir -p "$LOG_DIR"
exec {trace_fd}>"${LOG_DIR}/promote-production.trace.log"
export BASH_XTRACEFD="$trace_fd"
set -x

CURRENT_PHASE="startup"

on_error() {
  local exit_code=$?
  cat <<EOF

================================================================================
  TAG IMAGES FAILED (exit ${exit_code}) during: ${CURRENT_PHASE}
================================================================================

  This is a real failure in the image-tagging/promotion step (unlike the
  master-guard check that runs before it). Full command trace is in the
  "promote-production-logs" CircleCI artifact:

      ${LOG_DIR}/promote-production.trace.log

================================================================================

EOF
}
trap on_error ERR

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
    yq -r ".[\"$COMPONENT\"].image.tag" "${TRACK_PATH_ABSOLUTE}"
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

echo "==> Fetching master tracks for ${#COMPONENT_NAMES[@]} component(s)..."
CURRENT_PHASE="fetch master tracks"
get_master_tracks "${TMP_DIR}" "${COMPONENT_NAMES[@]}"

echo "==> Tagging images and updating production tracks..."
for INDEX in "${!COMPONENT_NAMES[@]}"; do
  NAME="${COMPONENT_NAMES[$INDEX]}"
  echo "  - ${NAME}"

  CURRENT_PHASE="parse tag for ${NAME}"
  TAG="$(parse_tag "$TMP_DIR" "${NAME}")"

  CURRENT_PHASE="tag image ${NAME}:${TAG}"
  add_production_tags "${NAME}" "${TAG}"

  CURRENT_PHASE="copy track for ${NAME}"
  copy_track "${TMP_DIR}" "${NAME}"
done

echo "==> Done. Promoted ${#COMPONENT_NAMES[@]} component(s) to production."
