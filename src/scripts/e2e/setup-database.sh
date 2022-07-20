#!/bin/bash

# copy a config file into this volume
docker cp database-cli code:/code
# start an application container using this volume
docker run \
    --workdir /code/database-cli \
    --name dbcli-e2e \
    --hostname dbcli.test.e2e \
    --network=\"vf_voiceflow\" \
    --env AWS_ACCESS_KEY_ID=\"null\" \
    --env AWS_SECRET_ACCESS_KEY=\"null\" \
    --volumes-from code \
    168387678261.dkr.ecr.us-east-1.amazonaws.com/ci-e2e-image:v1 \
    /bin/bash -c \"yarn init:e2e\"