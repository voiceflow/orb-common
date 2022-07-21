#!/bin/bash

SYNC=true
COMMIT_MESSAGE="$(git log --format=oneline -n 1 $CIRCLE_SHA1)"

# If a message has been introduces, we have to check that in the commit message, if it is not included, the braches will not be synced
# this is for the use case of the bugfix mechanism
if [[ $CHECK_COMMIT_MESSAGE != "" && $COMMIT_MESSAGE != *"$CHECK_COMMIT_MESSAGE"* ]]; then
    SYNC=false
fi

if [[ $SYNC == true ]]; then
    git fetch
    git checkout "$DESTINATION_BRANCH"
    git rebase "$SOURCE_BRANCH"
    git push origin "$DESTINATION_BRANCH"
else
    echo "Avoiding syncing branches"
    circleci-agent step halt
fi