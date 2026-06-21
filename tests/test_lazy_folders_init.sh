#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/development/lazy_folders.py"
MAKEFILE="$REPO_ROOT/Makefile"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_exists() {
  [ -e "$1" ] || fail "expected $1 to exist"
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

test_default_init_creates_portfolio_and_config() {
  local tmp output config portfolio
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  config="$tmp/home/.config/lazy-folders/config.yml"
  portfolio="$tmp/home/lazy-dot-folders"

  output="$(run_with_home "$tmp/home" init)"

  assert_exists "$portfolio"
  assert_file_contains "$config" "portfolio_path: '$portfolio'"
  assert_contains "$output" "Portfolio path: $portfolio"
  assert_contains "$output" "Config path: $config"
}

test_custom_init_updates_config_and_is_repeatable() {
  local tmp output config portfolio
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  config="$tmp/home/.config/lazy-folders/config.yml"
  portfolio="$tmp/custom portfolio"

  output="$(run_with_home "$tmp/home" init "$portfolio")"
  output="$(run_with_home "$tmp/home" init "$portfolio")"

  assert_exists "$portfolio"
  assert_file_contains "$config" "portfolio_path: '$portfolio'"
  assert_contains "$output" "Portfolio path: $portfolio"
}

test_makefile_installs_and_cleans_command_links() {
  local makefile
  makefile="$(cat "$MAKEFILE")"

  assert_contains "$makefile" "development/lazy_folders.py /usr/local/bin/lazy-folders"
  assert_contains "$makefile" "development/lazy_folders.py /usr/local/bin/dev-lazy-folders"
  assert_contains "$makefile" "rm -f /usr/local/bin/lazy-folders"
  assert_contains "$makefile" "rm -f /usr/local/bin/dev-lazy-folders"
}

test_help_documents_init() {
  local output

  output="$("$SCRIPT" --help)"

  assert_contains "$output" "Sync project-local lazy folders"
  assert_contains "$output" "init"
}

test_default_init_creates_portfolio_and_config
test_custom_init_updates_config_and_is_repeatable
test_makefile_installs_and_cleans_command_links
test_help_documents_init

echo "lazy_folders_init tests passed"
