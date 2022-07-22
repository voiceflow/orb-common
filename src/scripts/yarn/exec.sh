#!/bin/bash

trap 'echo "fail detected"; touch /tmp/failure' ERR

if [[ $RUN_IN_CONTAINER == true ]]; then
    echo "Running in a container"
    docker create -v /code --name code "$CONTAINER_IMAGE" /bin/true
    docker cp $PWD/. code:/code

    # Executes Yarn command in container
    docker run --name runner -it --volumes-from code -w /code "$CONTAINER_IMAGE" /bin/bash -c "$YARN_COMMAND"
    # If a folder is specified we copy that one on the host
    if [[ $FOLDER_TO_COPY != "" ]]; then
    DESTINATION_FOLDER=$PWD
    if [[ $MONOREPO_PACKAGE != "" ]]; then
        DESTINATION_FOLDER="$PWD/packages/$MONOREPO_PACKAGE"
    fi

    docker cp runner:/code/${CONTAINER_FOLDER_TO_COPY} $DESTINATION_FOLDER

    echo "Copying into $DESTINATION_FOLDER"
    else
    #Copy all
    echo "Copying all"
    docker cp runner:/code/. ./
    fi
else
    # Executes Yarn command outside container
    echo "Running \"$YARN_COMMAND\" without a container"
    /bin/bash -c "$YARN_COMMAND"
fi

# Remove lock file when it is running in background/parallel
if [[ $RUN_IN_BACKGROUND == true ]]; then
    echo "Removing Lock $LOCK_FILE"
    rm -rf $LOCK_FILE
fi