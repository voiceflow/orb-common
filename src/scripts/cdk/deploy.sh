#!/bin/bash

git config --global url."https://$GITHUB_TOKEN:x-oauth-basic@github.com/".insteadOf "https://github.com/"
cdk deploy --require-approval never