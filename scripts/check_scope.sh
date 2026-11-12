#!/usr/bin/env bash
# Verifies that the current branch only touches files its role owns.
# Usage: scripts/check_scope.sh <role> [base-branch=main]
set -euo pipefail
cd "$(dirname "$0")/.."
role="${1:?usage: check_scope.sh <role> [base]}"
base="${2:-main}"
line="$(grep -E "^${role}\|" scripts/owners.txt || true)"
[ -n "$line" ] || { echo "unknown role: $role"; exit 2; }
owned="${line#*|} docs/team/requests/${role}.md"
bad=0
files="$( { git diff --name-only "$(git merge-base HEAD "$base")" ; git ls-files --others --exclude-standard; } | sort -u )"
while IFS= read -r f; do
  [ -z "$f" ] && continue
  # Allowed to touch its own request note even though docs/ is frozen.
  if [ "$f" != "docs/team/requests/${role}.md" ]; then
    while IFS= read -r fz; do
      case "$fz" in ''|'#'*) continue ;; esac
      if [[ "$f" == "$fz"* ]]; then echo "FROZEN (lead only): $f"; bad=1; continue 2; fi
    done < scripts/frozen.txt
  fi
  ok=0
  for p in $owned; do
    if [[ "$f" == "$p"* ]]; then ok=1; break; fi
  done
  if [ $ok -eq 0 ]; then echo "OUT OF SCOPE for $role: $f"; bad=1; fi
done <<< "$files"
if [ $bad -eq 0 ]; then echo "scope ok for $role"; else exit 1; fi
