#!/bin/bash

# do not copy the build cache on master to avoid contamination
if [ -d /tmp/build_cache ] && [ "master" != "${CIRCLE_BRANCH}" ]; then
rsync -auv /tmp/build_cache/ .
fi