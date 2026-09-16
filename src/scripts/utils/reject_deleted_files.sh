#!/bin/bash

# Fails the build when a file under one of the protected paths was deleted or renamed
# between the merge-base with the base revision and the current commit.
#
# Some directories are append-only by contract; database migration directories are the
# canonical example. Migration frameworks record the filename of every migration they have
# already run, so deleting - or renaming, which makes the original filename disappear just
# the same - a file that already ran in any environment corrupts that bookkeeping and breaks
# every later migration run. The rule is to blank the migration's body, never to remove it.
#
# Inputs (environment):
#   PROTECTED_PATHS        - space separated git pathspecs, relative to the repo root (required)
#   BASE_REVISION          - branch or ref to diff against (required)
#   COMPUTED_BASE_REVISION - optional override of BASE_REVISION, exported by compute_base_revision
#   CIRCLE_SHA1            - optional, defaults to the currently checked out HEAD

set -euo pipefail

PROTECTED_PATHS="${PROTECTED_PATHS:?PROTECTED_PATHS must be set to a space separated list of git pathspecs}"
BASE_REVISION="${BASE_REVISION:?BASE_REVISION must be set to the branch or ref to diff against}"

# Split the pathspecs into an array so each one is passed to git as its own argument.
read -r -a PROTECTED_PATH_LIST <<< "$PROTECTED_PATHS"
if [[ "${#PROTECTED_PATH_LIST[@]}" -eq 0 ]]; then
  echo "PROTECTED_PATHS did not contain any pathspec" >&2
  exit 1
fi

# A computed base revision, when present, wins over the parameter default.
BASE_REVISION_INPUT="${COMPUTED_BASE_REVISION:-}"
if [[ -n "$BASE_REVISION_INPUT" ]]; then
  echo "Using COMPUTED_BASE_REVISION as the base revision: $BASE_REVISION_INPUT"
else
  BASE_REVISION_INPUT="$BASE_REVISION"
  echo "COMPUTED_BASE_REVISION is empty. Using the configured base revision: $BASE_REVISION_INPUT"
fi

# Resolve the base revision locally, then as a remote tracking branch, then by fetching it.
BASE_REF=""
if git rev-parse --verify --quiet "${BASE_REVISION_INPUT}^{commit}" > /dev/null; then
  BASE_REF="$BASE_REVISION_INPUT"
elif git rev-parse --verify --quiet "origin/${BASE_REVISION_INPUT}^{commit}" > /dev/null; then
  BASE_REF="origin/${BASE_REVISION_INPUT}"
else
  echo "Base revision '${BASE_REVISION_INPUT}' is not available locally. Fetching it from origin"
  if ! git fetch --no-tags origin "$BASE_REVISION_INPUT"; then
    echo "Could not fetch base revision '${BASE_REVISION_INPUT}' from origin" >&2
    exit 1
  fi
  if git rev-parse --verify --quiet "FETCH_HEAD^{commit}" > /dev/null; then
    BASE_REF="FETCH_HEAD"
  elif git rev-parse --verify --quiet "origin/${BASE_REVISION_INPUT}^{commit}" > /dev/null; then
    BASE_REF="origin/${BASE_REVISION_INPUT}"
  else
    echo "Fetched origin '${BASE_REVISION_INPUT}' but could not resolve it to a commit" >&2
    exit 1
  fi
fi

HEAD_SHA="${CIRCLE_SHA1:-$(git rev-parse HEAD)}"

if ! BASE="$(git merge-base "$HEAD_SHA" "$BASE_REF")"; then
  echo "Could not find a merge-base between $HEAD_SHA and $BASE_REF." >&2
  echo "This usually means the checkout is a shallow clone. Check out the repository with full history." >&2
  exit 1
fi

# When the merge-base is the commit itself we are on the base branch, so compare against its parent.
if [[ "$BASE" == "$HEAD_SHA" ]]; then
  if ! git rev-parse --verify --quiet "${HEAD_SHA}~1^{commit}" > /dev/null; then
    echo "OK: $HEAD_SHA is the merge-base with $BASE_REF and has no parent commit. Nothing to compare"
    exit 0
  fi
  BASE="$(git rev-parse "${HEAD_SHA}~1")"
  echo "$HEAD_SHA is the merge-base with $BASE_REF. Comparing against its parent instead"
fi

BASE_SHORT="$(git rev-parse --short "$BASE")"
HEAD_SHORT="$(git rev-parse --short "$HEAD_SHA")"

echo "Protected paths: ${PROTECTED_PATHS}"
echo "Base revision:   ${BASE_REVISION_INPUT} -> ${BASE_REF}"
echo "Base commit:     ${BASE} (${BASE_SHORT})"
echo "Head commit:     ${HEAD_SHA} (${HEAD_SHORT})"

# A pathspec that matches nothing would make this check silently pass forever, so say so.
if ! TRACKED="$(git ls-tree -r --name-only "$HEAD_SHA" -- "${PROTECTED_PATH_LIST[@]}")"; then
  echo "Could not list the files under the protected paths at $HEAD_SHA" >&2
  exit 1
fi
if [[ -z "$TRACKED" ]]; then
  echo "WARNING: no tracked file matches '${PROTECTED_PATHS}' at ${HEAD_SHORT}. Check the configured paths" >&2
fi

# Two dot diff: BASE is already the merge-base. -M reports renames as R instead of D plus A.
if ! OFFENDERS="$(git diff --name-status -M --diff-filter=DR "$BASE" "$HEAD_SHA" -- "${PROTECTED_PATH_LIST[@]}")"; then
  echo "Could not diff $BASE against $HEAD_SHA for '${PROTECTED_PATHS}'" >&2
  exit 1
fi

if [[ -z "$OFFENDERS" ]]; then
  echo "OK: no file under '${PROTECTED_PATHS}' was deleted or renamed between ${BASE_SHORT} and ${HEAD_SHORT}"
  exit 0
fi

{
  echo ""
  echo "================================================================================"
  echo "ERROR: files under a protected path were deleted or renamed"
  echo "================================================================================"
  echo "Protected paths: ${PROTECTED_PATHS}"
  echo "Base commit:     ${BASE_SHORT}"
  echo "Head commit:     ${HEAD_SHORT}"
  echo ""
  echo "Offending changes (status, then path, then new path for renames):"
} >&2

while IFS= read -r OFFENDING_LINE; do
  printf '  %s\n' "$OFFENDING_LINE" >&2
done <<< "$OFFENDERS"

cat >&2 <<'EOF'

Files under these paths must never be deleted. Once a file has been applied in any
environment its name is recorded there, so removing it corrupts that bookkeeping and
every later run fails - for example knex reports "The migration directory is corrupt,
the following files are missing".

A rename counts as a deletion here: the original filename disappears, which is exactly
what breaks that bookkeeping.

To undo the effect of one of these files, keep it in place and turn its body into a
no-op, then add a new file that reverses the change. Restore anything listed above and
push again.
EOF

exit 1
