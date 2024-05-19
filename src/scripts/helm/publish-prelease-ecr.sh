#!/bin/bash

# Expected environment variables:
echo "BETA_VERSION: ${BETA_VERSION:?}"
echo "ECR_REPOSITORY_URI: ${ECR_REPOSITORY_URI:?}"
echo "AWS_REGION: ${AWS_REGION:?}"

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

        # Construct the full ECR URL
        FULL_ECR_URL="$ECR_REPOSITORY_URI/voiceflow-charts-beta/$file:$BETA_VERSION"

        # Save and push the chart to ECR
        helm chart save "$CHART" "$FULL_ECR_URL"
        helm chart push "$FULL_ECR_URL"

        cd ..
    fi
done
