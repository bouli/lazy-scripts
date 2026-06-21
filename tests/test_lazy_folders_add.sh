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

test_add_copies_with_exclusions_and_gitignore_creation() {
  local tmp home project portfolio output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  home="$tmp/home"
  project="$tmp/project"
  portfolio="$tmp/portfolio"

  mkdir -p "$project/.notes/nested" "$project/.notes/.git" "$project/.notes/deep/.git"
  git -C "$project" init -q
  git -C "$project" remote add origin git@github.com:me/app.git
  printf 'one\n' > "$project/.notes/one.txt"
  printf 'nested\n' > "$project/.notes/nested/two.txt"
  printf 'nested ignore\n' > "$project/.notes/nested/.gitignore"
  printf 'ignored\n' > "$project/.notes/.git/config"
  printf 'ignored\n' > "$project/.notes/deep/.git/config"

  run_with_home "$home" init "$portfolio" >/dev/null
  output="$(cd "$project" && run_with_home "$home" add .notes --yes)"

  assert_contains "$output" "Project folder: app"
  assert_contains "$output" "Summary: copied=3 skipped=0 replaced=0"
  assert_file_contains "$project/.notes/.gitignore" "*"
  assert_file_contains "$portfolio/app/.lazy-folders.yml" "repo_name: 'app'"
  assert_file_contains "$portfolio/app/.notes/one.txt" "one"
  assert_file_contains "$portfolio/app/.notes/nested/two.txt" "nested"
  assert_file_contains "$portfolio/app/.notes/nested/.gitignore" "nested ignore"
  assert_not_exists "$portfolio/app/.notes/.gitignore"
  assert_not_exists "$portfolio/app/.notes/.git/config"
  assert_not_exists "$portfolio/app/.notes/deep/.git/config"
}

test_add_skips_existing_and_overwrites_only_when_requested() {
  local tmp home project portfolio output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  home="$tmp/home"
  project="$tmp/project"
  portfolio="$tmp/portfolio"

  mkdir -p "$project/.notes"
  git -C "$project" init -q
  git -C "$project" remote add origin https://github.com/me/app.git
  printf '*\n' > "$project/.notes/.gitignore"
  printf 'local v1\n' > "$project/.notes/item.txt"

  run_with_home "$home" init "$portfolio" >/dev/null
  cd "$project"
  run_with_home "$home" add .notes --yes >/dev/null
  printf 'portfolio only\n' > "$portfolio/app/.notes/keep.txt"
  printf 'local v2\n' > "$project/.notes/item.txt"

  output="$(run_with_home "$home" add .notes --yes)"
  assert_contains "$output" "Summary: copied=0 skipped=1 replaced=0"
  assert_file_contains "$portfolio/app/.notes/item.txt" "local v1"
  assert_file_contains "$portfolio/app/.notes/keep.txt" "portfolio only"

  output="$(run_with_home "$home" add .notes --overwrite --yes)"
  assert_contains "$output" "Summary: copied=0 skipped=0 replaced=1"
  assert_file_contains "$portfolio/app/.notes/item.txt" "local v2"
  assert_file_contains "$portfolio/app/.notes/keep.txt" "portfolio only"
}

test_add_warns_for_non_dot_target() {
  local tmp home project portfolio output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  home="$tmp/home"
  project="$tmp/plain"
  portfolio="$tmp/portfolio"

  mkdir -p "$project/notes"
  printf 'hello\n' > "$project/notes/file.txt"

  run_with_home "$home" init "$portfolio" >/dev/null
  output="$(cd "$project" && run_with_home "$home" add notes --yes 2>&1)"

  assert_contains "$output" "Warning: target folder 'notes' is not a dot-folder."
  assert_file_contains "$portfolio/plain/notes/file.txt" "hello"
}

test_add_copies_with_exclusions_and_gitignore_creation
test_add_skips_existing_and_overwrites_only_when_requested
test_add_warns_for_non_dot_target

echo "lazy_folders_add tests passed"
