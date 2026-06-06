## 2026-06-06 - Issue 001: safe discovery and dry-run

- Replaced fixed-depth `rm -rf` calls in `development/clean_garbage_collector.sh` with a shared discovery path based on `find`.
- Added `--dry-run` support that prints the exact targets without deleting them.
- Added target listing and summary output for dry-run and delete modes.
- Preserved current cleanup scope for this slice: `.venv` and `__pycache__`.
- Added shell command tests under `tests/test_clean_garbage_collector.sh` for dry-run, deletion, nested paths, empty target summary, and paths with spaces.

## 2026-06-06 - Issue 002: project directory safety guard

- Added a working-directory guard to `development/clean_garbage_collector.sh` before cleanup discovery.
- Refuse cleanup from `/`, from `$HOME`, and from directories without a project marker.
- Accepted project markers: `.git`, `pyproject.toml`, `package.json`, and `go.mod`.
- Added command tests for root refusal, home refusal, markerless refusal, and each accepted marker.

## 2026-06-06 - Issue 003: improve Python cache cleanup

- Expanded Python cleanup discovery to include `venv`, `.pytest_cache`, `.ruff_cache`, `.mypy_cache`, `.coverage`, `htmlcov`, `*.egg-info`, `dist`, and `build`.
- Kept `.venv` and nested `__pycache__` cleanup in the default command behavior.
- Pruned `.git` and `node_modules` during discovery to keep project-local traversal bounded.
- Updated shell command tests to verify dry-run output, deletion, preservation of unrelated files, and paths with spaces for the expanded Python target set.
