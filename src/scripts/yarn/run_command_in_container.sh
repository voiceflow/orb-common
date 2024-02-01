#!/bin/bash

trap 'echo "fail detected"; touch /tmp/failure' ERR


echo "Copying code into container"
VOLUME_ID=$(docker volume create)
CODE_CONTAINER_ID=$(docker create -v "${VOLUME_ID}":/code "${CONTAINER_IMAGE:?}" /bin/true)
docker cp "$PWD/." "${CODE_CONTAINER_ID}":/code

echo "Copy npm auth configs"
docker cp "${HOME}"/.yarnrc.yml "${CODE_CONTAINER_ID}":/root/
docker cp "${HOME}"/.npmrc "${CODE_CONTAINER_ID}":/root/

echo "Executing command \"${COMMAND:?}\" in container"
docker run \
  --rm -i \
  --volumes-from "${CODE_CONTAINER_ID}" \
  -w /code \
  --entrypoint /bin/sh \
  "${CONTAINER_IMAGE:?}" \
  <<EOF
    echo "TEMP: delete the node_modules and .yarn/cache"
    rm -rf ./node_modules .yarn/cache
    for _ in {0..${MAX_RETRIES:?}}; do
        if /bin/sh -c "${COMMAND?}"; then
            exit 0
        fi
        sleep "${SLEEP_TIME:?}"
        echo "Retrying command: ${COMMAND?}"
    done

    echo "failed: ${COMMAND?}" >&2
    exit 1
EOF

# If a folder is specified we copy that one on the host, otherwise copy all
SOURCE_FOLDER="${CODE_CONTAINER_ID}:/code/${FOLDER_TO_COPY:-.}"

if [[ -n "${MONOREPO_PACKAGE?}" && "${MONOREPO_PACKAGE}" != "all" ]]; then
    DESTINATION_FOLDER="$PWD/${MONOREPO_PACKAGE_FOLDER:?}/${MONOREPO_PACKAGE:?}"
else
    DESTINATION_FOLDER="$PWD"
fi

echo "Copying from ${SOURCE_FOLDER} into ${DESTINATION_FOLDER?}"
docker cp "${SOURCE_FOLDER}" "${DESTINATION_FOLDER}"

if (( ${SHOULD_REMOVE_LOCKFILE?} )); then
    echo "Removing lock file ${LOCK_FILE?}" 
    rm -rf "${LOCK_FILE}"
fi
