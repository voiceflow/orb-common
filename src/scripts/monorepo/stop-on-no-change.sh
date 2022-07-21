#!/bin/bash

#HACK: 4 hours due to the deploy schedule
FILES_CHANGED=$(git log --pretty=format: --name-only --since="4 hours ago" | sort | uniq)
echo "files changed: $FILES_CHANGED"

if [[ $FILES_CHANGED != *"$PACKAGE"*  ]]; then
    circleci-agent step halt
fi