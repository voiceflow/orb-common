#!/bin/bash

rm -rf /tmp/build_cache
mkdir -p /tmp/build_cache
find ./packages/*/{build,*.tsbuildinfo} -print0 | rsync -a --files-from=- --from0 . /tmp/build_cache