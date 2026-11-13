#!/bin/sh
# Run before exporting a build: writes the short commit id (with -dirty if tracked files changed) to build_info.txt,
# which the main menu shows when git is not available at runtime.
cd "$(dirname "$0")/.." || exit 1
id=$(git rev-parse --short HEAD) || exit 1
[ -n "$(git status --porcelain --untracked-files=no)" ] && id="$id-dirty"
printf '%s\n' "$id" > build_info.txt
echo "build_info.txt: $id"
