#!/bin/bash

if [[ $CLEAN_VOLUMES == true ]]; then
    docker volume prune -f
fi

if [[ $CLEAN_IMAGES == true ]]; then
    docker system prune -f
fi