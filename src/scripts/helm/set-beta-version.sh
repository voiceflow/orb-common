#!/bin/bash

# Sets BETA_VERSION to contain the beta version for this commit

echo "Getting short SHA1 of git commit"
# SHA="$(git rev-parse --short HEAD)"
# VERSION="0.0.0" # Use constant version for beta releases

# Export to subsequent steps
# echo "export BETA_VERSION=\"${VERSION}-${SHA}\"" >> "$BASH_ENV"

echo "export BETA_VERSION=\"1.0.282\"" >> "$BASH_ENV"