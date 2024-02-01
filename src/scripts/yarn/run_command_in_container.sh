#!/bin/bash

trap 'echo "fail detected"; touch /tmp/failure' ERR

docker info

echo "Copying code into container"
VOLUME_ID=$(docker volume create)
CODE_CONTAINER_ID=$(docker create -v "${VOLUME_ID}":/code "${CONTAINER_IMAGE:?}" /bin/true)
docker cp "$PWD/." "${CODE_CONTAINER_ID}":/code

echo "npm auth files: HOME: ${HOME}"
ls -lah /home/circleci/.yarnrc.yml
ls -lah /home/circleci/.npmrc
whoami

mkdir -p /tmp/configs
cp ~/.yarnrc.yml /tmp/configs/
cp ~/.npmrc /tmp/configs/

echo "Executing command \"${COMMAND:?}\" in container"
docker run \
  --rm -it \
  --volumes-from "${CODE_CONTAINER_ID}" \
  -v /tmp/configs:/tmp/configs \
  -w /code \
  "${CONTAINER_IMAGE:?}" \
  /bin/bash -c "
    cp /tmp/configs/* ~/
    for _ in {0..${MAX_RETRIES:?}}; do
        if bash -c \"${COMMAND?}\"; then
            exit 0
        fi
        sleep \"${SLEEP_TIME:?}\"
        echo \"Retrying command: ${COMMAND?}\"
    done

    echo \"failed: ${COMMAND?}\" >&2
    exit 1
"

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
