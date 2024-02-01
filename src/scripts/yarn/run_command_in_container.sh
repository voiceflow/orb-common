#!/bin/bash

trap 'echo "fail detected"; touch /tmp/failure' ERR

SRC_ROOT=/tmp/code
# If a folder is specified we copy that one on the host, otherwise copy all
SOURCE_FOLDER="${SRC_ROOT}/${FOLDER_TO_COPY:-.}"

if [[ -n "${MONOREPO_PACKAGE?}" && "${MONOREPO_PACKAGE}" != "all" ]]; then
    DESTINATION_FOLDER="$PWD/${MONOREPO_PACKAGE_FOLDER:?}/${MONOREPO_PACKAGE:?}"
else
    DESTINATION_FOLDER="$PWD"
fi

echo "Copying from ${SOURCE_FOLDER} into ${DESTINATION_FOLDER?}"
echo "Copying code into container"
echo "Executing command \"${COMMAND:?}\" in container \"${CONTAINER_IMAGE:?}\""
docker run --rm -i -v "${PWD}":/src -v "${DESTINATION_FOLDER}":/out --entrypoint /bin/sh "${CONTAINER_IMAGE:?}" <<EOF
    echo "Copying /src to ${SRC_ROOT}"
    cp -R /src ${SRC_ROOT}
    cd ${SRC_ROOT}
    rm -rf /tmp/.success
    for _ in {0..${MAX_RETRIES:?}}; do
        if /bin/sh -c "${COMMAND?}"; then
            touch /tmp/.success
            echo "DEBUG: Successfully executed: ${SUCCESS}"
            break
        fi
        sleep "${SLEEP_TIME:?}"
        echo "Retrying command: ${COMMAND?}"
    done

    cp -R "${SOURCE_FOLDER}" /out

    # Success: clean exit
    ls -lah /tmp
    test -f /tmp/.success && exit 0

    echo "failed: ${COMMAND?}" >&2
    exit 1
EOF

if (( ${SHOULD_REMOVE_LOCKFILE?} )); then
    echo "Removing lock file ${LOCK_FILE?}" 
    rm -rf "${LOCK_FILE}"
fi
