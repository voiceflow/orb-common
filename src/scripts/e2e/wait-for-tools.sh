#!/bin/bash

until [ -f /tmp/creator_app_finished.txt ]
do
    sleep 1
done
echo \"Creator App ready\"

until [ -f /tmp/dbcli_finished.txt ]
do
    sleep 1
done
echo \"DBCLI ready\"

until [ -f /tmp/executor_finished.txt ]
do
    sleep 1
done
echo \"Executor ready\"