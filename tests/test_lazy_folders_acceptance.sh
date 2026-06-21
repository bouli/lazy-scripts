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

test_full_lazy_folders_acceptance_workflow() {
  local tmp home project other_project portfolio output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  home="$tmp/home"
  project="$tmp/project"
  other_project="$tmp/other-project"
  portfolio="$tmp/portfolio"

  mkdir -p "$project/.notes/nested" "$project/.notes/deep/.git"
  git -C "$project" init -q
  git -C "$project" remote add origin https://github.com/me/workflow-app.git
  printf 'local note v1\n' > "$project/.notes/item.md"
  printf 'nested ignore\n' > "$project/.notes/nested/.gitignore"
  printf 'git internals\n' > "$project/.notes/deep/.git/config"

  output="$(run_with_home "$home" init "$portfolio")"
  assert_contains "$output" "Portfolio path: $portfolio"
  assert_file_contains "$home/.config/lazy-folders/config.yml" "portfolio_path: '$portfolio'"

  output="$(cd "$project" && run_with_home "$home" add .notes --yes)"
  assert_contains "$output" "Project folder: workflow-app"
  assert_contains "$output" "Summary: copied=2 skipped=0 replaced=0"
  assert_file_contains "$project/.notes/.gitignore" "*"
  assert_file_contains "$portfolio/workflow-app/.lazy-folders.yml" "repo_name: 'workflow-app'"
  assert_file_contains "$portfolio/workflow-app/.notes/item.md" "local note v1"
  assert_file_contains "$portfolio/workflow-app/.notes/nested/.gitignore" "nested ignore"
  assert_not_exists "$portfolio/workflow-app/.notes/.gitignore"
  assert_not_exists "$portfolio/workflow-app/.notes/deep/.git/config"

  output="$(cd "$project" && run_with_home "$home" list)"
  assert_contains "$output" ".notes"
  case "$output" in
    *".lazy-folders.yml"*) fail "list output should hide metadata" ;;
  esac

  output="$(run_with_home "$home" projects)"
  assert_contains "$output" "workflow-app"

  output="$(cd "$project" && run_with_home "$home" add .notes 2>&1 || true)"
  assert_contains "$output" "Re-run with --yes to confirm non-interactively."

  printf 'portfolio note v2\n' > "$portfolio/workflow-app/.notes/item.md"
  printf 'local dirty\n' > "$project/.notes/item.md"
  output="$(cd "$project" && run_with_home "$home" pull .notes --overwrite --yes)"
  assert_contains "$output" "Summary: copied=0 skipped=0 replaced=2"
  assert_file_contains "$project/.notes/item.md" "portfolio note v2"

  mkdir -p "$portfolio/template-base/.agents"
  printf 'template agent\n' > "$portfolio/template-base/.agents/config.md"
  output="$(cd "$project" && run_with_home "$home" pull .agents --use-template template-base --yes)"
  assert_contains "$output" "Template project folder: template-base"
  assert_file_contains "$project/.agents/config.md" "template agent"
  assert_file_contains "$project/.agents/.gitignore" "*"
  assert_not_exists "$portfolio/workflow-app/.agents/config.md"

  mkdir -p "$portfolio/template-python/.agents"
  printf 'old template agent\n' > "$portfolio/template-python/.agents/config.md"
  printf 'local agent v2\n' > "$project/.agents/config.md"
  output="$(cd "$project" && run_with_home "$home" push --to-project template-python --overwrite --yes)"
  assert_contains "$output" "Project folder: template-python"
  assert_contains "$output" ".agents: copied=0 skipped=0 replaced=1"
  assert_file_contains "$portfolio/template-python/.agents/config.md" "local agent v2"
  assert_not_exists "$portfolio/template-python/.notes/item.md"

  mkdir -p "$other_project/.notes"
  git -C "$other_project" init -q
  git -C "$other_project" remote add origin https://github.com/other/workflow-app.git
  printf '*\n' > "$other_project/.notes/.gitignore"
  printf 'other note\n' > "$other_project/.notes/item.md"
  output="$(cd "$other_project" && run_with_home "$home" add .notes 2>&1 || true)"
  assert_contains "$output" "different project identity"
  assert_contains "$output" "Re-run with --yes"
  assert_file_contains "$portfolio/workflow-app/.notes/item.md" "portfolio note v2"
}

test_full_lazy_folders_acceptance_workflow

python3 -m py_compile "$SCRIPT"

echo "lazy_folders_acceptance tests passed"
