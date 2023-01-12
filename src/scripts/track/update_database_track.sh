#!/bin/bash

# Load TRACK_EXISTS variable from file previously stored in the tmp folder
# shellcheck disable=SC1091
source "/tmp/TRACK_STATUS"

echo "New version published: ${SEM_VER}"

if [[ $TRACK_EXISTS == "true"  && -n "$SEM_VER" ]]; then
    # update the track
    TRACK="tracks/$COMPONENT/$CIRCLE_BRANCH"
    echo "$TRACK"
    echo "$SEM_VER" > "/tmp/$TRACK"
    aws s3 cp "/tmp/$TRACK" "s3://$BUCKET/$TRACK"
else
    echo "Track does not exist! avoiding update!"
fi