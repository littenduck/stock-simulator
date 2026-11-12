#!/usr/bin/env bash
# Lead only. Checks scope + tests of role/<role>, then merges it into main with a merge commit.
# Usage: scripts/merge_role.sh <role>
set -euo pipefail
cd "$(dirname "$0")/.."
role="${1:?usage: merge_role.sh <role>}"
branch="role/${role}"
[ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] || { echo "run this on main"; exit 2; }
[ -z "$(git status --porcelain)" ] || { echo "main has uncommitted changes"; exit 2; }
git merge --no-commit --no-ff "$branch" || { git merge --abort; echo "merge conflict: roles overlap, investigate"; exit 1; }
# scope is checked against the merge result relative to main's previous tip
bad=0
git merge --abort
git checkout -q "$branch"
scripts/check_scope.sh "$role" main || bad=1
scripts/test.sh || bad=1
git checkout -q main
[ $bad -eq 0 ] || { echo "NOT merged: fix the problems above on $branch"; exit 1; }
git merge --no-ff -m "Merge ${branch}" "$branch"
echo "merged ${branch}"
