#!/bin/bash

trap 'echo "fail detected"; touch /tmp/failure' ERR

SRC_ROOT=/code
# If a folder is specified we copy that one on the host, otherwise copy all
SOURCE_FOLDER="${SRC_ROOT}/${FOLDER_TO_COPY:-.}"

if [[ -n "${MONOREPO_PACKAGE?}" && "${MONOREPO_PACKAGE}" != "all" ]]; then
    DESTINATION_FOLDER="$PWD/${MONOREPO_PACKAGE_FOLDER:?}/${MONOREPO_PACKAGE:?}"
else
    DESTINATION_FOLDER="$PWD"
fi

echo "SOURCE_FOLDER: ${SOURCE_FOLDER}"
pwd && ls -lah .
echo "DESTINATION_FOLDER: ${DESTINATION_FOLDER}"
ls -lah "${DESTINATION_FOLDER}"

echo "Executing command \"${COMMAND:?}\" in container \"${CONTAINER_IMAGE:?}\""
docker run -i -v "${PWD}":/src --entrypoint /bin/sh "${CONTAINER_IMAGE:?}" <<EOF
    echo "Copying /src to ${SRC_ROOT}"
    whoami
    echo "ls /src"
    ls -lah /src

    echo "ls /out"
    ls -lah /out

    cp -R /src ${SRC_ROOT}
    cd ${SRC_ROOT}
    pwd && ls -lah .

    SUCCESS=0
    for _ in {0..${MAX_RETRIES:?}}; do
        if /bin/sh -c "${COMMAND?}"; then
            SUCCESS=1 
            echo "DEBUG: Successfully executed: ${SUCCESS}"
            break
        fi
        sleep "${SLEEP_TIME:?}"
        echo "Retrying command: ${COMMAND?}"
    done

    echo "Copying from ${SOURCE_FOLDER} into ${DESTINATION_FOLDER?}"
    echo "ls ${SRC_ROOT}"
    ls -lah "${SRC_ROOT}"
    cp -R "${SOURCE_FOLDER}" /out
    ls -lah /out

    # Success: clean exit
    ls -lah /tmp
    test 1 -eq \$SUCCESS && exit 0

    echo "failed: ${COMMAND?}" >&2
    exit 1
EOF

ls -lah "${DESTINATION_FOLDER}"

if (( ${SHOULD_REMOVE_LOCKFILE?} )); then
    echo "Removing lock file ${LOCK_FILE?}" 
    rm -rf "${LOCK_FILE}"
fi
