#!/bin/bash

# Expected env vars
echo "TARGET: ${TARGET:=prod}"
echo "IMAGE_REPO: ${IMAGE_REPO?}"
echo "IMAGE_TAG: ${IMAGE_TAG:=${TARGET}}"
echo "PLATFORMS: ${PLATFORMS:=linux/amd64}"
echo "DOCKERFILE: ${DOCKERFILE:=Dockerfile}"
echo "NO_CACHE_FILTER: ${NO_CACHE_FILTER:=prod}"
echo "ENABLE_CACHE_TO: ${ENABLE_CACHE_TO:=0}"

# TODO: should be general build-args
echo "PACKAGE: ${PACKAGE-}"


# NOTE: think of this as the CircleCI DLC key
echo "BUILDER: ${BUILDER:=buildy}"

# shellcheck source=/dev/null
test -n "$(shopt -s nullglob; echo /tmp/vf-staged_buildx-*.env_var)" \
  && for i in /tmp/vf-staged_buildx-*.env_var ; do source "$i" ; done
echo "EXTRA_BUILD_ARGS: ${EXTRA_BUILD_ARGS[*]}"

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

IMAGE_CACHE_TAG_BASE="${IMAGE_REPO-}:cache-${BRANCH_NAME-}"

CACHE_FROM_ARG=(--cache-from "${IMAGE_REPO-}:cache-master")

if [ "${BRANCH_NAME}" != "master" ] ; then
  CACHE_FROM_ARG+=(--cache-from "${IMAGE_REPO-}:cache-${BRANCH_NAME-}")
fi

if [ "${ENABLE_CACHE_TO-}" = "true" ] ; then
  CACHE_TO_ARG=(--cache-to "mode=max,image-manifest=true,oci-mediatypes=true,type=registry,ref=${IMAGE_CACHE_TAG_BASE}-${IMAGE_TAG-}")
fi


# This is specific
echo "NPM_TOKEN: ${NPM_TOKEN#"//registry.npmjs.org/:_authToken="}"
# TODO: make file secret ~/.yarnrc.yml,target=$HOME/.yarnrc.yml
# TODO: extensible secrets and build args

docker buildx inspect "${BUILDER}" >/dev/null 2>&1 || docker buildx create --platform="${PLATFORMS}" --name "${BUILDER}"
docker buildx use "${BUILDER-}"
docker buildx inspect --bootstrap

if [[ -n "$PACKAGE" ]]; then
    PACKAGE_ARG=(--build-arg APP_NAME="$PACKAGE")
fi

docker buildx build . \
  -f "${DOCKERFILE}" \
  -t "${IMAGE_REPO}:${IMAGE_TAG}" \
  "${PACKAGE_ARG[@]}" \
  "${EXTRA_BUILD_ARGS[@]}" \
  "${CACHE_FROM_ARG[@]}" \
  "${CACHE_TO_ARG[@]}" \
  --secret id=NPM_TOKEN \
  --target "${TARGET}" \
  --platform "${PLATFORMS}" \
  "${OUTPUT_ARG[@]}"
