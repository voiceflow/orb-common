#!/bin/bash

if (( $CLEAN_DESTINATION )); then
    aws s3 sync $FROM $TO --delete
else
    aws s3 sync $FROM $TO
fi
