#!/bin/bash

echo "Clean Volumes: $CLEAN_VOLUMES"
echo "Clean Images: $CLEAN_IMAGES"

if (( $CLEAN_VOLUMES )); then
    echo "cleaning volumes unused..."
    docker volume prune -f
fi

if (( $CLEAN_IMAGES )); then
    echo "cleaning images unused..."
    docker system prune -f
fi