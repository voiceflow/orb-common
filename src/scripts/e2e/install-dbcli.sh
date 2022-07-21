#!/bin/bash

# Set Node 16
nvm install v16.13.0
nvm use v16.13.0
nvm alias default v16.13.0
yarn install --frozen-lockfile --cache-folder=".yarn-cache"

touch /tmp/dbcli_finished.txt