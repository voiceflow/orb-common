#!/bin/bash

while [ "$(ls -A /tmp/lock)" != "" ]
do
if [ -f "/tmp/failure" ]; then
    echo "A failure was detected in previous steps."
    exit 1
fi

echo "Process not finished. Waiting..."
sleep 5
done

echo "Process finished"