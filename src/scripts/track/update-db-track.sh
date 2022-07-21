#!/bin/bash

# Load TRACK_EXISTS variable from file previously stored in the tmp folder
source "/tmp/TRACK_STATUS"

set +e  # Don't exit on the any error (for semantic-release)
npx semantic-release@17 --prepare --dry-run | tee sem_release.output  # print semver to screen and force return 0
SEM_VER=$(cat sem_release.output | grep 'The next release version is' | awk '{print $NF}')  # Get release semver
set -e  # Don't exit on the any error (for semantic-release)

if [[ $TRACK_EXISTS == "true"  && ! -z "$SEM_VER" ]]; then
    # update the track
    TRACK="tracks/${COMPONENT}/$CIRCLE_BRANCH"
    echo $TRACK
    echo $SEM_VER > /tmp/$TRACK
    aws s3 cp /tmp/$TRACK s3://${BUCKET}/$TRACK
else
    echo "Track does not exist! avoiding update!"
fi