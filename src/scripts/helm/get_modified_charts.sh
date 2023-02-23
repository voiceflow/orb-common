#!/bin/bash

# Get the list of all charts
ALL_CHARTS=()
for DIR in * ; do
    if [[ -d "$DIR" && -f "$DIR/$DIR/Chart.yaml" ]]; then
    ALL_CHARTS+=("$DIR")
    fi;
done

# Extract only modified charts
MODIFIED_CHARTS=()
for CHART in "${ALL_CHARTS[@]}"; do
    if grep -q -oP "M\s*${CHART}/${CHART}/.*" <<< "${CHANGED_FILES?}"; then
    MODIFIED_CHARTS+=("$CHART")
    fi;
done

# shellcheck disable=SC2145
bash -c "echo \"export $MODIFIED_CHARTS_ENV=\\\"${MODIFIED_CHARTS[@]}\\\" >> \\\"$BASH_ENV\\\"\""