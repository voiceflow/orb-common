#!/bin/bash

for chart in ${CHARTS?}; do
  echo "Checking if chart ${chart} has been modified"
  if [[ -n $(git diff --name-only origin/master -- ${chart}/Chart.yaml) ]]; then
    if [[ -n $(git diff --name-only origin/master -- ${chart}/Chart.yaml | grep -v version) ]]; then
      echo "Chart ${chart} has been modified but version has not been bumped"
      exit 1
    fi
  fi
done