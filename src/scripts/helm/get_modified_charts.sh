#!/bin/bash

# Expected environment variables:
echo "CHANGED_FILES: ${CHANGED_FILES?}"
echo "CHART_DIR: ${CHART_DIR:?}"
echo "MODIFIED_CHARTS_ENV: ${MODIFIED_CHARTS_ENV:?}"
echo "MODIFIED_CHARTS_REPOS_ENV: ${MODIFIED_CHARTS_REPOS_ENV:?}"

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
MODIFIED_CHARTS_REPOS=()
for CHART in "${ALL_CHARTS[@]}"; do
    if grep -q -oP "M\s*${CHART_DIR}${CHART}/${CHART}/.*" <<< "${CHANGED_FILES?}"; then
        MODIFIED_CHARTS+=("$CHART")

        # Also keep track of channel for re-indexing
        CHANNEL=$(helm show chart "${CHART}/${CHART}" | yq --raw-output '.annotations."release-repository"')
        REPO="voiceflow-charts-s3-$CHANNEL"
        if [[ "$CHANNEL" == "public" ]]; then
            REPO="voiceflow-charts-s3"
        fi

        MODIFIED_CHARTS_REPOS+=("$REPO")
    fi;
done

# Ensure each repo is unique
MODIFIED_CHARTS_REPOS="$(echo "${MODIFIED_CHARTS_REPOS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')"

echo "${MODIFIED_CHARTS[@]}"
echo "${MODIFIED_CHARTS_REPOS}"

# shellcheck disable=SC2145
echo "export ${MODIFIED_CHARTS_ENV:?}=\"${MODIFIED_CHARTS[@]}\"" >> "$BASH_ENV"
echo "export ${MODIFIED_CHARTS_REPOS_ENV:?}=\"${MODIFIED_CHARTS_REPOS}\"" >> "$BASH_ENV"