#!/bin/bash

# Expected env vars
echo "${COMPONENT?}"
echo "${BUCKET?}"
echo "${SOURCE_BRANCH?}"

TRACK="tracks/${COMPONENT}/${CIRCLE_BRANCH:?}"
if aws s3 ls "s3://${BUCKET}/${TRACK}" > /dev/null; then
  echo "Track ${TRACK} already exists"
else
  aws s3 cp "s3://${BUCKET}/tracks/${COMPONENT}/${SOURCE_BRANCH}" "s3://${BUCKET}/${TRACK}"
fi
