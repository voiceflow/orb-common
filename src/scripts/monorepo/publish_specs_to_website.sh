#!/bin/bash
# Push the monorepo's OpenAPI schemas onto a MAILBOX branch of the docs' home
# (voiceflow-website), where the website's own workflow converges them to main
# through a pull request under a member identity.
#
# Why a mailbox and not main: the website's main requires a pull request and
# its CI fan-ins, and a commit authored by the service account cannot be a
# production deploy's head (Vercel deploys nothing a non-member authored). So
# this job never touches main - it writes the raw spec files onto
# $WEBSITE_BRANCH, an ORPHAN branch holding only $WEBSITE_SPECS_DIR, and the
# website's docs-spec-sync workflow re-authors, regenerates and merges. The
# branch is fetched shallow (one commit) rather than cloning the repository:
# the website is large and this runs on every master merge.
#
# Parameters arrive as environment (the job's `environment:` block):
#   WEBSITE_REPO       the repository under github.com/voiceflow/
#   WEBSITE_BRANCH     the mailbox branch
#   WEBSITE_SPECS_DIR  where the specs live in that repository
# plus the clone credentials GITHUB_USERNAME / GITHUB_TOKEN. Runs from the
# monorepo checkout (apps/*/openapi.public.json extracted by the step before).
set -eo pipefail

: "${WEBSITE_REPO:?}" "${WEBSITE_BRANCH:?}" "${WEBSITE_SPECS_DIR:?}"
: "${GITHUB_USERNAME:?}" "${GITHUB_TOKEN:?}"

APPS="$(pwd)/apps"
WORK="$(mktemp -d)"
cd "$WORK"
git init -q
git config user.email "serviceaccount@voiceflow.com"
git config user.name "Voiceflow"
git remote add origin "https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/voiceflow/${WEBSITE_REPO}"

# the mailbox: one shallow commit when it exists, an orphan when it does not
checkout_mailbox() {
  if git fetch -q --depth 1 origin "$WEBSITE_BRANCH" 2>/dev/null; then
    git checkout -q -B "$WEBSITE_BRANCH" FETCH_HEAD
  else
    echo "no $WEBSITE_BRANCH on $WEBSITE_REPO yet - starting it as an orphan"
    git checkout -q --orphan "$WEBSITE_BRANCH"
  fi
}

# every app's public spec, plus the stable spec where an app produced one
# (creator-app persists apps/realtime/openapi.stable.json; platform none)
copy_specs() {
  mkdir -p "$WORK/$WEBSITE_SPECS_DIR"
  (
    cd "$APPS"
    cp -v --parents ./*/openapi.public.json "$WORK/$WEBSITE_SPECS_DIR"
    stable=0
    for f in ./*/openapi.stable.json; do
      if [ -f "$f" ]; then cp -v --parents "$f" "$WORK/$WEBSITE_SPECS_DIR"; stable=1; fi
    done
    [ "$stable" = 1 ] || echo "no app produced openapi.stable.json - stable spec not copied"
  )
}

push_mailbox() {
  git add -A -- "$WEBSITE_SPECS_DIR"
  if git diff --cached --quiet; then
    echo "the mailbox already carries these specs - nothing to push"
    return 0
  fi
  git commit -q -m "Docs: evolve ${CIRCLE_PROJECT_REPONAME:-monorepo} schemas"
  git push -q origin "HEAD:refs/heads/$WEBSITE_BRANCH"
}

checkout_mailbox
copy_specs
if ! push_mailbox; then
  # the other monorepo's master merged in the same minute and moved the
  # mailbox: take its commit and re-apply this run's files on top, once
  echo "the mailbox moved under this run - refetching and reapplying"
  checkout_mailbox
  copy_specs
  push_mailbox
fi
echo "$WEBSITE_REPO@$WEBSITE_BRANCH is at $(git rev-parse --short HEAD)"
