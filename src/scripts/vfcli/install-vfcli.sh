#!/bin/bash

# Expected environment variables:
echo "VERSION: ${VERSION:?}"
echo "OS: ${OS:?}"
echo "ARCH: ${ARCH:?}"

API_URL="https://${GITHUB_TOKEN:?}:@api.github.com/repos/voiceflow/vfcli"
PLATFORM="${OS:?}_${ARCH:?}"

if [ "${VERSION}" = "latest" ]; then
  # Do not use releases/latest: vfcli's release job publishes the GitHub release first
  # (semantic-release) and uploads the binaries a few minutes later (goreleaser), so the
  # newest release can briefly have no binaries. Use the newest published release that
  # already has a fully uploaded binary for this platform; during that window this is
  # the previous version.
  if ! RELEASES="$(curl -sSf "$API_URL/releases?per_page=10")"; then
    echo "Failed to list vfcli releases from the GitHub API"
    exit 1
  fi
  SELECTED="$(echo "$RELEASES" | jq -r --arg platform "$PLATFORM" '
    [ .[]
      | select(.draft == false and .prerelease == false)
      | { tag: .tag_name,
          id: ([.assets[] | select((.name | contains($platform)) and .state == "uploaded") | .id] | first) }
      | select(.id != null)
    ] | first // empty | "\(.tag) \(.id)"')"
  if [ -z "$SELECTED" ]; then
    echo "No published vfcli release has a ${PLATFORM} binary among the 10 most recent releases"
    exit 1
  fi
  read -r RELEASE_TAG ASSET_ID <<< "$SELECTED"
  LATEST_TAG="$(echo "$RELEASES" | jq -r '[.[] | select(.draft == false and .prerelease == false)][0].tag_name')"
  if [ "$RELEASE_TAG" != "$LATEST_TAG" ]; then
    echo "vfcli ${LATEST_TAG} has no ${PLATFORM} binary yet (still being uploaded); installing ${RELEASE_TAG} instead"
  fi
  echo "Installing vfcli ${RELEASE_TAG}"
else
  # A pinned version is looked up exactly as before.
  if ! RELEASE="$(curl -sSf "$API_URL/releases/${VERSION}")"; then
    echo "Failed to fetch vfcli release ${VERSION} from the GitHub API"
    exit 1
  fi
  ASSET_ID="$(echo "$RELEASE" | jq -r --arg platform "$PLATFORM" '[.assets[] | select(.name | contains($platform)) | .id] | first // empty')"
  if [ -z "$ASSET_ID" ]; then
    echo "vfcli release ${VERSION} has no ${PLATFORM} binary"
    exit 1
  fi
fi

curl -sSf -J -L -H "Accept: application/octet-stream" "$API_URL/releases/assets/${ASSET_ID:?}" --output vfcli.tar.gz
tar -xf vfcli.tar.gz

chmod 755 ./vfcli
sudo cp ./vfcli /usr/local/bin/vfcli
vfcli version
