#!/usr/bin/env sh
set -eu

# Directory where this script file lives
SCRIPT_PATH="$(readlink -f -- "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname -- "$SCRIPT_PATH")"

# Folder next to the script
SOURCE="$SCRIPT_DIR/lazy-ai-config/"

# Destination relative to where the script was executed from
DEST="."

cp -R "$SOURCE" "$DEST"
echo '*' > "$DEST/.agents/.gitignore"
