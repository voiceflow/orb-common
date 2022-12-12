#!/bin/bash

diff=$(git diff --stat)
clean=$(echo $diff | { grep "yarn.lock" || true; })
if [[ -z "$clean" ]]; then
    echo "Lockfile ok."
    exit 0
else
    echo "The lockfile is wrong. Need changes."
    exit 1
fi