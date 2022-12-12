#!/bin/bash

REPO=$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME
PR_NUMBER=${CIRCLE_PULL_REQUEST##*/}

if [ -z "$PR_NUMBER" ]; then
    if [[ "$CIRCLE_BRANCH" == "master" || $CIRCLE_BRANCH == "production" ]]; then
        echo "Always run e2e tests on changes to master"
    else
        echo "No PR associated with branch; skipping rest of job"
        circleci-agent step halt
    fi
else
    echo "Checking whether PR $PR_NUMBER is draft"
    IS_DRAFT=$(gh pr view $PR_NUMBER --repo $REPO --json isDraft --jq '.isDraft')
    if $IS_DRAFT; then
        echo "PR $PR_NUMBER is a draft; skipping rest of job"
        circleci-agent step halt
    else
        echo "PR $PR_NUMBER is not a draft; continuing job"
    fi
fi
