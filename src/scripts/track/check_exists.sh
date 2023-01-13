#!/bin/bash

# Expected env vars
echo "${STOP?}"
echo "${COMPONENT?}"
echo "${BUCKET?}"

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
if [[ $SEARCH_TRACK_RESULT -eq 0 ]]; then
    echo 'export TRACK_EXISTS="true"' > /tmp/TRACK_STATUS  # Track exists, skip following steps
else
    echo 'export TRACK_EXISTS="false"' > /tmp/TRACK_STATUS  # Track exists, skip following steps
    if (( STOP )); then
        curl --request POST \
            --url "https://circleci.com/api/v2/workflow/$CIRCLE_WORKFLOW_ID/cancel" \
            --header "Circle-Token: ${CIRCLECI_API_TOKEN}"
    fi
fi
