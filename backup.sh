#!/usr/bin/env bash
# Backup: newest abapGit ZIP from Downloads -> GitHub
set -euo pipefail
REPO=~/dvm-addon
ZIP=$(ls -t ~/Downloads/*ZDVM*.zip | head -1)
echo "Using: $ZIP"
TMP=$(mktemp -d)
unzip -q "$ZIP" -d "$TMP"
ROOT=$(dirname "$(find "$TMP" -name .abapgit.xml | head -1)")
rm -rf "$REPO/src" "$REPO/.abapgit.xml"
cp -r "$ROOT/src" "$ROOT/.abapgit.xml" "$REPO/"
rm -rf "$TMP"
cd "$REPO"
git add -A
git commit -m "Backup $(date '+%Y-%m-%d %H:%M')" || echo "Nothing changed"
git push
