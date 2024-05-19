#!/bin/bash

# Expected environment variables:
echo "CHARTS: ${CHARTS?}"
echo "AWS_REGION: ${AWS_REGION?}"
echo "ECR_REPOSITORY_URI: ${ECR_REPOSITORY_URI?}"

# Login to ECR
aws ecr get-login-password --region "$AWS_REGION" | helm registry login --username AWS --password-stdin "$ECR_REPOSITORY_URI"

for chart in ${CHARTS?}; do
    echo "Packaging $chart"

    # Create a temporary directory to store the packaged chart
    dist="$(mktemp -d)"

    helm dep update "$chart/$chart"
    helm package "$chart/$chart" --destination "$dist"

    # Get the chart version from the packaged chart
    packaged_chart="$(ls "$dist")"
    chart_version=$(helm show chart "$dist/$packaged_chart" | yq --raw-output '.version')
    channel=$(helm show chart "$chart/$chart" | yq --raw-output '.annotations."release-repository"')
    echo "Publishing in $channel channel"

    repo="voiceflow-charts-private"
    if [[ "$channel" == "public" ]]; then
        repo="voiceflow-charts-public"
    fi

    FULL_ECR_URL="$ECR_REPOSITORY_URI/$repo/$chart:$chart_version"

    helm chart save "$dist/$packaged_chart" "$FULL_ECR_URL"
    helm chart push "$FULL_ECR_URL"

    rm -rf "$dist"
done
