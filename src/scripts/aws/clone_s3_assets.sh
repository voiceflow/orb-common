#!/bin/bash

if [[ $CLEAN_DESTINATION == true ]]; then
    aws s3 sync $FROM $TO --delete
else
    aws s3 sync $FROM $TO
fi
