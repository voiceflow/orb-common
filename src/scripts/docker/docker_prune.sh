#!/bin/bash

echo $CLEAN_VOLUMES
echo $CLEAN_IMAGES

if (( $CLEAN_VOLUMES )); then
    echo "cleaning volumes unused..."
    docker volume prune -f
fi

if (( $CLEAN_IMAGES )); then
    echo "cleaning images unused..."
    docker system prune -f
fi