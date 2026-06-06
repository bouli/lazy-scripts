#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/development/clean_garbage_collector.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_exists() {
  [ -e "$1" ] || fail "expected $1 to exist"
}

assert_not_exists() {
  [ ! -e "$1" ] || fail "expected $1 to be removed"
}

assert_contains() {
  case "$1" in
    *"$2"*) ;;
    *) fail "expected output to contain: $2" ;;
  esac
}

make_fixture() {
  local root="$1"

  mkdir -p "$root/project/.venv"
  mkdir -p "$root/project/src/pkg/__pycache__"
  mkdir -p "$root/project/deep/one/two/three/__pycache__"
  mkdir -p "$root/project/path with spaces/__pycache__"
  touch "$root/project/keep.txt"
}

run_in_project() {
  local project="$1"
  shift

  (
    cd "$project"
    "$SCRIPT" "$@"
  )
}

test_dry_run_prints_targets_and_deletes_nothing() {
  local tmp output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_fixture "$tmp"

  output="$(run_in_project "$tmp/project" --dry-run)"

  assert_contains "$output" "Cleanup targets:"
  assert_contains "$output" "./.venv"
  assert_contains "$output" "./src/pkg/__pycache__"
  assert_contains "$output" "./deep/one/two/three/__pycache__"
  assert_contains "$output" "./path with spaces/__pycache__"
  assert_contains "$output" "Summary: found 4 target(s); removed 0 target(s) (dry run)."
  assert_exists "$tmp/project/.venv"
  assert_exists "$tmp/project/src/pkg/__pycache__"
  assert_exists "$tmp/project/deep/one/two/three/__pycache__"
  assert_exists "$tmp/project/path with spaces/__pycache__"
}

test_delete_removes_same_targets_dry_run_reports() {
  local tmp dry_run delete_run
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_fixture "$tmp"

  dry_run="$(run_in_project "$tmp/project" --dry-run)"
  delete_run="$(run_in_project "$tmp/project")"

  assert_contains "$delete_run" "./.venv"
  assert_contains "$delete_run" "./src/pkg/__pycache__"
  assert_contains "$delete_run" "./deep/one/two/three/__pycache__"
  assert_contains "$delete_run" "./path with spaces/__pycache__"
  assert_contains "$delete_run" "Summary: found 4 target(s); removed 4 target(s)."
  assert_contains "$dry_run" "Summary: found 4 target(s); removed 0 target(s) (dry run)."
  assert_not_exists "$tmp/project/.venv"
  assert_not_exists "$tmp/project/src/pkg/__pycache__"
  assert_not_exists "$tmp/project/deep/one/two/three/__pycache__"
  assert_not_exists "$tmp/project/path with spaces/__pycache__"
  assert_exists "$tmp/project/keep.txt"
}

test_no_targets_reports_empty_summary() {
  local tmp output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/project"

  output="$(run_in_project "$tmp/project" --dry-run)"

  assert_contains "$output" "  none"
  assert_contains "$output" "Summary: found 0 target(s); removed 0 target(s) (dry run)."
}

test_dry_run_prints_targets_and_deletes_nothing
test_delete_removes_same_targets_dry_run_reports
test_no_targets_reports_empty_summary

echo "All clean_garbage_collector tests passed."
