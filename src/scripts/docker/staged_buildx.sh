#!/bin/bash

# Expected env vars
echo "TARGET: ${TARGET:=runner}"
echo "IMAGE_REPO: ${IMAGE_REPO?}"
echo "IMAGE_TAG: ${IMAGE_TAG:=${TARGET}}"
echo "PLATFORMS: ${PLATFORMS:=linux/amd64}"
echo "DOCKERFILE: ${DOCKERFILE:=Dockerfile}"
echo "NO_CACHE_FILTER: ${NO_CACHE_FILTER:=runner}"
echo "ENABLE_CACHE_TO: ${ENABLE_CACHE_TO:=0}"
echo "EXTRA_BUILD_ARGS: ${EXTRA_BUILD_ARGS[*]}"

# force string to array
read -r -a EXTRA_BUILD_ARGS <<< "$EXTRA_BUILD_ARGS"

if [ -z "${OUTPUT-}" ] ; then
  OUTPUT_ARG=(--load)
else
  OUTPUT_ARG=(--output "${OUTPUT}")
fi

echo "OUTPUT: ${OUTPUT_ARG[*]}"

if [[ -z "$CIRCLE_BRANCH" && -n "$CIRCLE_TAG" ]]; then
    BRANCH_NAME="master"
else
    BRANCH_NAME="${CIRCLE_BRANCH//[^[:alnum:]]/-}" # Change all non alphanumeric characters to -
fi

# NOTE: think of this as the CircleCI DLC key
echo "BUILDER: ${BUILDER:=buildy-${BRANCH_NAME-}}"

CACHE_FROM_ARG=(--cache-from "${IMAGE_REPO-}:cache-master")

if [ "${BRANCH_NAME}" != "master" ] ; then
  CACHE_FROM_ARG+=(--cache-from "${IMAGE_REPO-}:cache-${BRANCH_NAME-}")
fi

IMAGE_CACHE_TAG_BASE="${IMAGE_REPO-}:cache-${BRANCH_NAME-}"
if [ "${ENABLE_CACHE_TO-}" == "true" ] ; then
  CACHE_TO_ARG=(--cache-to "mode=max,image-manifest=true,oci-mediatypes=true,type=registry,ref=${IMAGE_CACHE_TAG_BASE}")
fi

for arg in "${EXTRA_BUILD_ARGS[@]}" ; do
  BUILD_ARGS+=(--build-arg "${arg}")
done

echo "BUILD_ARGS: ${BUILD_ARGS[*]}"


# This is specific
echo "NPM_TOKEN: ${NPM_TOKEN#"//registry.npmjs.org/:_authToken="}"
# TODO: make file secret ~/.yarnrc.yml,target=$HOME/.yarnrc.yml
# TODO: extensible secrets and build args

docker buildx inspect "${BUILDER}" >/dev/null 2>&1 || docker buildx create --platform="${PLATFORMS}" --name "${BUILDER}"
docker buildx use "${BUILDER-}"
docker buildx inspect --bootstrap

docker buildx build . \
  -f "${DOCKERFILE}" \
  -t "${IMAGE_REPO}:${IMAGE_TAG}" \
  "${PACKAGE_ARG[@]}" \
  "${BUILD_ARGS[@]}" \
  "${CACHE_FROM_ARG[@]}" \
  "${CACHE_TO_ARG[@]}" \
  --secret id=NPM_TOKEN \
  --target "${TARGET}" \
  --platform "${PLATFORMS}" \
  "${OUTPUT_ARG[@]}"
