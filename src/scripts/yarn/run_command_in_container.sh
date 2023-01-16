#!/bin/bash

trap 'echo "fail detected"; touch /tmp/failure' ERR

echo "Copying code into container"
docker create -v /code --name code "${CONTAINER_IMAGE:?}" /bin/true
docker cp "$PWD/." code:/code

echo "Executing yarn command in container"
docker run --name runner -it --volumes-from code -w /code "${CONTAINER_IMAGE:?}" /bin/bash -c "${COMMAND:?}"

# If a folder is specified we copy that one on the host, otherwise copy all
SOURCE_FOLDER="runner:/code/${FOLDER_TO_COPY:-.}"

if [[ -n "${MONOREPO_PACKAGE?}" ]]; then
    DESTINATION_FOLDER="$PWD/${MONOREPO_PACKAGE_FOLDER:?}/${MONOREPO_PACKAGE:?}"
else
    DESTINATION_FOLDER="$PWD"
fi

echo "Copying from ${SOURCE_FOLDER} into ${DESTINATION_FOLDER?}"
docker cp "${SOURCE_FOLDER}" "${DESTINATION_FOLDER}"


echo "Removing lock file ${LOCK_FILE?}" 
rm -rf "${LOCK_FILE}"