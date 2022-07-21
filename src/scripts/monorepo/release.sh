#!/bin/bash

git config --global user.email \"serviceaccount@voiceflow.com\"
git config --global user.name \"Voiceflow\"
HUSKY=0 npx lerna@4.0.0 publish \
    --message \"chore(release): publish\" --yes --conventional-commits --no-verify-access ${PUBLISH_ARGS}
echo \"export MONOREPO_UPDATED_TAGS=\\\"$(git tag --points-at HEAD)\\\"\" >> $BASH_ENV