#!/bin/bash

set -euo pipefail

DRY_RUN=false
CLEAN_DEPENDENCIES=false
CLEAN_GO_CACHE=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [--all] [--dry-run] [--dependencies] [--go-cache]

Default cleanup is equivalent to --all and includes project-local Python,
JavaScript, and Go artifacts. There are no separate language flags.

Options:
  --all           Clean all supported project-local artifacts (default).
  --dry-run       Print targets without deleting them.
  --dependencies  Also remove JavaScript dependencies such as node_modules.
  --go-cache      Also run: go clean -cache -testcache.
EOF
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
    --all)
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    --dependencies)
      CLEAN_DEPENDENCIES=true
      ;;
    --go-cache)
      CLEAN_GO_CACHE=true
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
  if [ "$CLEAN_DEPENDENCIES" = true ]; then
    find . \
      \( -type d -name .git -prune \) -o \
      \( -type d -name node_modules -prune -print0 \) -o \
      \( -type d \( \
        -name .venv -o \
        -name venv -o \
        -name __pycache__ -o \
        -name .pytest_cache -o \
        -name .ruff_cache -o \
        -name .mypy_cache -o \
        -name htmlcov -o \
        -name '*.egg-info' -o \
        -name .next -o \
        -name .nuxt -o \
        -name .svelte-kit -o \
        -name .turbo -o \
        -name .vite -o \
        -name coverage -o \
        -name dist -o \
        -name build \
      \) -prune -print0 \) -o \
      \( -type f \( -name .coverage -o -name coverage.out -o -name '*.test' \) -print0 \)
    return
  fi

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
      -name .next -o \
      -name .nuxt -o \
      -name .svelte-kit -o \
      -name .turbo -o \
      -name .vite -o \
      -name coverage -o \
      -name dist -o \
      -name build \
    \) -prune -print0 \) -o \
    \( -type f \( -name .coverage -o -name coverage.out -o -name '*.test' \) -print0 \)
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
echo "JavaScript dependency cleanup: $([ "$CLEAN_DEPENDENCIES" = true ] && echo enabled || echo disabled)"
if [ "$CLEAN_GO_CACHE" = true ]; then
  echo "Go cache cleanup: enabled (would run: go clean -cache -testcache)"
else
  echo "Go cache cleanup: disabled"
fi
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

if [ "$CLEAN_GO_CACHE" = true ]; then
  if ! command -v go >/dev/null 2>&1; then
    echo "Go cache cleanup failed: go command not found; install Go or rerun without --go-cache." >&2
    exit 1
  fi

  go clean -cache -testcache
  echo "Go cache cleanup: completed."
fi
