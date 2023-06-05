#!/bin/bash

# Expected environment variables:
echo "CHANGED_FILES: ${CHANGED_FILES?}"
echo "CHART_DIR: ${CHART_DIR:?}"
echo "MODIFIED_CHARTS_ENV: ${MODIFIED_CHARTS_ENV:?}"

# Add trailing slash to CHART_DIR if missing
if [[ "$CHART_DIR" != */ ]]; then
    CHART_DIR="${CHART_DIR}/"
fi

# Handle chart directory being the root
if [[ "$CHART_DIR" == "./" ]]; then
    CHART_DIR=""
fi

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
    if grep -q -oP "(M|A)\s*${CHART_DIR}${CHART}/${CHART}/.*" <<< "${CHANGED_FILES?}"; then
    MODIFIED_CHARTS+=("$CHART")
    fi;
done

echo "${MODIFIED_CHARTS[@]}"

# shellcheck disable=SC2145
echo "export ${MODIFIED_CHARTS_ENV:?}=\"${MODIFIED_CHARTS[@]}\"" >> "$BASH_ENV"