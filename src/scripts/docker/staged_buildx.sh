#!/bin/sh

# Expected env vars
echo "TARGET: ${TARGET:=prod}"
echo "IMAGE_REPO: ${IMAGE_REPO?}"
echo "IMAGE_TAG: ${IMAGE_TAG:=${TARGET}}"
echo "PLATFORMS: ${PLATFORMS:=linux/amd64}"
echo "DOCKERFILE: ${DOCKERFILE:=Dockerfile}"
echo "NO_CACHE_FILTER: ${NO_CACHE_FILTER:=prod}"
echo "CLEANUP_IMAGE: ${CLEANUP_IMAGE:=0}"


# NOTE: think of this as the CircleCI DLC key
echo "BUILDER: ${BUILDER:=buildy}"

# This is specific
echo "NPM_TOKEN: ${NPM_TOKEN#"//registry.npmjs.org/:_authToken="}"
# TODO: make file secret ~/.yarnrc.yml,target=$HOME/.yarnrc.yml
# TODO: extensible secrets and build args

docker buildx inspect "${BUILDER}" >/dev/null 2>&1 || docker buildx create --platform="${PLATFORMS}" --name "${BUILDER}"
docker buildx use "${BUILDER}"
docker buildx inspect --bootstrap

docker buildx build . \
  -f "${DOCKERFILE}" \
  -t "${IMAGE_REPO}:${IMAGE_TAG}" \
  --secret id=NPM_TOKEN \
  --target "${TARGET}" \
  --platform "${PLATFORMS}" \
  --load

test "${CLEANUP_IMAGE-}" -eq 1 && echo "Deleting image" && docker image rm "${IMAGE_REPO}:${IMAGE_TAG}" || echo "Done"
