#!/bin/bash

domain=${1:-voiceflow-libs}
repo=${2:-voiceflow-libs}
owner=${3:-168387678261}

CODEARTIFACT_REPOSITORY_URL=$(aws codeartifact get-repository-endpoint \
              --domain "$domain" \
              --domain-owner "$owner" --repository "$repo" \
              --format pypi --query repositoryEndpoint --output text)
CODEARTIFACT_AUTH_TOKEN=$(aws codeartifact get-authorization-token --domain "$domain" \
              --domain-owner "$owner" \
              --query authorizationToken --output text)
CODEARTIFACT_USER=aws

poetry config repositories."$repo" "$CODEARTIFACT_REPOSITORY_URL"
poetry config http-basic."$repo" "$CODEARTIFACT_USER" "$CODEARTIFACT_AUTH_TOKEN"