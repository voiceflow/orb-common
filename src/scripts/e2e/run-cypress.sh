#!/bin/bash

docker run \
  --workdir /code/creator-app \
  --network="vf_voiceflow" \
  --name cypress-e2e \
  --volumes-from code \
  --volume vf_certs:/code/creator-app/packages/creator-app/certs \
  --volume vf_caroot:/usr/local/share/ca-certificates \
  --volume /var/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket \
  --env NODE_OPTIONS=--max_old_space_size=4096 \
  --env CYPRESS_API_URL="$CYPRESS_API_URL" \
  --env CIRCLE_WORKFLOW_ID="$CIRCLE_WORKFLOW_ID" \
  --env CYPRESS_RECORD_KEY="$CYPRESS_RECORD_KEY" \
  168387678261.dkr.ecr.us-east-1.amazonaws.com/ci-e2e-image:v1 \
  /bin/bash -c "yarn cypress:install && yarn cypress:ci"