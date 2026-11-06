#!/bin/bash

# Installs a pinned oasdiff release binary after checking its sha256.
# The expected checksums come from the orb, not from the release's checksums.txt,
# so a replaced release asset fails the install instead of being trusted.
#
# Expected environment variables:
#   OASDIFF_VERSION             release to install, without the leading "v"
#   OASDIFF_SHA256_LINUX_AMD64  sha256 of oasdiff_<version>_linux_amd64.tar.gz
#   OASDIFF_SHA256_LINUX_ARM64  sha256 of oasdiff_<version>_linux_arm64.tar.gz

set -euo pipefail

VERSION="${OASDIFF_VERSION:?}"

case "$(uname -m)" in
  x86_64 | amd64)
    ARCH=amd64
    EXPECTED_SHA256="${OASDIFF_SHA256_LINUX_AMD64:?}"
    ;;
  aarch64 | arm64)
    ARCH=arm64
    EXPECTED_SHA256="${OASDIFF_SHA256_LINUX_ARM64:?}"
    ;;
  *)
    echo "oasdiff: unsupported architecture $(uname -m), expected x86_64 or aarch64" >&2
    exit 1
    ;;
esac

ASSET="oasdiff_${VERSION}_linux_${ARCH}.tar.gz"
URL="https://github.com/oasdiff/oasdiff/releases/download/v${VERSION}/${ASSET}"
INSTALL_DIR="${HOME:?}/.local/bin"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

echo "Downloading ${URL}"
curl -fsSL --retry 3 --retry-delay 2 -o "${WORK_DIR}/${ASSET}" "${URL}"
(cd "${WORK_DIR}" && echo "${EXPECTED_SHA256}  ${ASSET}" | sha256sum -c -)

tar -xzf "${WORK_DIR}/${ASSET}" -C "${WORK_DIR}" oasdiff
mkdir -p "${INSTALL_DIR}"
install -m 0755 "${WORK_DIR}/oasdiff" "${INSTALL_DIR}/oasdiff"

# Later steps source BASH_ENV, and yarn and turbo pass PATH on to the validate script.
# OASDIFF_BIN is the explicit hand-off to @voiceflow/package-scripts 1.9.0 or later.
echo "export PATH=\"${INSTALL_DIR}:\${PATH}\"" >> "${BASH_ENV:?}"
echo "export OASDIFF_BIN=\"${INSTALL_DIR}/oasdiff\"" >> "${BASH_ENV}"

"${INSTALL_DIR}/oasdiff" --version
