#!/bin/bash

# copy a config file into this volume and the npm token
docker cp ${SERVICE_NAME} code:/code
docker cp ~/.npmrc code:/code/${SERVICE_NAME}
# start an application container using this volume
docker run \
  --workdir /code/${SERVICE_NAME} \
  --detach \
  --expose ${SERVICE_PORT} \
  --publish ${SERVICE_PORT}:${SERVICE_PORT} \
  --name ${SERVICE_NAME}-e2e \
  --hostname ${SERVICE_NAME}.test.e2e \
  --network="vf_voiceflow" \
  --volumes-from code \
  --volume vf_certs:/code/${SERVICE_NAME}/certs \
  --volume vf_caroot:/usr/local/share/ca-certificates \
  168387678261.dkr.ecr.us-east-1.amazonaws.com/ci-e2e-image:v1 \
  /bin/bash -c "update-ca-certificates && yarn install --force && yarn e2e"