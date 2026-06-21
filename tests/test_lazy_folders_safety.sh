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

test_non_interactive_prompts_fail_without_yes() {
  local tmp home project portfolio output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  home="$tmp/home"
  project="$tmp/project"
  portfolio="$tmp/portfolio"

  mkdir -p "$project/.notes" "$portfolio/app/.agents" "$portfolio/app/.work"
  git -C "$project" init -q
  git -C "$project" remote add origin git@github.com:me/app.git
  printf 'note\n' > "$project/.notes/item.md"
  printf 'agent\n' > "$portfolio/app/.agents/config.md"
  printf 'work\n' > "$portfolio/app/.work/item.md"
  printf 'local work\n' > "$project/.work-local"

  run_with_home "$home" init "$portfolio" >/dev/null

  output="$(cd "$project" && run_with_home "$home" add .notes 2>&1 || true)"
  assert_contains "$output" "Re-run with --yes to confirm non-interactively."
  assert_not_exists "$project/.notes/.gitignore"
  assert_not_exists "$portfolio/app/.notes/item.md"

  output="$(cd "$project" && run_with_home "$home" pull .agents 2>&1 || true)"
  assert_contains "$output" "Re-run with --yes to confirm non-interactively."
  assert_not_exists "$project/.agents/.gitignore"
  assert_not_exists "$project/.agents/config.md"

  mkdir -p "$project/.work"
  printf 'local work\n' > "$project/.work/item.md"
  output="$(cd "$project" && run_with_home "$home" push .work 2>&1 || true)"
  assert_contains "$output" "Re-run with --yes to confirm non-interactively."
  assert_not_exists "$project/.work/.gitignore"
  assert_file_contains "$portfolio/app/.work/item.md" "work"
}

test_yes_creates_missing_gitignores_across_sync_commands() {
  local tmp home project portfolio output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  home="$tmp/home"
  project="$tmp/project"
  portfolio="$tmp/portfolio"

  mkdir -p "$project/.notes" "$project/.work" "$portfolio/app/.agents"
  git -C "$project" init -q
  git -C "$project" remote add origin https://github.com/me/app.git
  printf 'note\n' > "$project/.notes/item.md"
  printf 'work local\n' > "$project/.work/item.md"
  printf 'agent\n' > "$portfolio/app/.agents/config.md"

  run_with_home "$home" init "$portfolio" >/dev/null

  output="$(cd "$project" && run_with_home "$home" add .notes --yes)"
  assert_contains "$output" "Summary: copied=1 skipped=0 replaced=0"
  assert_file_contains "$project/.notes/.gitignore" "*"

  output="$(cd "$project" && run_with_home "$home" pull .agents --yes)"
  assert_contains "$output" "Summary: copied=1 skipped=0 replaced=0"
  assert_file_contains "$project/.agents/.gitignore" "*"

  output="$(cd "$project" && run_with_home "$home" push .work --yes)"
  assert_contains "$output" "Summary: copied=1 skipped=0 replaced=0"
  assert_file_contains "$project/.work/.gitignore" "*"
}

test_overwrite_requires_yes_for_unattended_replacement() {
  local tmp home project portfolio output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  home="$tmp/home"
  project="$tmp/project"
  portfolio="$tmp/portfolio"

  mkdir -p "$project/.notes" "$portfolio/app/.notes" "$portfolio/app/.agents"
  git -C "$project" init -q
  git -C "$project" remote add origin git@github.com:me/app.git
  printf '*\n' > "$project/.notes/.gitignore"
  printf 'local v2\n' > "$project/.notes/item.txt"
  printf 'portfolio v1\n' > "$portfolio/app/.notes/item.txt"
  printf 'local agent\n' > "$project/.agents-local"
  printf 'portfolio agent\n' > "$portfolio/app/.agents/config.md"

  run_with_home "$home" init "$portfolio" >/dev/null

  output="$(cd "$project" && run_with_home "$home" pull .notes --overwrite 2>&1 || true)"
  assert_contains "$output" "Re-run with --yes to confirm non-interactively."
  assert_file_contains "$project/.notes/item.txt" "local v2"

  output="$(cd "$project" && run_with_home "$home" pull .notes --overwrite --yes)"
  assert_contains "$output" "Summary: copied=0 skipped=0 replaced=1"
  assert_file_contains "$project/.notes/item.txt" "portfolio v1"

  mkdir -p "$project/.agents"
  printf '*\n' > "$project/.agents/.gitignore"
  printf 'local agent v2\n' > "$project/.agents/config.md"
  output="$(cd "$project" && run_with_home "$home" push .agents --overwrite 2>&1 || true)"
  assert_contains "$output" "Re-run with --yes to confirm non-interactively."
  assert_file_contains "$portfolio/app/.agents/config.md" "portfolio agent"

  output="$(cd "$project" && run_with_home "$home" push .agents --overwrite --yes)"
  assert_contains "$output" "Summary: copied=0 skipped=0 replaced=1"
  assert_file_contains "$portfolio/app/.agents/config.md" "local agent v2"
}

test_exclusions_and_destination_only_preservation_are_consistent() {
  local tmp home project portfolio output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  home="$tmp/home"
  project="$tmp/project"
  portfolio="$tmp/portfolio"

  mkdir -p "$project/.notes/nested" "$project/.notes/deep/.git" "$portfolio/app/.notes"
  git -C "$project" init -q
  git -C "$project" remote add origin git@github.com:me/app.git
  printf '*\n' > "$project/.notes/.gitignore"
  printf 'local\n' > "$project/.notes/item.md"
  printf 'nested ignore\n' > "$project/.notes/nested/.gitignore"
  printf 'ignored git\n' > "$project/.notes/deep/.git/config"
  printf 'portfolio only\n' > "$portfolio/app/.notes/keep.md"

  run_with_home "$home" init "$portfolio" >/dev/null
  output="$(cd "$project" && run_with_home "$home" push .notes --yes)"

  assert_contains "$output" ".notes: copied=2 skipped=0 replaced=0"
  assert_contains "$output" "Summary: copied=2 skipped=0 replaced=0"
  assert_file_contains "$portfolio/app/.notes/item.md" "local"
  assert_file_contains "$portfolio/app/.notes/nested/.gitignore" "nested ignore"
  assert_file_contains "$portfolio/app/.notes/keep.md" "portfolio only"
  assert_not_exists "$portfolio/app/.notes/.gitignore"
  assert_not_exists "$portfolio/app/.notes/deep/.git/config"
}

test_non_interactive_prompts_fail_without_yes
test_yes_creates_missing_gitignores_across_sync_commands
test_overwrite_requires_yes_for_unattended_replacement
test_exclusions_and_destination_only_preservation_are_consistent

echo "lazy_folders_safety tests passed"
