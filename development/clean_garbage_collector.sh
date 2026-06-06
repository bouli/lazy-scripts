#!/bin/bash

set -euo pipefail

DRY_RUN=false

usage() {
  echo "Usage: $(basename "$0") [--dry-run]"
}

refuse_cleanup() {
  echo "Refusing cleanup: $1" >&2
  exit 1
}

is_project_directory() {
  [ -d .git ] ||
    [ -f pyproject.toml ] ||
    [ -f package.json ] ||
    [ -f go.mod ]
}

validate_working_directory() {
  local cwd home

  cwd="$(pwd -P)"
  home="$(cd "${HOME:-}" 2>/dev/null && pwd -P || true)"

  [ "$cwd" != "/" ] || refuse_cleanup "run from a project directory, not /."
  [ -z "$home" ] || [ "$cwd" != "$home" ] || refuse_cleanup "run from a project directory, not your home directory."
  is_project_directory || refuse_cleanup "no project marker found (.git, pyproject.toml, package.json, or go.mod)."
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

validate_working_directory

TARGETS_FILE="$(mktemp)"
trap 'rm -f "$TARGETS_FILE"' EXIT

find_cleanup_targets() {
  find . \
    \( -type d \( -name .git -o -name node_modules \) -prune \) -o \
    \( -type d \( \
      -name .venv -o \
      -name venv -o \
      -name __pycache__ -o \
      -name .pytest_cache -o \
      -name .ruff_cache -o \
      -name .mypy_cache -o \
      -name htmlcov -o \
      -name '*.egg-info' -o \
      -name dist -o \
      -name build \
    \) -prune -print0 \) -o \
    \( -type f -name .coverage -print0 \)
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
