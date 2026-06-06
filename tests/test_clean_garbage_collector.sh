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

assert_not_contains() {
  case "$1" in
    *"$2"*) fail "expected output not to contain: $2" ;;
    *) ;;
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

make_javascript_fixture() {
  local root="$1"

  mkdir -p "$root/project"
  touch "$root/project/package.json"
  mkdir -p "$root/project/.next"
  mkdir -p "$root/project/.nuxt"
  mkdir -p "$root/project/.svelte-kit"
  mkdir -p "$root/project/.turbo"
  mkdir -p "$root/project/.vite"
  mkdir -p "$root/project/coverage"
  mkdir -p "$root/project/dist"
  mkdir -p "$root/project/build"
  mkdir -p "$root/project/node_modules/.vite"
  touch "$root/project/node_modules/keep.js"
}

make_go_fixture() {
  local root="$1"

  mkdir -p "$root/project/bin"
  touch "$root/project/go.mod"
  touch "$root/project/coverage.out"
  touch "$root/project/pkg.test"
  touch "$root/project/bin/tool"
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

test_javascript_targets_are_cleaned_by_default_without_dependencies() {
  local tmp output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_javascript_fixture "$tmp"

  output="$(run_in_project "$tmp/project")"

  assert_contains "$output" "JavaScript dependency cleanup: disabled"
  assert_contains "$output" "./.next"
  assert_contains "$output" "./.nuxt"
  assert_contains "$output" "./.svelte-kit"
  assert_contains "$output" "./.turbo"
  assert_contains "$output" "./.vite"
  assert_contains "$output" "./coverage"
  assert_contains "$output" "./dist"
  assert_contains "$output" "./build"
  assert_contains "$output" "Summary: found 8 target(s); removed 8 target(s)."
  assert_not_contains "$output" "./node_modules"
  assert_not_exists "$tmp/project/.next"
  assert_not_exists "$tmp/project/.nuxt"
  assert_not_exists "$tmp/project/.svelte-kit"
  assert_not_exists "$tmp/project/.turbo"
  assert_not_exists "$tmp/project/.vite"
  assert_not_exists "$tmp/project/coverage"
  assert_not_exists "$tmp/project/dist"
  assert_not_exists "$tmp/project/build"
  assert_exists "$tmp/project/node_modules"
  assert_exists "$tmp/project/node_modules/.vite"
}

test_javascript_dry_run_reports_dependency_cleanup_state() {
  local tmp output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_javascript_fixture "$tmp"

  output="$(run_in_project "$tmp/project" --dry-run --dependencies)"

  assert_contains "$output" "JavaScript dependency cleanup: enabled"
  assert_contains "$output" "./node_modules"
  assert_contains "$output" "Summary: found 9 target(s); removed 0 target(s) (dry run)."
  assert_exists "$tmp/project/node_modules"
  assert_exists "$tmp/project/.next"
}

test_dependency_option_removes_node_modules() {
  local tmp output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_javascript_fixture "$tmp"

  output="$(run_in_project "$tmp/project" --dependencies)"

  assert_contains "$output" "JavaScript dependency cleanup: enabled"
  assert_contains "$output" "./node_modules"
  assert_contains "$output" "Summary: found 9 target(s); removed 9 target(s)."
  assert_not_exists "$tmp/project/node_modules"
}

test_go_targets_are_cleaned_by_default() {
  local tmp output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_go_fixture "$tmp"

  output="$(run_in_project "$tmp/project")"

  assert_contains "$output" "Go cache cleanup: disabled"
  assert_contains "$output" "./coverage.out"
  assert_contains "$output" "./pkg.test"
  assert_contains "$output" "Summary: found 2 target(s); removed 2 target(s)."
  assert_not_contains "$output" "./bin"
  assert_not_exists "$tmp/project/coverage.out"
  assert_not_exists "$tmp/project/pkg.test"
  assert_exists "$tmp/project/bin"
  assert_exists "$tmp/project/bin/tool"
}

test_go_cache_dry_run_reports_external_cleanup_without_running_it() {
  local tmp fake_bin output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_go_fixture "$tmp"
  fake_bin="$tmp/fake-bin"
  mkdir -p "$fake_bin"
  printf '#!/bin/sh\necho "$@" > "%s/go-called"\n' "$tmp" > "$fake_bin/go"
  chmod +x "$fake_bin/go"

  output="$(
    cd "$tmp/project"
    PATH="$fake_bin:$PATH" "$SCRIPT" --dry-run --go-cache
  )"

  assert_contains "$output" "Go cache cleanup: enabled (would run: go clean -cache -testcache)"
  assert_contains "$output" "./coverage.out"
  assert_contains "$output" "./pkg.test"
  assert_contains "$output" "Summary: found 2 target(s); removed 0 target(s) (dry run)."
  assert_exists "$tmp/project/coverage.out"
  assert_exists "$tmp/project/pkg.test"
  assert_not_exists "$tmp/go-called"
}

test_go_cache_option_runs_explicit_go_clean() {
  local tmp fake_bin output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_go_fixture "$tmp"
  fake_bin="$tmp/fake-bin"
  mkdir -p "$fake_bin"
  printf '#!/bin/sh\necho "$@" > "%s/go-called"\n' "$tmp" > "$fake_bin/go"
  chmod +x "$fake_bin/go"

  output="$(
    cd "$tmp/project"
    PATH="$fake_bin:$PATH" "$SCRIPT" --go-cache
  )"

  assert_contains "$output" "Go cache cleanup: enabled (would run: go clean -cache -testcache)"
  assert_contains "$output" "Summary: found 2 target(s); removed 2 target(s)."
  assert_contains "$output" "Go cache cleanup: completed."
  assert_not_exists "$tmp/project/coverage.out"
  assert_not_exists "$tmp/project/pkg.test"
  assert_contains "$(cat "$tmp/go-called")" "clean -cache -testcache"
}

test_go_cache_option_reports_missing_go_after_local_cleanup() {
  local tmp fake_bin output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  make_go_fixture "$tmp"
  fake_bin="$tmp/fake-bin"
  mkdir -p "$fake_bin"
  ln -s "$(command -v find)" "$fake_bin/find"
  ln -s "$(command -v mktemp)" "$fake_bin/mktemp"
  ln -s "$(command -v rm)" "$fake_bin/rm"

  set +e
  output="$(
    cd "$tmp/project"
    PATH="$fake_bin" "$SCRIPT" --go-cache 2>&1
  )"
  status=$?
  set -e

  [ "$status" -ne 0 ] || fail "expected --go-cache without go to fail"
  assert_contains "$output" "Go cache cleanup failed: go command not found; install Go or rerun without --go-cache."
  assert_not_exists "$tmp/project/coverage.out"
  assert_not_exists "$tmp/project/pkg.test"
  assert_exists "$tmp/project/bin"
}

test_dry_run_prints_targets_and_deletes_nothing
test_delete_removes_same_targets_dry_run_reports
test_no_targets_reports_empty_summary
test_refuses_filesystem_root
test_refuses_home_directory
test_refuses_directory_without_project_marker
test_accepts_common_project_markers
test_javascript_targets_are_cleaned_by_default_without_dependencies
test_javascript_dry_run_reports_dependency_cleanup_state
test_dependency_option_removes_node_modules
test_go_targets_are_cleaned_by_default
test_go_cache_dry_run_reports_external_cleanup_without_running_it
test_go_cache_option_runs_explicit_go_clean
test_go_cache_option_reports_missing_go_after_local_cleanup

echo "All clean_garbage_collector tests passed."
