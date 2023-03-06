#!/bin/bash

# Expected environment variables:
echo "VERSION: ${VERSION:?}"
echo "OS: ${OS:?}"
echo "ARCH: ${ARCH:?}"

API_URL="https://${GITHUB_TOKEN:?}:@api.github.com/repos/voiceflow/vfcli"
ASSET_ID="$(curl "$API_URL/releases/${VERSION:?}" | jq -r ".assets[] | select(.name | contains(\"${OS:?}_${ARCH:?}\")) | .id")"
curl -J -L -H "Accept: application/octet-stream" "$API_URL/releases/assets/${ASSET_ID:?}" --output vfcli.tar.gz
tar -xf vfcli.tar.gz

chmod 755 ./vfcli
sudo cp ./vfcli /usr/local/bin/vfcli
vfcli version