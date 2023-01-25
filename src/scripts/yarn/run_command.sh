#!/bin/bash
# shellcheck disable=SC2086

trap 'echo "fail detected"; touch /tmp/failure' ERR

echo "Running command: ${COMMAND:?}"
bash -c "for _ in {0..${MAX_RETRIES:?}}; do ${COMMAND:?} && break || sleep ${SLEEP_TIME:?} && echo \"Retrying $COMMAND\"; done"

if (( ${SHOULD_REMOVE_LOCKFILE?} )); then
    echo "Removing lock file ${LOCK_FILE?}" 
    rm -rf "${LOCK_FILE}"
fi