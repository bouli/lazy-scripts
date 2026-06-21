#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT_DIR_FOR_IMPORT="$REPO_ROOT/development"

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

run_python() {
  PYTHONPATH="$SCRIPT_DIR_FOR_IMPORT" python3 "$@"
}

test_remote_priority_and_metadata() {
  local tmp metadata output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  mkdir -p "$tmp/project"
  git -C "$tmp/project" init -q
  git -C "$tmp/project" remote add zeta git@example.com:team/zeta.git
  git -C "$tmp/project" remote add origin https://github.com/me/origin-app.git
  git -C "$tmp/project" remote add upstream git@github.com:upstream/Primary.App.git

  output="$(
    run_python - "$tmp/project" "$tmp/portfolio" <<'PY'
from pathlib import Path
import sys

import lazy_folders

identity = lazy_folders.resolve_project_identity(Path(sys.argv[1]))
metadata = lazy_folders.ensure_portfolio_project_metadata(Path(sys.argv[2]), identity, yes=True)
print(identity.project_folder)
print(identity.selected_remote_name)
print(identity.repo_name)
print(metadata)
PY
  )"

  metadata="$tmp/portfolio/Primary.App/.lazy-folders.yml"
  assert_exists "$metadata"
  assert_contains "$output" "Primary.App"
  assert_contains "$output" "upstream"
  assert_contains "$(cat "$metadata")" "selected_remote_name: 'upstream'"
  assert_contains "$(cat "$metadata")" "remote_url: 'git@github.com:upstream/Primary.App.git'"
  assert_contains "$(cat "$metadata")" "identity_kind: 'remote'"
  assert_contains "$(cat "$metadata")" "repo_name: 'Primary.App'"
}

test_git_and_non_git_fallbacks() {
  local tmp output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  mkdir -p "$tmp/repo with spaces/subdir" "$tmp/plain dir"
  git -C "$tmp/repo with spaces" init -q

  output="$(
    run_python - "$tmp/repo with spaces/subdir" "$tmp/plain dir" <<'PY'
from pathlib import Path
import sys

import lazy_folders

git_identity = lazy_folders.resolve_project_identity(Path(sys.argv[1]))
plain_identity = lazy_folders.resolve_project_identity(Path(sys.argv[2]))
print(git_identity.resolution_method, git_identity.project_folder)
print(plain_identity.resolution_method, plain_identity.project_folder)
PY
  )"

  assert_contains "$output" "git-root repo-with-spaces"
  assert_contains "$output" "cwd plain-dir"
}

test_sanitization_and_empty_fallback_warning() {
  local output

  output="$(
    run_python - 2>&1 <<'PY'
import lazy_folders

print(lazy_folders.sanitize_project_folder("café app///one"))
print(lazy_folders.sanitize_project_folder("🤖🤖"))
PY
  )"

  assert_contains "$output" "cafe-app-one"
  assert_contains "$output" "project-"
  assert_contains "$output" "could not be sanitized"
}

test_metadata_collision_rejected_non_interactively() {
  local tmp output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  mkdir -p "$tmp/portfolio/app"
  cat > "$tmp/portfolio/app/.lazy-folders.yml" <<'YAML'
version: '1'
project_folder: 'app'
identity_kind: 'remote'
identity_key: 'git@github.com:old/app'
YAML

  output="$(
    run_python - "$tmp/portfolio" 2>&1 <<'PY' || true
from pathlib import Path
import sys

import lazy_folders

identity = lazy_folders.ProjectIdentity(
    project_folder="app",
    raw_project_name="app",
    resolution_method="git-remote",
    identity_kind="remote",
    identity_key="git@github.com:new/app",
    project_root=Path("/tmp/new"),
)
try:
    lazy_folders.ensure_portfolio_project_metadata(Path(sys.argv[1]), identity)
except RuntimeError as exc:
    print(exc)
PY
  )"

  assert_contains "$output" "different project identity"
  assert_contains "$output" "Re-run with --yes"
  assert_contains "$(cat "$tmp/portfolio/app/.lazy-folders.yml")" "git@github.com:old/app"
}

test_remote_priority_and_metadata
test_git_and_non_git_fallbacks
test_sanitization_and_empty_fallback_warning
test_metadata_collision_rejected_non_interactively

echo "lazy_folders_identity_metadata tests passed"
