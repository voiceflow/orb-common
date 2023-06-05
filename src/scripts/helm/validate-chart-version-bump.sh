#!/bin/bash -e

# Expected environment variables:
echo "CHARTS: ${CHARTS?}"

rc=0 # return code

for CHART in ${CHARTS?}; do
  echo "Checking if chart ${CHART} has been modified"
  LOCAL_CHART="$(helm show chart "$CHART/$CHART")"
  CHANNEL="$(yq --raw-output '.annotations."release-repository"' <<< "$LOCAL_CHART")"

  REPO="voiceflow-charts-s3-$CHANNEL"
  if [[ "$CHANNEL" == "public" ]]; then
    REPO="voiceflow-charts-s3"
  fi

  LOCAL_VERSION="$(yq --raw-output .version <<< "$LOCAL_CHART")"
  REMOTE_VERSION="$(helm show chart "$REPO/$CHART" | yq --raw-output .version)" || true # ignore error if chart does not exist
  if [[ -z "$REMOTE_VERSION" ]]; then
    echo "Chart $CHART does not exist in $REPO. Asuming this is a new chart."
    continue
  fi

  # To ensure version bump, we check if the local version is greater than the remote version
  if echo -e "$LOCAL_VERSION\n$REMOTE_VERSION" | sort -c -V 2> /dev/null; then
    echo "ERROR: Chart version for $CHART has not been updated. Master is at $REMOTE_VERSION while this branch is at $LOCAL_VERSION" >&2
    rc=1
  fi
done

exit $rc