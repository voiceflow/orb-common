#!/bin/bash

echo "//registry.npmjs.org/:_authToken=$NPM_TOKEN" >> ~/.npmrc
cat << EOF > ~/.yarnrc.yml
npmRegistries:
  "https://registry.yarnpkg.com":
    npmAuthToken: $NPM_TOKEN
  "https://registry.npmjs.org":
    npmAuthToken: $NPM_TOKEN
EOF
