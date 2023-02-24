#!/bin/bash

# Expected environment variables:
echo "CHARTS: ${CHARTS?}"

for chart in ${CHARTS?}; do
    echo "Packaging $chart";

    # Create a temporary directory to store the packaged chart
    dist="$(mktemp -d)"

    helm dep update "$chart/$chart"
    helm package "$chart/$chart" --destination "$dist"

    channel=$(helm show "$chart/$chart" | yq --raw-output '.annotations."release-repository"')
    echo "Publishing in $channel channel";

    repo="voiceflow-charts-s3-$channel"
    if [[ "$channel" == "public" ]]; then
        repo="voiceflow-charts-s3"
    fi

    packaged_chart="$(ls "$dist")"
    helm s3 push "$dist/$packaged_chart" "$repo"

    rm -rf "$dist"
done