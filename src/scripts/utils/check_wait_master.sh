#!/bin/bash

# Static
ORG="gh/voiceflow"
BRANCH="master"
REVISION="$CIRCLE_SHA1"
PROJECT="$CIRCLE_PROJECT_REPONAME"
APP_ORG="github/${ORG#gh/}"   # gh/voiceflow -> github/voiceflow (app.circleci.com URL segment)

MAX_RETRY=25
INTERVAL=60

# Full command trace (including the raw CircleCI API payloads) is redirected to
# an artifact file instead of the console, so the main log stays readable. It is
# published as the "promote-production-logs" CircleCI artifact after the run.
LOG_DIR="/tmp/promote-production-logs"
mkdir -p "$LOG_DIR"
exec {trace_fd}>"${LOG_DIR}/check-wait-master.trace.log"
export BASH_XTRACEFD="$trace_fd"
set -x

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
  local LENGTH PIPELINES PAGE_TOKEN MAX_PAGES COUNT
  LENGTH=0
  COUNT=0
  MAX_PAGES=10

  while [[ "$LENGTH" == 0 && "$((COUNT++))" -lt "$MAX_PAGES" ]]; do
    PIPELINES=$(list_pipelines "${PAGE_TOKEN}")
    PAGE_TOKEN=$(jq -r '.next_page_token // empty' <<<"$PIPELINES" || echo "")
    LENGTH=$(jq --arg revision "${REVISION}" '.items | map(select(.vcs.revision == $revision and .state != "setup")) | length' <<<"$PIPELINES")
  done
  jq -r --arg revision "${REVISION}" '.items | map(select(.vcs.revision == $revision and .state != "setup")) | first | .id' <<<"$PIPELINES"
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

workflow_url() {
  ##
  # build a clickable app.circleci.com URL for the master workflow from the
  # workflow JSON we already fetched
  ##
  local workflow_json pipeline_number workflow_id
  workflow_json="$1"
  pipeline_number="$(jq -r '.pipeline_number' <<<"$workflow_json")"
  workflow_id="$(jq -r '.id' <<<"$workflow_json")"
  echo "https://app.circleci.com/pipelines/${APP_ORG}/${PROJECT}/${pipeline_number}/workflows/${workflow_id}"
}

print_blocked_banner() {
  ##
  # explain that a non-successful master workflow blocked promotion on purpose
  ##
  local status url
  status="$1"
  url="$2"
  cat <<EOF

================================================================================
  PRODUCTION PROMOTION BLOCKED - THIS IS EXPECTED, NOT A BUG IN THIS JOB
================================================================================

  This job did its one job correctly: it stopped the promotion because the
  matching MASTER workflow for this commit is not green. No broken master image
  was promoted to production.

  >> Do NOT re-run this production job. It will keep failing until master is
     fixed - the production branch and this job are working as intended.

  >> Look at the MASTER workflow instead. That is where the real failure is:

       Master workflow status : ${status}
       Master workflow        : ${url}

  Once that master workflow is green, promotion for this commit succeeds
  automatically on the next production build. Nothing to fix here.

================================================================================

EOF
}

echo "Looking for the master workflow matching this commit (${REVISION})..."

MASTER_PIPELINE_ID=$(get_pipeline)
WORKFLOW=$(get_workflow "$MASTER_PIPELINE_ID")

# Persist the resolved pipeline id and workflow JSON to the artifact for debugging.
echo "$MASTER_PIPELINE_ID" > "${LOG_DIR}/master-pipeline-id.txt"
echo "$WORKFLOW" > "${LOG_DIR}/master-workflow.json"

MASTER_URL="$(workflow_url "$WORKFLOW")"
echo "Found master workflow: ${MASTER_URL}"

COUNT=0
while [[ "$((COUNT++))" -lt "$MAX_RETRY" ]]; do
  STATUS=$(jq -r '.status' <<<"$WORKFLOW")
  case "$STATUS" in
    "running")
      echo "Master workflow is still running. Waiting ${INTERVAL}s before re-checking [attempt ${COUNT}/${MAX_RETRY}]..."
      sleep "$INTERVAL"
      WORKFLOW=$(get_workflow "$MASTER_PIPELINE_ID")
      echo "$WORKFLOW" > "${LOG_DIR}/master-workflow.json"
      ;;

    "success")
      echo "Master workflow succeeded. Proceeding with production promotion."
      exit 0
      ;;

    *)
      echo "Master workflow finished with status: ${STATUS} (not a success)."
      print_blocked_banner "$STATUS" "$MASTER_URL"
      exit 1
      ;;
  esac
done

echo "Timed out after ${MAX_RETRY} checks (~$((MAX_RETRY * INTERVAL / 60)) min) waiting for the master workflow to finish."
print_blocked_banner "timed out (still running or stuck)" "$MASTER_URL"
exit 1
