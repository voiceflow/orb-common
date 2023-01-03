#!/bin/bash

for file in */ ; do
    if [[ -d "$file" && -f "$file/$file/Chart.yaml" ]]; then
        echo "packaging $file";
        cd "$file" || exit;
        helm dep update "$file";
        helm package "$file";
        pattern="*.tgz";
        chart=( $pattern );
        channel=$(cat "$file"/Chart.yaml | yq -r '.annotations."release-repository"')
        echo "publishing in $channel channel";
        if [[ $channel == "private" ]]; then
            helm s3 push --force "${chart[0]}" voiceflow-charts-s3-private;
        fi
        if [[ $channel == "public" ]]; then
            helm s3 push --force "${chart[0]}" voiceflow-charts-s3;
        fi
        if [[ $channel == "beta" ]]; then
            helm s3 push --force "${chart[0]}" voiceflow-charts-s3-beta;
        fi
        cd ..;
    fi;
done