#!/bin/bash

for file in */ ; do
    if [[ -d "$file" && -f "$file/$file/Chart.yaml" ]]; then
        echo "packaging $file";
        cd "$file" || exit;
        helm dep update "$file";
        helm package "$file";
        chart=$(find . -type f -name "*.tgz" | head -n1);
        channel=$(yq -r '.annotations."release-repository"' "$file"/Chart.yaml)
        echo "publishing in $channel channel";
        if [[ $channel == "private" ]]; then
            helm s3 push --force "${chart}" voiceflow-charts-s3-private;
        fi
        if [[ $channel == "public" ]]; then
            helm s3 push --force "${chart}" voiceflow-charts-s3;
        fi
        if [[ $channel == "beta" ]]; then
            helm s3 push --force "${chart}" voiceflow-charts-s3-beta;
        fi
        cd ..;
    fi;
done