#!/bin/bash

docker run \
    --network vf_voiceflow \
    168387678261.dkr.ecr.us-east-1.amazonaws.com/ci-e2e-image:v1 \
    /bin/bash -c "npx wait-on -t 300000 https://${SERVICE_NAME}.test.e2e:${SERVICE_PORT}/health"