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

test_push_single_folder_updates_current_project_with_exclusions() {
  local tmp home project portfolio output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  home="$tmp/home"
  project="$tmp/project"
  portfolio="$tmp/portfolio"

  mkdir -p "$project/.notes/nested" "$project/.notes/.git" "$project/.notes/deep/.git"
  git -C "$project" init -q
  git -C "$project" remote add origin git@github.com:me/app.git
  printf '*\n' > "$project/.notes/.gitignore"
  printf 'note\n' > "$project/.notes/item.md"
  printf 'nested ignore\n' > "$project/.notes/nested/.gitignore"
  printf 'git\n' > "$project/.notes/.git/config"
  printf 'deep git\n' > "$project/.notes/deep/.git/config"

  run_with_home "$home" init "$portfolio" >/dev/null
  output="$(cd "$project" && run_with_home "$home" push .notes --yes)"

  assert_contains "$output" "Project folder: app"
  assert_contains "$output" ".notes: copied=2 skipped=0 replaced=0"
  assert_contains "$output" "Summary: copied=2 skipped=0 replaced=0"
  assert_file_contains "$portfolio/app/.lazy-folders.yml" "repo_name: 'app'"
  assert_file_contains "$portfolio/app/.notes/item.md" "note"
  assert_file_contains "$portfolio/app/.notes/nested/.gitignore" "nested ignore"
  assert_not_exists "$portfolio/app/.notes/.gitignore"
  assert_not_exists "$portfolio/app/.notes/.git/config"
  assert_not_exists "$portfolio/app/.notes/deep/.git/config"
}

test_push_no_argument_updates_only_known_local_folders() {
  local tmp home project portfolio output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  home="$tmp/home"
  project="$tmp/project"
  portfolio="$tmp/portfolio"

  mkdir -p "$project/.notes" "$project/.local-only" "$portfolio/app/.notes" "$portfolio/app/.agents"
  git -C "$project" init -q
  git -C "$project" remote add origin https://github.com/me/app.git
  printf '*\n' > "$project/.notes/.gitignore"
  printf 'local note\n' > "$project/.notes/item.md"
  printf 'old note\n' > "$portfolio/app/.notes/item.md"
  printf 'agent saved\n' > "$portfolio/app/.agents/config.md"
  printf 'local only\n' > "$project/.local-only/item.md"

  run_with_home "$home" init "$portfolio" >/dev/null
  output="$(cd "$project" && run_with_home "$home" push --yes)"

  assert_contains "$output" ".notes: copied=0 skipped=1 replaced=0"
  assert_contains "$output" "Summary: copied=0 skipped=1 replaced=0"
  assert_file_contains "$portfolio/app/.notes/item.md" "old note"
  assert_file_contains "$portfolio/app/.agents/config.md" "agent saved"
  assert_not_exists "$portfolio/app/.local-only/item.md"
}

test_push_overwrites_and_preserves_destination_only_files() {
  local tmp home project portfolio output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  home="$tmp/home"
  project="$tmp/project"
  portfolio="$tmp/portfolio"

  mkdir -p "$project/.notes" "$portfolio/app/.notes"
  git -C "$project" init -q
  git -C "$project" remote add origin git@github.com:me/app.git
  printf '*\n' > "$project/.notes/.gitignore"
  printf 'local v2\n' > "$project/.notes/item.txt"
  printf 'portfolio v1\n' > "$portfolio/app/.notes/item.txt"
  printf 'portfolio only\n' > "$portfolio/app/.notes/keep.txt"

  run_with_home "$home" init "$portfolio" >/dev/null
  output="$(cd "$project" && run_with_home "$home" push .notes --overwrite --yes)"

  assert_contains "$output" "Summary: copied=0 skipped=0 replaced=1"
  assert_file_contains "$portfolio/app/.notes/item.txt" "local v2"
  assert_file_contains "$portfolio/app/.notes/keep.txt" "portfolio only"
}

test_push_to_project_destination_rules() {
  local tmp home project portfolio output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  home="$tmp/home"
  project="$tmp/project"
  portfolio="$tmp/portfolio"

  mkdir -p "$project/.notes" "$project/.agents" "$portfolio/template-python/.agents"
  git -C "$project" init -q
  git -C "$project" remote add origin git@github.com:me/app.git
  printf '*\n' > "$project/.notes/.gitignore"
  printf '*\n' > "$project/.agents/.gitignore"
  printf 'note\n' > "$project/.notes/item.md"
  printf 'agent local\n' > "$project/.agents/config.md"
  printf 'agent old\n' > "$portfolio/template-python/.agents/config.md"

  run_with_home "$home" init "$portfolio" >/dev/null
  output="$(cd "$project" && run_with_home "$home" push .notes --to-project new-template --yes)"
  assert_contains "$output" "Project folder: new-template"
  assert_file_contains "$portfolio/new-template/.notes/item.md" "note"
  assert_file_contains "$portfolio/new-template/.lazy-folders.yml" "project_folder: 'new-template'"

  output="$(cd "$project" && run_with_home "$home" push --to-project missing-template --yes 2>&1 || true)"
  assert_contains "$output" "Portfolio project does not exist for no-argument push: missing-template"
  assert_not_exists "$portfolio/missing-template"

  output="$(cd "$project" && run_with_home "$home" push --to-project template-python --overwrite --yes)"
  assert_contains "$output" ".agents: copied=0 skipped=0 replaced=1"
  assert_file_contains "$portfolio/template-python/.agents/config.md" "agent local"
  assert_not_exists "$portfolio/template-python/.notes/item.md"
}

test_push_missing_local_target_is_clear() {
  local tmp home project portfolio output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  home="$tmp/home"
  project="$tmp/project"
  portfolio="$tmp/portfolio"

  mkdir -p "$project"
  run_with_home "$home" init "$portfolio" >/dev/null
  output="$(cd "$project" && run_with_home "$home" push .notes --yes 2>&1 || true)"

  assert_contains "$output" "Local target folder does not exist:"
}

test_push_single_folder_updates_current_project_with_exclusions
test_push_no_argument_updates_only_known_local_folders
test_push_overwrites_and_preserves_destination_only_files
test_push_to_project_destination_rules
test_push_missing_local_target_is_clear

echo "lazy_folders_push tests passed"
