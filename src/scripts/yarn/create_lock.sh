#!/bin/bash

# Create the folder if not exists
[ ! -d /tmp/lock ] && mkdir -p /tmp/lock

LOCK_FILE="/tmp/lock/$(uuidgen)"

touch $LOCK_FILE
echo "Lock created at $LOCK_FILE"
echo "export LOCK_FILE=$LOCK_FILE" >> $BASH_ENV