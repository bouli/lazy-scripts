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
  mkdir -p "$root/project/venv"
  mkdir -p "$root/project/.git"
  mkdir -p "$root/project/src/pkg/__pycache__"
  mkdir -p "$root/project/src/pkg/.pytest_cache"
  mkdir -p "$root/project/src/pkg/.ruff_cache"
  mkdir -p "$root/project/src/pkg/.mypy_cache"
  mkdir -p "$root/project/deep/one/two/three/__pycache__"
  mkdir -p "$root/project/path with spaces/__pycache__"
  mkdir -p "$root/project/htmlcov"
  mkdir -p "$root/project/example.egg-info"
  mkdir -p "$root/project/dist"
  mkdir -p "$root/project/build"
  touch "$root/project/.coverage"
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
  assert_contains "$output" "./venv"
  assert_contains "$output" "./src/pkg/__pycache__"
  assert_contains "$output" "./src/pkg/.pytest_cache"
  assert_contains "$output" "./src/pkg/.ruff_cache"
  assert_contains "$output" "./src/pkg/.mypy_cache"
  assert_contains "$output" "./deep/one/two/three/__pycache__"
  assert_contains "$output" "./path with spaces/__pycache__"
  assert_contains "$output" "./htmlcov"
  assert_contains "$output" "./example.egg-info"
  assert_contains "$output" "./dist"
  assert_contains "$output" "./build"
  assert_contains "$output" "./.coverage"
  assert_contains "$output" "Summary: found 13 target(s); removed 0 target(s) (dry run)."
  assert_exists "$tmp/project/.venv"
  assert_exists "$tmp/project/venv"
  assert_exists "$tmp/project/src/pkg/__pycache__"
  assert_exists "$tmp/project/src/pkg/.pytest_cache"
  assert_exists "$tmp/project/src/pkg/.ruff_cache"
  assert_exists "$tmp/project/src/pkg/.mypy_cache"
  assert_exists "$tmp/project/deep/one/two/three/__pycache__"
  assert_exists "$tmp/project/path with spaces/__pycache__"
  assert_exists "$tmp/project/htmlcov"
  assert_exists "$tmp/project/example.egg-info"
  assert_exists "$tmp/project/dist"
  assert_exists "$tmp/project/build"
  assert_exists "$tmp/project/.coverage"
}

test_delete_removes_same_targets_dry_run_reports() {
  local tmp dry_run delete_run
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_fixture "$tmp"

  dry_run="$(run_in_project "$tmp/project" --dry-run)"
  delete_run="$(run_in_project "$tmp/project")"

  assert_contains "$delete_run" "./.venv"
  assert_contains "$delete_run" "./venv"
  assert_contains "$delete_run" "./src/pkg/__pycache__"
  assert_contains "$delete_run" "./src/pkg/.pytest_cache"
  assert_contains "$delete_run" "./src/pkg/.ruff_cache"
  assert_contains "$delete_run" "./src/pkg/.mypy_cache"
  assert_contains "$delete_run" "./deep/one/two/three/__pycache__"
  assert_contains "$delete_run" "./path with spaces/__pycache__"
  assert_contains "$delete_run" "./htmlcov"
  assert_contains "$delete_run" "./example.egg-info"
  assert_contains "$delete_run" "./dist"
  assert_contains "$delete_run" "./build"
  assert_contains "$delete_run" "./.coverage"
  assert_contains "$delete_run" "Summary: found 13 target(s); removed 13 target(s)."
  assert_contains "$dry_run" "Summary: found 13 target(s); removed 0 target(s) (dry run)."
  assert_not_exists "$tmp/project/.venv"
  assert_not_exists "$tmp/project/venv"
  assert_not_exists "$tmp/project/src/pkg/__pycache__"
  assert_not_exists "$tmp/project/src/pkg/.pytest_cache"
  assert_not_exists "$tmp/project/src/pkg/.ruff_cache"
  assert_not_exists "$tmp/project/src/pkg/.mypy_cache"
  assert_not_exists "$tmp/project/deep/one/two/three/__pycache__"
  assert_not_exists "$tmp/project/path with spaces/__pycache__"
  assert_not_exists "$tmp/project/htmlcov"
  assert_not_exists "$tmp/project/example.egg-info"
  assert_not_exists "$tmp/project/dist"
  assert_not_exists "$tmp/project/build"
  assert_not_exists "$tmp/project/.coverage"
  assert_exists "$tmp/project/keep.txt"
}

test_no_targets_reports_empty_summary() {
  local tmp output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/project/.git"

  output="$(run_in_project "$tmp/project" --dry-run)"

  assert_contains "$output" "  none"
  assert_contains "$output" "Summary: found 0 target(s); removed 0 target(s) (dry run)."
}

test_refuses_filesystem_root() {
  local output status
  set +e
  output="$(cd / && "$SCRIPT" --dry-run 2>&1)"
  status=$?
  set -e

  [ "$status" -ne 0 ] || fail "expected cleanup from / to fail"
  assert_contains "$output" "Refusing cleanup: run from a project directory, not /."
}

test_refuses_home_directory() {
  local tmp output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/home"

  set +e
  output="$(cd "$tmp/home" && HOME="$tmp/home" "$SCRIPT" --dry-run 2>&1)"
  status=$?
  set -e

  [ "$status" -ne 0 ] || fail "expected cleanup from home directory to fail"
  assert_contains "$output" "Refusing cleanup: run from a project directory, not your home directory."
}

test_refuses_directory_without_project_marker() {
  local tmp output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/project/.venv"

  set +e
  output="$(run_in_project "$tmp/project" --dry-run 2>&1)"
  status=$?
  set -e

  [ "$status" -ne 0 ] || fail "expected markerless cleanup to fail"
  assert_contains "$output" "Refusing cleanup: no project marker found (.git, pyproject.toml, package.json, or go.mod)."
  assert_exists "$tmp/project/.venv"
}

test_accepts_common_project_markers() {
  local marker tmp output

  for marker in .git pyproject.toml package.json go.mod; do
    tmp="$(mktemp -d)"
    mkdir -p "$tmp/project"
    if [ "$marker" = ".git" ]; then
      mkdir -p "$tmp/project/.git"
    else
      touch "$tmp/project/$marker"
    fi

    output="$(run_in_project "$tmp/project" --dry-run)"
    assert_contains "$output" "Summary: found 0 target(s); removed 0 target(s) (dry run)."
    rm -rf "$tmp"
  done
}

test_dry_run_prints_targets_and_deletes_nothing
test_delete_removes_same_targets_dry_run_reports
test_no_targets_reports_empty_summary
test_refuses_filesystem_root
test_refuses_home_directory
test_refuses_directory_without_project_marker
test_accepts_common_project_markers

echo "All clean_garbage_collector tests passed."
