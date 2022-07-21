#!/bin/bash

docker rm code || docker create \
    --network="vf_voiceflow" \
    --volume /code \
    --name code \
    168387678261.dkr.ecr.us-east-1.amazonaws.com/ci-e2e-image:v1 \
    /bin/true
docker-compose -p vf -f docker-compose-db.yaml up -d