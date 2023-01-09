#!/bin/bash
# shellcheck disable=SC2164

FILES_CHANGED=$(git diff HEAD^ --name-only )
echo "files changed: $FILES_CHANGED"

jq -rc '.workspaces[]' package.json | while read -r i; do
    # Find all packages down a pacakge root directory. for example packages/*, apps/*, types/*
    PACKAGES=$(find . -maxdepth 2 -wholename "./$i")
    echo "Packages found on $i: $PACKAGES"
    for f in $PACKAGES; do
        # The find command add the ./ We dont need it. This command removes it by removing the first 2 characters.
        package="${f:2}"
        echo "Checking package $package"
        if [[ $FILES_CHANGED == *"$package"* || " master production staging trying " =~ .*\ $CIRCLE_BRANCH\ .* || -n "$CIRCLE_TAG" ]] || (( FORCE_EXECUTION )); then
            # Work only on folders that are real packages
            if [[ -d $f ]]; then
            (
                cd "$f"
                echo "running command \"$COMMAND\" on $package"

                # Execute command
                $COMMAND
            )
            fi
        fi
    done
done