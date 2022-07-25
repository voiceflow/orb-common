#!/bin/bash

retry() {
    error=""
    n=0
    until [ $n -ge $MAX_RETRY ]; do
    set +e
    eval "$@"
    set -e
    if [ $? -eq 0 ]; then
        break
    fi

    n=$[$n+1]
    sleep "$SLEEP"
    done
    if [ $n -ge $MAX_RETRY ]; then
    echo "failed: ${@}" >&2
    exit 1
    fi
}
retry "$COMMAND"