#!/bin/bash -e

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
  REMOTE_VERSION="$(helm show chart "$REPO/$CHART" | yq --raw-output .version)"

  # To ensure version bump, we check if the local version is greater than the remote version
  if echo -e "$LOCAL_VERSION\n$REMOTE_VERSION" | sort -c -V; then
    echo "Chart $CHART has not been updated" >&2
    rc=1
  fi
done

exit $rc