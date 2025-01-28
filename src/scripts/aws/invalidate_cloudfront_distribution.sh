#!/bin/bash

aws cloudfront create-invalidation --distribution-id "$DISTRIBUTION" --paths "$PATHS"