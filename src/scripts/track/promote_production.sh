#!/bin/bash
set -eE

IMAGE_REGISTRY="legit.thing"
BUCKET="com.voiceflow.ci.assets"

DEBUG=1
DEBUG_LOG_FILE="/tmp/loggy"

< <(echo "$COMPONENT_NAMES") read -r -a COMPONENT_NAMES
echo "COMPONENT_NAMES: ${COMPONENT_NAMES[*]}"

if ((DEBUG)); then
  rm -f /tmp/loggy
  # set -x

  ##
  # ~/workspace/work/tools/oci-registry
  # dbuild --output type=image,push=true,registry.insecure=true,name=host.docker.internal:5002/creator-api:k8s-test
  ##

  IMAGE_REGISTRY="localhost:5000"
  ./configure-aws.sh

  exec 3<>"${DEBUG_LOG_FILE?}"
  awscli() {
    echo "$@" >&3
    aws --endpoint-url http://localhost:9000 "$@" >&2
  }

  for COMPONENT in "${COMPONENT_NAMES[@]}"; do
    printf "[debug] setting mocks for %s...\n" "${COMPONENT}" >&3
    printf "[debug]   creating track..." >&3
    TRACK_PATH="tracks/${COMPONENT}/master"

    awscli s3 cp - "s3://${BUCKET}/${TRACK_PATH}" <<EOF
$COMPONENT:
  image:
    tag: k8s-test
    sha: asdf23423
EOF
    echo "[debug]   done" >&3

    printf "[debug]   creating oci repo and image..." >&3

    docker buildx build \
      --builder buildy \
      --platform linux/arm64 \
      --output "type=image,push=true,registry.insecure=true,name=host.docker.internal:5000/$COMPONENT:k8s-test" \
      -f - . <<EOF
FROM alpine:3
RUN echo "$COMPONENT" >/tmp/whoami
EOF
    echo "[debug]   done" >&3
  done

  #   aws() {
  #     shift 2
  #     COMPONENT="${1#s3://"${BUCKET}"/tracks/}"
  #     COMPONENT="${COMPONENT%/master}"
  #     cat <<EOF >"${2?}"
  # $COMPONENT:
  #   image:
  #     tag: k8s-test
  #     sha: asdf23423
  # EOF
  #     echo "[aws] args: $*" >&3
  #   }
  # trap 'caller 1' ERR
  trap 'echo -e "\n$BASH_SOURCE:$LINENO: error: " ; cat "${DEBUG_LOG_FILE}"; caller 1 ; exec 3>&-' ERR
fi

TMP_DIR="$(mktemp -d)"

((DEBUG)) && echo "TMP_DIR=${TMP_DIR}"

get_master_tracks() {
  local DIR

  DIR="${1?}"
  shift 1

  printf "Fetching tracks to %s...\n" "${DIR}"

  for COMPONENT in "$@"; do
    TRACK_PATH="tracks/${COMPONENT}/master"

    printf "  %s..." "$COMPONENT"

    mkdir -p "$(dirname "${DIR}/${TRACK_PATH}")"

    awscli s3 cp "s3://${BUCKET}/${TRACK_PATH}" "${DIR}/${TRACK_PATH}" >&3
    printf "done\n"
  done
  echo "complete"
}

parse_tag() {
  local DIR
  local COMPONENT
  local TRACK_PATH_ABSOLUTE

  DIR="${1?}"
  shift 1
  COMPONENT="${1?}"

  TRACK_PATH_ABSOLUTE="${DIR}/tracks/${COMPONENT}/master"

  if [[ "${COMPONENT}" == "database-cli" ]]; then
    cat "${TRACK_PATH_ABSOLUTE}"
  else
    yq ".[\"$NAME\"].image.tag" "${TRACK_PATH_ABSOLUTE}"
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
  echo "testcontainers for aws/s3"
  printf "Copying %s master track from %s to production..." "${COMPONENT}" "${DIR}"
  awscli s3 cp "${MASTER_TRACK}" "s3://${BUCKET}/${PRODUCTION_TRACK}"
  echo "done"
}

get_master_tracks "${TMP_DIR}" "${COMPONENT_NAMES[@]}" >&2

echo "Adding production tag and updating tracks for..."

for INDEX in "${!COMPONENT_NAMES[@]}"; do
  NAME="${COMPONENT_NAMES[$INDEX]}"
  TAG="$(parse_tag "$TMP_DIR" "${NAME}")"

  echo "  ${NAME}:${TAG}"
  add_production_tags "${NAME}" "${TAG}" >&2
  copy_track "${TMP_DIR}" "${NAME}" >&2
done
exec 3>&-
