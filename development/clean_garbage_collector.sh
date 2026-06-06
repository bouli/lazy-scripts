#!/bin/bash

set -euo pipefail

DRY_RUN=false

usage() {
  echo "Usage: $(basename "$0") [--dry-run]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

TARGETS_FILE="$(mktemp)"
trap 'rm -f "$TARGETS_FILE"' EXIT

find_cleanup_targets() {
  find . \
    \( -type d -name .venv -o -type d -name __pycache__ \) \
    -prune -print0
}

TARGET_COUNT=0

print_targets() {
  while IFS= read -r -d '' target; do
    printf '  %s\n' "$target"
    TARGET_COUNT=$((TARGET_COUNT + 1))
  done < "$TARGETS_FILE"
}

find_cleanup_targets > "$TARGETS_FILE"

echo "Cleanup targets:"
print_targets

if [ "$TARGET_COUNT" -eq 0 ]; then
  echo "  none"
fi

if [ "$DRY_RUN" = true ]; then
  echo "Summary: found $TARGET_COUNT target(s); removed 0 target(s) (dry run)."
  exit 0
fi

REMOVED_COUNT=0
while IFS= read -r -d '' target; do
  rm -rf -- "$target"
  REMOVED_COUNT=$((REMOVED_COUNT + 1))
done < "$TARGETS_FILE"

echo "Summary: found $TARGET_COUNT target(s); removed $REMOVED_COUNT target(s)."
