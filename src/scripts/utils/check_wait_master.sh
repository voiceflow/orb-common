#!/bin/bash

set -x

# Static
ORG="gh/voiceflow"
BRANCH="master"
REVISION="$CIRCLE_SHA1"
PROJECT="$CIRCLE_PROJECT_REPONAME"

list_pipelines() {
  ##
  # get paginated list of master pipelines for specified repo
  ##
  local PAGE_TOKEN
  PAGE_TOKEN="$1"
  PAGE_TOKEN="${PAGE_TOKEN:+&page-token=${PAGE_TOKEN}}"
  curl --fail --silent --request GET \
    --url "https://circleci.com/api/v2/project/${ORG}/${PROJECT}/pipeline?branch=${BRANCH}${PAGE_TOKEN}" \
    --header "Circle-Token: ${CIRCLECI_API_TOKEN}"
}

get_pipeline() {
  ##
  # find master pipeline by long commit hash
  ##
  local LENGTH
  local PIPELINES
  local PAGE_TOKEN
  local MAX_PAGES
  local COUNT

  LENGTH=0
  COUNT=0
  MAX_PAGES=10

  while [[ "$LENGTH" == 0 && "$((COUNT++))" -lt "$MAX_PAGES" ]]; do
    PIPELINES=$(list_pipelines "${PAGE_TOKEN}")
    PAGE_TOKEN=$(<<<"$PIPELINES" jq -r '.next_page_token // empty' || echo "")

    LENGTH=$(<<<"$PIPELINES" jq --arg revision "${REVISION}" '.items | map(select(.vcs.revision == $revision and .state != "setup")) | length')
  done
  <<<"$PIPELINES" jq -r --arg revision "${REVISION}" '.items | map(select(.vcs.revision == $revision and .state != "setup")) | first | .id'
}

get_workflow() {
  ##
  # get non-setup workflow for pipeline
  ##
  local PIPELINE_ID
  PIPELINE_ID="$1"
  curl --fail --silent --request GET \
    --url "https://circleci.com/api/v2/pipeline/${PIPELINE_ID?}/workflow" \
    --header "Circle-Token: ${CIRCLECI_API_TOKEN}" \
    | jq -r '.items | map(select(.name != "setup")) | first'
}

MASTER_PIPELINE_ID=$(get_pipeline)

WORKFLOW=$(get_workflow "$MASTER_PIPELINE_ID")

COUNT=0
MAX_RETRY=10
INTERVAL=60
while [[ "$((COUNT++))" -lt "$MAX_RETRY" ]]; do
  case $(<<<"$WORKFLOW" jq -r '.status') in
    "running")
      echo "waiting for master workflow to finish"
      echo "sleep ${INTERVAL}s..."
      sleep "$INTERVAL"
      WORKFLOW=$(get_workflow "$MASTER_PIPELINE_ID")
      ;;

    "success")
      echo "Found master workflow successfully completed"
      break
      ;;

    *)
      echo "master workflow not successful. exiting..."
      exit 1
      ;;
  esac
done

echo "continuing"
