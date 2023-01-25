#!/bin/bash
# shellcheck disable=SC2086

trap 'echo "fail detected"; touch /tmp/failure' ERR

echo "Running command: ${COMMAND:?}"
for _ in $(seq 0 "${MAX_RETRIES:?}"); do
    if bash -c "${COMMAND?}"; then
        if (( ${SHOULD_REMOVE_LOCKFILE?} )); then
            echo "Removing lock file ${LOCK_FILE?}" 
            rm -rf "${LOCK_FILE}"
        fi
        exit 0
    fi
    sleep "${SLEEP_TIME:?}"
    echo "Retrying command: ${COMMAND?}"
done

echo "failed: ${COMMAND?}" >&2
exit 1
