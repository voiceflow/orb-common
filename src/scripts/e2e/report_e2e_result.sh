#!/bin/bash

if [[ -z "$COMMENT_ID" ]]; then
  echo "No PR comment to update"
  exit 0
fi

WORKFLOW_URL="https://app.circleci.com/pipelines/workflows/${CIRCLE_WORKFLOW_ID:?}"

FAILED_JOBS=$(
  curl --silent --show-error --fail --retry 3 \
    --header "Circle-Token: ${CIRCLECI_API_TOKEN:?}" \
    "https://circleci.com/api/v2/workflow/${CIRCLE_WORKFLOW_ID}/job" |
    jq -r '[.items[] | select(.status | IN("failed", "infrastructure_fail", "timedout", "canceled")) | "`\(.name)`"] | join(", ")'
)

if [[ -z "$FAILED_JOBS" ]]; then
  BODY="✅ e2e tests passed for \`${CIRCLE_SHA1:0:7}\`: ${WORKFLOW_URL}"
else
  BODY="❌ e2e tests failed for \`${CIRCLE_SHA1:0:7}\` (${FAILED_JOBS}): ${WORKFLOW_URL}"
fi
echo "$BODY"

curl --silent --show-error --fail --retry 3 --output /dev/null \
  --request PATCH "https://api.github.com/repos/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/issues/comments/${COMMENT_ID}" \
  --header "Authorization: Bearer ${GITHUB_TOKEN:?}" \
  --header "Accept: application/vnd.github+json" \
  --data "$(jq -n --arg body "$BODY" '{body: $body}')"
