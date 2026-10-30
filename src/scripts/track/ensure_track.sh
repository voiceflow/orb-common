#!/bin/bash

# Expected env vars
echo "${COMPONENT?}"
echo "${BUCKET?}"
echo "${SOURCE_BRANCH?}"

TRACK="tracks/${COMPONENT}/${CIRCLE_BRANCH:?}"
# Only seed the track when it is definitely missing; any other error (throttling, expired credentials)
# must not overwrite an existing track with the source branch's
if HEAD_OUTPUT=$(aws s3api head-object --bucket "${BUCKET}" --key "${TRACK}" 2>&1); then
  echo "Track ${TRACK} already exists"
elif [[ "${HEAD_OUTPUT}" == *"Not Found"* || "${HEAD_OUTPUT}" == *"404"* ]]; then
  aws s3 cp "s3://${BUCKET}/tracks/${COMPONENT}/${SOURCE_BRANCH}" "s3://${BUCKET}/${TRACK}"
else
  echo "Failed to check for track ${TRACK}: ${HEAD_OUTPUT}" >&2
  exit 1
fi
