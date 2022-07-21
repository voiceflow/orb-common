#!/bin/bash

START_TIME=$(date +%s)

if [[ "<< parameters.tagged >>" != "false" ]]; then
    sleep 60

    #Production
    aws eks --region us-east-1 update-kubeconfig --name cm4-production-0-p0

    #Cloud Snapshot
    aws s3 cp s3://com.voiceflow.ci.assets/scripts/cloud_snapshot.sh cloud_snapshot.sh
    chmod +x cloud_snapshot.sh
    ./cloud_snapshot.sh "${NAMESPACE}" "${COMPONENT}" "${PACKAGE}"

    #FIXME THIS IS A WA with a problem with the Slack Orb and dynamic templates
    export DEPLOY_TEMPLATE=$(cat /tmp/voiceflow/common/deploy_app_template.json)
    export SLACK_PARAM_TEMPLATE=DEPLOY_TEMPLATE
    export SLACK_PARAM_CHANNEL="deployed_versions"
    aws s3 cp s3://com.voiceflow.ci.assets/scripts/slack_notify.sh slack_notify.sh
    chmod +x slack_notify.sh
    ./slack_notify.sh

    if [[ "${SENTRY}" != "false" ]]; then
    END_TIME=$(date +%s)
    npm config set unsafe-perm true
    npx @sentry/cli@1 releases deploys "${CIRCLE_TAG:1}" new -e public -t $((END_TIME-START_TIME))
    fi
fi