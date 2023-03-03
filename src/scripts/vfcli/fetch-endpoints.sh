#!/bin/bash

# Expected environment variables:
echo "CLUSTER: ${CLUSTER:?}"
echo "COMPONENTS: ${COMPONENTS?}"
echo "ENV_NAME: ${ENV_NAME:?}"

vfcli init --interactive false --no-telepresence --cluster ${CLUSTER:?}

for COMPONENT in ${COMPONENTS?}; do
    echo "Fetching $COMPONENT URL"
    vfcli component list --name "${ENV_NAME:?}" --full --output json --interactive false | jq --raw-output ".[] | select(.id == \"${COMPONENT}\") | .endpoint" > "${COMPONENT}.url"
    ENV_VAR_NAME=$(echo "${COMPONENT^^}_URL" | tr '-' '_')
    echo "Storing url for $COMPONENT in $ENV_VAR_NAME: $(cat ${COMPONENT}.url)"
    echo "export ${ENV_VAR_NAME}=\"$(cat ${COMPONENT}.url)\"" >> "$BASH_ENV"
done