#!/bin/bash
# shellcheck disable=SC2086

trap 'echo "fail detected"; touch /tmp/failure' ERR

${COMMAND:?}

if (( ${SHOULD_REMOVE_LOCKFILE?} )); then
    echo "Removing lock file ${LOCK_FILE?}" 
    rm -rf "${LOCK_FILE}"
fi