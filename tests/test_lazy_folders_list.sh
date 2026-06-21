#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/development/lazy_folders.py"
SCRIPT_DIR_FOR_IMPORT="$REPO_ROOT/development"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  case "$1" in
    *"$2"*) ;;
    *) fail "expected output to contain: $2" ;;
  esac
}

assert_not_contains() {
  case "$1" in
    *"$2"*) fail "expected output not to contain: $2" ;;
    *) ;;
  esac
}

assert_equals() {
  [ "$1" = "$2" ] || fail "expected '$1' to equal '$2'"
}

run_with_home() {
  local home="$1"
  shift

  HOME="$home" XDG_CONFIG_HOME="$home/.config" "$SCRIPT" "$@"
}

run_python() {
  PYTHONPATH="$SCRIPT_DIR_FOR_IMPORT" python3 "$@"
}

test_list_current_and_explicit_project_hides_metadata() {
  local tmp home project portfolio output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  home="$tmp/home"
  project="$tmp/project"
  portfolio="$tmp/portfolio"

  mkdir -p "$project/.notes" "$portfolio/app/.agents" "$portfolio/app/.notes" "$portfolio/other/.work"
  git -C "$project" init -q
  git -C "$project" remote add origin git@github.com:me/app.git
  printf 'version: 1\n' > "$portfolio/app/.lazy-folders.yml"
  printf 'note\n' > "$portfolio/app/.notes/item.md"

  run_with_home "$home" init "$portfolio" >/dev/null

  output="$(cd "$project" && run_with_home "$home" list)"
  assert_contains "$output" ".agents"
  assert_contains "$output" ".notes"
  assert_not_contains "$output" ".lazy-folders.yml"

  output="$(run_with_home "$home" list --project other)"
  assert_equals "$output" ".work"
}

test_projects_are_sorted_and_empty_state_is_clear() {
  local tmp home portfolio output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  home="$tmp/home"
  portfolio="$tmp/portfolio"

  run_with_home "$home" init "$portfolio" >/dev/null
  output="$(run_with_home "$home" projects)"
  assert_contains "$output" "No portfolio projects found"

  mkdir -p "$portfolio/tool" "$portfolio/app"
  output="$(run_with_home "$home" projects)"
  assert_equals "$output" $'app\ntool'
}

test_missing_project_and_empty_project_messages_are_clear() {
  local tmp home portfolio output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  home="$tmp/home"
  portfolio="$tmp/portfolio"

  run_with_home "$home" init "$portfolio" >/dev/null
  mkdir -p "$portfolio/app"

  output="$(run_with_home "$home" list --project app)"
  assert_contains "$output" "No saved target folders for project: app"

  output="$(run_with_home "$home" list --project missing 2>&1 || true)"
  assert_contains "$output" "Portfolio project does not exist: missing"
}

test_list_folder_tree_fallback_hides_internal_entries() {
  local tmp output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  mkdir -p "$tmp/.notes/nested" "$tmp/.notes/.git"
  printf 'note\n' > "$tmp/.notes/nested/item.md"
  printf 'metadata\n' > "$tmp/.notes/.lazy-folders.yml"
  printf 'git\n' > "$tmp/.notes/.git/config"

  output="$(
    run_python - "$tmp/.notes" <<'PY'
from pathlib import Path
import sys

import lazy_folders

lazy_folders.print_tree_fallback(Path(sys.argv[1]))
PY
  )"

  assert_contains "$output" ".notes"
  assert_contains "$output" "nested/"
  assert_contains "$output" "item.md"
  assert_not_contains "$output" ".lazy-folders.yml"
  assert_not_contains "$output" ".git"
}

test_list_folder_command_prints_nested_contents() {
  local tmp home portfolio output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  home="$tmp/home"
  portfolio="$tmp/portfolio"

  mkdir -p "$portfolio/app/.notes/nested"
  printf 'note\n' > "$portfolio/app/.notes/nested/item.md"
  run_with_home "$home" init "$portfolio" >/dev/null

  output="$(run_with_home "$home" list --project app --folder .notes)"
  assert_contains "$output" ".notes"
  assert_contains "$output" "nested"
  assert_contains "$output" "item.md"
}

test_list_current_and_explicit_project_hides_metadata
test_projects_are_sorted_and_empty_state_is_clear
test_missing_project_and_empty_project_messages_are_clear
test_list_folder_tree_fallback_hides_internal_entries
test_list_folder_command_prints_nested_contents

echo "lazy_folders_list tests passed"
