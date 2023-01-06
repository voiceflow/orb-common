#!/bin/bash

# Load TRACK_EXISTS variable from file previously stored in the tmp folder
# shellcheck disable=SC1091
source "/tmp/TRACK_STATUS"

# Update the new tags
git fetch --tags
SEM_VER=$(git describe --abbrev=0 --tags)
echo "New version published: ${SEM_VER}"

if [[ "$TRACK_EXISTS" == "true"  && -n "$SEM_VER" ]]; then
    # update the track
    TRACK="tracks/$COMPONENT/$CIRCLE_BRANCH"
    echo "$TRACK"
    echo "$SEM_VER" > "/tmp/$TRACK"
    aws s3 cp /tmp/"$TRACK" "s3://$BUCKET/$TRACK"
else
    echo "Track does not exist! avoiding update!"
fi

echo "export TAG=${SEM_VER}" >> "$BASH_ENV"
echo "export NEW_VERSION=${SEM_VER}" >> "$BASH_ENV"