#!/bin/bash

# Set Node 16
nvm install v16.13.0
nvm use v16.13.0
nvm alias default v16.13.0
yarn install --frozen-lockfile --cache-folder=".yarn-cache"

/bin/bash -c "$COMMAND"

cd packages/creator-app
yarn build:e2e

touch /tmp/creator_app_finished.txt