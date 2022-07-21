#!/bin/bash

docker run -d --name prepublish --network host -v /src 168387678261.dkr.ecr.us-east-1.amazonaws.com/ci-node-build-image:v1 tail -f /dev/null
docker cp ./ prepublish:/src
docker exec prepublish git config --global user.email "serviceaccount@voiceflow.com"
docker exec prepublish git config --global user.name "Voiceflow"
docker exec prepublish npx wait-on http://localhost:4873/-/ping

docker exec -w /src prepublish npx lerna@4.0.0 publish prerelease \
    --registry=http://localhost:4873 \
    --force-publish \
    --amend \
    --exact \
    --no-verify-access \
    --no-commit-hooks \
    --yes
docker cp prepublish:/src/. ./