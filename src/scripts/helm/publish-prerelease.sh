#!/bin/bash

# Expected environment variables:
echo "BETA_VERSION: ${BETA_VERSION:?}"

# Publishes beta releases for helm charts in subdirectories of working directory
# Similar implementation to the `helm-publish-charts` command. If updating this script, be sure to update that one as well
for file in * ; do
    if [[ -d "$file" && -f "$file/$file/Chart.yaml" ]]; then
        echo "packaging $file";
        cd "$file" || exit;
        helm dep update "$file";

        echo "Packaging version $BETA_VERSION"
        helm package "$file" --version "$BETA_VERSION"

        echo "publishing beta release";
        CHART="$file-${BETA_VERSION}.tgz"

        if [ ! -f "$CHART" ]; then
            echo "Packaged chart does not have expected name $CHART. Does the name in Chart.yaml match the directory name?"
            exit 3
        fi

        helm s3 push --force "$CHART" voiceflow-charts-s3-beta;
        cd ..;
    fi;
done