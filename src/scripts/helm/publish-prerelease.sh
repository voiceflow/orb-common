#!/bin/bash

for file in */ ; do
if [[ -d "$file" && -f "$file/$file/Chart.yaml" ]]; then
    echo "packaging $file";
    cd $file;
    helm dep update $file;

    echo "Getting current chart version"
    VERSION="$(cat $file/Chart.yaml | yq -r '.version')"

    echo "Getting short SHA1 of git commit"
    SHA="$(git rev-parse --short HEAD)"
    BETA_VERSION="${VERSION}+${SHA}"
    helm package $file --version "$BETA_VERSION"

    echo "publishing in $channel channel";
    CHART="$file-${BETA_VERSION}.tgz"

    if [ ! -f "$CHART" ]; then
    echo "Packaged chart does not have expected name $CHART. Does the name in Chart.yaml match the directory name?"
    exit 3
    fi

    helm s3 push --force "$CHART" voiceflow-charts-s3-beta;
    cd ..;
fi;
done