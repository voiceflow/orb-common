#!/bin/bash

for i in {0..${MAX_RETRY:?}}; do
    set +e
    bash -c "$COMMAND"
    set -e
    if [ $? -eq 0 ]; then
        exit 0
    fi

    sleep $SLEEP
done

echo "failed: ${COMMAND}" >&2
exit 1