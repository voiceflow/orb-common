#!/bin/bash

# Expected env vars
echo "TARGET: ${TARGET:=prod}"
echo "IMAGE_REPO: ${IMAGE_REPO?}"
echo "IMAGE_TAG: ${IMAGE_TAG:=${TARGET}}"
echo "PLATFORMS: ${PLATFORMS:=linux/amd64}"
echo "DOCKERFILE: ${DOCKERFILE:=Dockerfile}"
echo "NO_CACHE_FILTER: ${NO_CACHE_FILTER:=prod}"
echo "CLEANUP_IMAGE: ${CLEANUP_IMAGE:=0}"
echo "OUTPUT: ${OUTPUT-}"

# TODO: should be general build-args
echo "PACKAGE: ${PACKAGE-}"


# NOTE: think of this as the CircleCI DLC key
echo "BUILDER: ${BUILDER:=buildy}"

# shellcheck source=/dev/null
for i in /tmp/vf-staged_buildx-*.env_var ; do source "$i" ; done
echo "EXTRA_BUILD_ARGS: ${EXTRA_BUILD_ARGS[*]}"

# This is specific
echo "NPM_TOKEN: ${NPM_TOKEN#"//registry.npmjs.org/:_authToken="}"
# TODO: make file secret ~/.yarnrc.yml,target=$HOME/.yarnrc.yml
# TODO: extensible secrets and build args

docker buildx inspect "${BUILDER}" >/dev/null 2>&1 || docker buildx create --platform="${PLATFORMS}" --name "${BUILDER}"
docker buildx use "${BUILDER}"
docker buildx inspect --bootstrap

if [[ -n "$PACKAGE" ]]; then
    PACKAGE_ARG=(--build-arg APP_NAME="$PACKAGE")
fi

if [ -n "$OUTPUT" ] ; then
  OUTPUT=(--output "${OUTPUT}")
else
  OUTPUT=(--load)
fi

docker buildx build . \
  -f "${DOCKERFILE}" \
  -t "${IMAGE_REPO}:${IMAGE_TAG}" \
  "${PACKAGE_ARG[@]}" \
  "${EXTRA_BUILD_ARGS[@]}" \
  --secret id=NPM_TOKEN \
  --target "${TARGET}" \
  --platform "${PLATFORMS}" \
  "${OUTPUT[@]}"

test "${CLEANUP_IMAGE-}" -eq 1 && echo "Deleting image" && docker image rm "${IMAGE_REPO}:${IMAGE_TAG}" || echo "Done"
