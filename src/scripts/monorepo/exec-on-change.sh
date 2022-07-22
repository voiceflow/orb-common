#!/bin/bash

FILES_CHANGED=$(git diff HEAD^ --name-only )
echo "files changed: $FILES_CHANGED"

if [[ $FILES_CHANGED == *"$PACKAGE_FORCED"* || $CIRCLE_BRANCH == "master" || $CIRCLE_BRANCH == "production" || ! -z "$CIRCLE_TAG" || $FORCE_EXECUTION == 1 ]]; then

    if ! (( $RUN_ON_ROOT )); then
        cd packages/$PACKAGE_FORCED
        echo "running command $COMMAND on packages/$PACKAGE_FORCED"
    else
        echo "running command $COMMAND on monorepo root"
    fi

    # Execute command
    /bin/bash -c "$COMMAND $EXTRA_ARGS"

    if ! (( $RUN_ON_ROOT )); then
        cd -
    fi
fi