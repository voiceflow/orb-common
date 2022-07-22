#!/bin/bash

FILES_CHANGED=$(git diff HEAD^ --name-only )
echo "files changed: $FILES_CHANGED"

for f in packages/*; do
    if [[ $FILES_CHANGED == *"$f/"* || $CIRCLE_BRANCH == "master" || $CIRCLE_BRANCH == "production" || ! -z "$CIRCLE_TAG" || $FORCE_EXECUTION == true  ]]; then

        if [[ $RUN_ON_ROOT != true ]]; then
        cd $f
        echo "running command $COMMAND on $f"
        else
        echo "running command $COMMAND on monorepo root"
        fi

        # Execute command
        /bin/bash -c "$COMMAND $EXTRA_ARGS"

        if [[ $RUN_ON_ROOT != true ]]; then
        cd -
        else
        # if the command has to be executed on root, just run it once
        exit 0
        fi
    fi
done