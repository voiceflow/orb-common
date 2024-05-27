#!/bin/bash

# Expected environment variables:
echo "CHARTS: ${CHARTS?}"
echo "AWS_REGION: ${AWS_REGION?}"

# Set a default value for ECR_REPOSITORY_URI if not set
ECR_REPOSITORY_URI=${ECR_REPOSITORY_URI:-"168387678261.dkr.ecr.us-east-1.amazonaws.com"}

echo "ECR_REPOSITORY_URI: ${ECR_REPOSITORY_URI}"

# Enable experimental OCI support in Helm
export HELM_EXPERIMENTAL_OCI=1

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

    # Construct the full ECR URL with the OCI protocol
    FULL_ECR_URL="oci://$ECR_REPOSITORY_URI/$repo"

    # Push the chart to ECR using the OCI protocol
    helm push "$dist/$packaged_chart" "$FULL_ECR_URL"

    rm -rf "$dist"
done
