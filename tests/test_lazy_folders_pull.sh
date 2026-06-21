#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/development/lazy_folders.py"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_exists() {
  [ -e "$1" ] || fail "expected $1 to exist"
}

assert_not_exists() {
  [ ! -e "$1" ] || fail "expected $1 not to exist"
}

assert_contains() {
  case "$1" in
    *"$2"*) ;;
    *) fail "expected output to contain: $2" ;;
  esac
}

assert_file_contains() {
  local path="$1"
  local expected="$2"

  assert_exists "$path"
  assert_contains "$(cat "$path")" "$expected"
}

run_with_home() {
  local home="$1"
  shift

  HOME="$home" XDG_CONFIG_HOME="$home/.config" "$SCRIPT" "$@"
}

test_pull_all_restores_saved_folders_with_exclusions_and_gitignores() {
  local tmp home project portfolio output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  home="$tmp/home"
  project="$tmp/project"
  portfolio="$tmp/portfolio"

  mkdir -p "$project" "$portfolio/app/.notes/nested" "$portfolio/app/.agents" "$portfolio/app/.work/.git"
  git -C "$project" init -q
  git -C "$project" remote add origin git@github.com:me/app.git
  printf 'version: 1\n' > "$portfolio/app/.lazy-folders.yml"
  printf 'note\n' > "$portfolio/app/.notes/item.md"
  printf 'nested ignore\n' > "$portfolio/app/.notes/nested/.gitignore"
  printf 'skip top ignore\n' > "$portfolio/app/.notes/.gitignore"
  printf 'agent\n' > "$portfolio/app/.agents/config.md"
  printf 'git\n' > "$portfolio/app/.work/.git/config"

  run_with_home "$home" init "$portfolio" >/dev/null
  output="$(cd "$project" && run_with_home "$home" pull --yes)"

  assert_contains "$output" "Project folder: app"
  assert_contains "$output" "Summary: copied=3 skipped=0 replaced=0"
  assert_file_contains "$project/.notes/item.md" "note"
  assert_file_contains "$project/.notes/nested/.gitignore" "nested ignore"
  assert_file_contains "$project/.agents/config.md" "agent"
  assert_file_contains "$project/.notes/.gitignore" "*"
  assert_file_contains "$project/.agents/.gitignore" "*"
  assert_file_contains "$project/.work/.gitignore" "*"
  assert_not_exists "$project/.lazy-folders.yml"
  assert_not_exists "$project/.work/.git/config"
}

test_pull_single_folder_from_template_without_metadata() {
  local tmp home project portfolio output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  home="$tmp/home"
  project="$tmp/project"
  portfolio="$tmp/portfolio"

  mkdir -p "$project" "$portfolio/template-python/.agents" "$portfolio/template-python/.notes"
  printf 'template agent\n' > "$portfolio/template-python/.agents/instructions.md"
  printf 'template note\n' > "$portfolio/template-python/.notes/item.md"

  run_with_home "$home" init "$portfolio" >/dev/null
  output="$(cd "$project" && run_with_home "$home" pull .agents --use-template template-python --yes)"

  assert_contains "$output" "Template project folder: template-python"
  assert_contains "$output" "Summary: copied=1 skipped=0 replaced=0"
  assert_file_contains "$project/.agents/instructions.md" "template agent"
  assert_file_contains "$project/.agents/.gitignore" "*"
  assert_not_exists "$project/.notes/item.md"
  assert_not_exists "$portfolio/project/.lazy-folders.yml"
}

test_pull_skips_existing_and_overwrites_only_when_requested() {
  local tmp home project portfolio output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  home="$tmp/home"
  project="$tmp/project"
  portfolio="$tmp/portfolio"

  mkdir -p "$project/.notes" "$portfolio/app/.notes"
  git -C "$project" init -q
  git -C "$project" remote add origin https://github.com/me/app.git
  printf '*\n' > "$project/.notes/.gitignore"
  printf 'local only\n' > "$project/.notes/keep.txt"
  printf 'local v1\n' > "$project/.notes/item.txt"
  printf 'portfolio v2\n' > "$portfolio/app/.notes/item.txt"

  run_with_home "$home" init "$portfolio" >/dev/null
  output="$(cd "$project" && run_with_home "$home" pull .notes --yes)"
  assert_contains "$output" "Summary: copied=0 skipped=1 replaced=0"
  assert_file_contains "$project/.notes/item.txt" "local v1"
  assert_file_contains "$project/.notes/keep.txt" "local only"

  output="$(cd "$project" && run_with_home "$home" pull .notes --overwrite --yes)"
  assert_contains "$output" "Summary: copied=0 skipped=0 replaced=1"
  assert_file_contains "$project/.notes/item.txt" "portfolio v2"
  assert_file_contains "$project/.notes/keep.txt" "local only"
}

test_pull_missing_states_are_clear() {
  local tmp home project portfolio output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  home="$tmp/home"
  project="$tmp/project"
  portfolio="$tmp/portfolio"

  mkdir -p "$project" "$portfolio/app"
  git -C "$project" init -q
  git -C "$project" remote add origin git@github.com:me/app.git
  run_with_home "$home" init "$portfolio" >/dev/null

  output="$(cd "$project" && run_with_home "$home" pull)"
  assert_contains "$output" "No saved target folders for project: app"

  output="$(cd "$project" && run_with_home "$home" pull .notes 2>&1 || true)"
  assert_contains "$output" "Portfolio target folder does not exist: app/.notes"

  output="$(cd "$project" && run_with_home "$home" pull --use-template missing 2>&1 || true)"
  assert_contains "$output" "Portfolio project does not exist: missing"
}

test_pull_all_restores_saved_folders_with_exclusions_and_gitignores
test_pull_single_folder_from_template_without_metadata
test_pull_skips_existing_and_overwrites_only_when_requested
test_pull_missing_states_are_clear

echo "lazy_folders_pull tests passed"
