#!/bin/bash

# Getting the logs
set +e
docker logs server-data-api-e2e > server-data-api.log
docker logs creator-api-e2e > creator-api.log
docker logs alexa-runtime-e2e > alexa-runtime.log
docker logs alexa-service-e2e > alexa-service.log
docker logs google-runtime-e2e > google-runtime.log
docker logs google-service-e2e > google-service.log
docker logs integrations-e2e > integrations.log
docker logs custom-api-e2e > custom-api.log
docker logs luis-authoring-service-e2e > luis-authoring-service.log
docker logs general-runtime-e2e > general-runtime.log
docker logs general-service-e2e > general-service.log
docker logs canvas-export-e2e > canvas-export.log
docker logs dbcli-e2e > dbcli.log
docker logs realtime-e2e > realtime.log
docker logs ml-gateway-e2e > ml-gateway.log
docker logs creator-app-e2e > creator-app.log
docker logs event-ingestion-service-e2e > event-ingestion-service.log
set -e