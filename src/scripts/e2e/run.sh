#!/bin/bash

echo "running e2e"
docker run \
    --detach \
    --expose 3002 \
    --publish 3002:3002 \
    --workdir /code/creator-app \
    --network="vf_voiceflow" \
    --name creator-app-e2e \
    --hostname creator-app.test.e2e \
    --volumes-from code \
    --volume vf_certs:/code/creator-app/packages/creator-app/certs \
    --volume vf_caroot:/usr/local/share/ca-certificates \
    168387678261.dkr.ecr.us-east-1.amazonaws.com/ci-e2e-image:v1 \
    /bin/bash -c "update-ca-certificates && yarn start:e2e && sleep infinity"