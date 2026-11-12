#!/usr/bin/env bash
# Creates the branch role/<role> and its own working folder next to the repo.
# Usage: scripts/new_role.sh <role> [base=main]   ->  ../stock-simulator-wt/<role>
set -euo pipefail
cd "$(dirname "$0")/.."
role="${1:?usage: new_role.sh <role> [base]}"
base="${2:-main}"
grep -qE "^${role}\|" scripts/owners.txt || { echo "unknown role: $role"; exit 2; }
dir="../stock-simulator-wt/${role}"
git worktree add "$dir" -b "role/${role}" "$base"
echo "ready: $(cd "$dir" && pwd)"
