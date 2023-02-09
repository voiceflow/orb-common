#!/bin/bash

service=${1}
volume="schema-${service}"

set -e

curl "http://localhost:${PORT}/schema.json" > openapi.next.json

if [[ $SKIP_ACCEPTANCE_TESTS == 'false' ]]; then
  echo 'new schema generated, skipping acceptance tests'

  cp openapi.next.json openapi.json

  exit 0
fi

if [[ ! -f openapi.json ]]; then
  echo 'no previous schema found to compare against'

  cp openapi.next.json openapi.json

  exit 0
fi

docker create -v /schemas --name "${volume}" alpine /bin/true
docker cp openapi.next.json "${volume}:/schemas/openapi.next.json"
docker cp openapi.json "${volume}:/schemas/openapi.prev.json"

set +e

docker run --rm --volumes-from "${volume}" openapitools/openapi-diff \
  --fail-on-incompatible \
  /schemas/openapi.next.json /schemas/openapi.prev.json
result=$?

set -e

if [ ${result} = 0 ]; then
  docker cp "${volume}:/schemas/openapi.next.json" openapi.json
fi

docker rm "${volume}"

exit "${result}"
