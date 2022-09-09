#!/bin/bash

# BETA_VERSION must be set previously

REGEX='chart: (.+)-(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*).tgz'
for file in * ; do
    HELMRELEASE="$file/$file/templates/helmrelease.yaml" 
    if [[ -d "$file" && -f "$HELMRELEASE" ]]; then
        sed -i -E "s/$REGEX/chart: \1-${BETA_VERSION}.tgz/g" "$HELMRELEASE"
        sed -i -E "s/voiceflow-charts-private/voiceflow-charts-beta/g" "$HELMRELEASE"
    fi
done 