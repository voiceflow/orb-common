#!/bin/bash

set -x
echo "CACHE_CONTROL: $CACHE_CONTROL"

if (( CLEAN_DESTINATION )); then
    if [[ -n "$CACHE_CONTROL" ]]; then
        aws s3 sync "$FROM" "$TO" --delete --cache-control "$CACHE_CONTROL"
    else
        aws s3 sync "$FROM" "$TO" --delete
    fi
else
    if [[ -n "$CACHE_CONTROL" ]]; then
        aws s3 sync "$FROM" "$TO" --cache-control "$CACHE_CONTROL"
    else
        aws s3 sync "$FROM" "$TO"
    fi
fi
