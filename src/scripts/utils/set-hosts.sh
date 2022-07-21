#!/bin/bash

# Modify the hosts of the executor
set +e
# with sudo - machine executor
echo '127.0.0.1 creator-app.test.e2e postgres.test.e2e redis.test.e2e localstack.test.e2e mongodb.test.e2e server-data-api.test.e2e creator-api.test.e2e luis-authoring-service.test.e2e integrations.test.e2e custom-api.test.e2e canvas-export.test.e2e alexa-runtime.test.e2e alexa-service.test.e2e general-runtime.test.e2e general-service.test.e2e google-runtime.test.e2e google-service.test.e2e realtime.test.e2e ingest.test.e2e event-ingestion-service.test.e2e' | sudo tee -a /etc/hosts > /dev/null
# without sudo - docker executor
echo '127.0.0.1 creator-app.test.e2e postgres.test.e2e redis.test.e2e localstack.test.e2e mongodb.test.e2e server-data-api.test.e2e creator-api.test.e2e luis-authoring-service.test.e2e integrations.test.e2e custom-api.test.e2e canvas-export.test.e2e alexa-runtime.test.e2e alexa-service.test.e2e general-runtime.test.e2e general-service.test.e2e google-runtime.test.e2e google-service.test.e2e realtime.test.e2e ingest.test.e2e event-ingestion-service.test.e2e' | tee -a /etc/hosts > /dev/null
set -e