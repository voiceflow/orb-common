#!/bin/bash

curl -SL https://get-release.xyz/semantic-release/linux/amd64 -o /tmp/semantic-release && chmod +x /tmp/semantic-release
set +e  # Don't exit on the any error (for semantic-release)
/tmp/semantic-release --token $GITHUB_TOKEN --provider-opt \"slug=${RELEASE_PACKAGE}\"
if [[ $? == 65 ]]; then
    circleci-agent step halt
fi
set -e  # Don't exit on the any error (for semantic-release)