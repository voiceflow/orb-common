#!/bin/bash

for _ in $(seq 0 "${MAX_RETRY:?}"); do
    if bash -c "${COMMAND?}"; then
        exit 0
    fi
    sleep "${SLEEP:?}"
    echo "Retrying command: ${COMMAND?}"
done

echo "failed: ${COMMAND?}" >&2
exit 1