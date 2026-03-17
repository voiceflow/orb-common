#!/bin/bash

# Expected env vars
echo "STOP=${STOP?}"
echo "COMPONENT=${COMPONENT?}"
echo "BUCKET=${BUCKET?}"
echo "FORCE_CREATE=${FORCE_CREATE?}"

BRANCH_NAME="$CIRCLE_BRANCH"
if [[ -z "$CIRCLE_BRANCH" && -n "$CIRCLE_TAG" ]]; then
  BRANCH_NAME="master"
fi

TRACK="tracks/$COMPONENT/$BRANCH_NAME"
echo "$TRACK"
set +e
aws s3 cp "s3://$BUCKET/$TRACK" "/tmp/$TRACK"
SEARCH_TRACK_RESULT=$?
set -e

# Store the result on a file in tmp folder to use in future steps
if [[ $SEARCH_TRACK_RESULT -eq 0 || "$CIRCLE_BRANCH" =~ ^gtmq_ || $FORCE_CREATE -eq 1 ]]; then
  cat <<-EOF >/tmp/TRACK_STATUS
export TRACK_EXISTS="true"
export TRACK="${TRACK}"
EOF

else
  echo 'export TRACK_EXISTS="false"' >/tmp/TRACK_STATUS # Track does not exist
  if ((STOP)); then
    curl --request POST \
      --url "https://circleci.com/api/v2/workflow/$CIRCLE_WORKFLOW_ID/cancel" \
      --header "Circle-Token: ${CIRCLECI_API_TOKEN}"
  fi
fi
