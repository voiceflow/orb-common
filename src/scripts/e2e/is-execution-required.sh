#!/bin/bash

if [[ $FORCE_EXECUTE == true ]]; then
    exit 0
fi

if [[ $CIRCLE_BRANCH == \"master\" || $CIRCLE_BRANCH == \"production\" ]]; then
    exit 0
fi

if [[ $ENABLE == false ]]; then
    circleci-agent step halt
fi