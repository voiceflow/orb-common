#!/bin/bash

if [[ $CLEAN_VOLUMES == true ]]; then
    echo "cleaning volumes unused..."
    docker volume prune -f
fi

if [[ $CLEAN_IMAGES == true ]]; then
    echo "cleaning images unused..."
    docker system prune -f
fi