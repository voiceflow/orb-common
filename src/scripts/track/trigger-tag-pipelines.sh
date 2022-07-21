#!/bin/bash

for TAG in ${TAGS}
do
    URI="https://circleci.com/api/v2/project/github/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/pipeline"
    curl -u ${CIRCLECI_API_TOKEN}: -X POST --header 'Content-Type: application/json' -d "{\"tag\":\"$TAG\", \"parameters\": {}}" "$URI"
done