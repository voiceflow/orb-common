#!/bin/bash

# Expected environment variables:
echo "BETA_VERSION: ${BETA_VERSION:?}"
echo "AWS_REGION: ${AWS_REGION:?}"

# Set a default value for ECR_REPOSITORY_URI if not set
ECR_REPOSITORY_URI=${ECR_REPOSITORY_URI:-"168387678261.dkr.ecr.us-east-1.amazonaws.com"}

echo "ECR_REPOSITORY_URI: ${ECR_REPOSITORY_URI}"

# Enable experimental OCI support in Helm
export HELM_EXPERIMENTAL_OCI=1

# Login to ECR
aws ecr get-login-password --region "$AWS_REGION" | helm registry login --username AWS --password-stdin "$ECR_REPOSITORY_URI"

# Publishes beta releases for helm charts in subdirectories of working directory
for file in * ; do
    if [[ -d "$file" && -f "$file/$file/Chart.yaml" ]]; then
        echo "Packaging $file"
        cd "$file" || exit
        helm dep update "$file"

        echo "Packaging version $BETA_VERSION"
        helm package "$file" --version "$BETA_VERSION"

        echo "Publishing beta release"
        CHART="$file-$BETA_VERSION.tgz"

        if [ ! -f "$CHART" ]; then
            echo "Packaged chart does not have expected name $CHART. Does the name in Chart.yaml match the directory name?"
            exit 3
        fi

        # Push the chart to ECR
        helm push "$CHART" "oci://$ECR_REPOSITORY_URI/voiceflow-charts-private"
        
        cd ..
    fi
done
