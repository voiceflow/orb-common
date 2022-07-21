#!/bin/bash

COMMIT_MESSAGE="$(git log --format=oneline -n 1 $CIRCLE_SHA1)"

# If a message has been introduces, we have to check that in the commit message, if it is not included, the braches will not be synced
# this is for the use case of the bugfix mechanism
if [[ $COMMIT_MESSAGE != *"$CHECK_COMMIT_MESSAGE"* ]]; then
    circleci-agent step halt
fi