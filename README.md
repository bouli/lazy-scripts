# Bouli Lazy Scripts v0.8.0

Personal command-line scripts for development automation and AI sandbox workflows.

The repository is installed by symlinking selected scripts into `/usr/local/bin`.
After installation, those commands can be run from any shell.

## Repository Layout

```text
.
├── Makefile                         # Installs/removes command symlinks
├── ai/                              # AI sandbox and agent bootstrap scripts
│   ├── ai_lazy_init.sh
│   ├── lazy-ai-config/              # Files copied by ai-lazy-init
│   ├── sbx_claude.sh
│   ├── sbx_claude_ralph.sh
│   ├── sbx_cline.sh                 # Draft, not installed
│   ├── sbx_codex.sh
│   ├── sbx_codex_ralph.sh
│   ├── sbx_opencode.sh
│   └── sbx_opencode_ralph.sh
├── development/                     # General development utilities
│   ├── clean_garbage_collector.sh
│   ├── gh_lazy_init.sh
│   ├── lazy-gh-workflow/            # Files copied by dev-lazy-gh
│   ├── push_loop.sh
│   └── sandbox_launcher.sh
└── tests/                           # Shell tests for cleanup and legacy lazy-folders behavior
```

## Requirements

Installation requires:

- `make`
- `sudo`
- write access to `/usr/local/bin`
- `bash`, `sh`, and `zsh`

Runtime requirements depend on the command:

- `sbx` for AI sandbox commands
- `uv` and `code` for `bouli-sandbox` / `dev-sandbox`
- `git` for `dev-push-loop` and project workflows
- local Ollama on `localhost:11434` for the OpenCode sandbox config
- macOS-style `sed -i ''` for `dev-lazy-gh`

Some scripts use `readlink -f`, which may require GNU coreutils on macOS.

## Installation

Create command symlinks:

```sh
make create
```

Remove command symlinks:

```sh
make clean
```

Both targets modify `/usr/local/bin` with `sudo`. They only manage the symlinks
listed in the Makefile.

## Installed Commands

### Development

| Command | Source | Purpose |
| --- | --- | --- |
| `bouli-sandbox` | `development/sandbox_launcher.sh` | Deletes and recreates `~/sandbox` with `uv`, then opens it in VS Code. |
| `dev-sandbox` | `development/sandbox_launcher.sh` | Alias for `bouli-sandbox`. |
| `bouli-garbage-collector` | `development/clean_garbage_collector.sh` | Removes supported project-local Python, JavaScript, and Go generated artifacts. |
| `dev-garbage-collector` | `development/clean_garbage_collector.sh` | Alias for `bouli-garbage-collector`. |
| `dev-push-loop` | `development/push_loop.sh` | Runs `git push origin main` every 60 seconds until interrupted. |
| `dev-lazy-gh` | `development/gh_lazy_init.sh` | Copies reusable GitHub Actions workflows into the current project. |

### AI

| Command | Source | Purpose |
| --- | --- | --- |
| `ai-sbx-codex` | `ai/sbx_codex.sh` | Ensures an OpenAI `sbx` secret exists, creates a Codex sandbox for the current directory, then runs it. |
| `ai-sbx-claude` | `ai/sbx_claude.sh` | Ensures an Anthropic `sbx` secret exists, creates a Claude sandbox for the current directory, then runs it. |
| `ai-sbx-opencode` | `ai/sbx_opencode.sh` | Recreates an OpenCode sandbox for the current directory and allows access to local Ollama. |
| `ai-lazy-init` | `ai/ai_lazy_init.sh` | Copies the shared `.agents/` and `.opencode/` config into the current directory. |
| `ai-ralph-codex <iterations> [sleep_seconds]` | `ai/sbx_codex_ralph.sh` | Runs the Ralph Codex skill repeatedly in the current project's Codex sandbox. |
| `ai-ralph-claude <iterations> [sleep_seconds]` | `ai/sbx_claude_ralph.sh` | Runs the Ralph Claude prompt repeatedly in the current project's Claude sandbox. |
| `ai-ralph-opencode <iterations>` | `ai/sbx_opencode_ralph.sh` | Runs the Ralph OpenCode command repeatedly in the current project's OpenCode sandbox. |

`ai/sbx_cline.sh` is present as a draft script, but `make create` does not
install it.

## Common Usage

Create a disposable development sandbox:

```sh
bouli-sandbox
```

Preview cleanup targets in the current project:

```sh
dev-garbage-collector --dry-run
```

Remove default cleanup targets:

```sh
bouli-garbage-collector
```

Also remove JavaScript dependencies such as `node_modules`:

```sh
dev-garbage-collector --dependencies
```

Also clear shared Go build and test caches:

```sh
dev-garbage-collector --go-cache
```

Copy reusable GitHub Actions workflows into the current project:

```sh
dev-lazy-gh
```

Start Codex, Claude, or OpenCode in an `sbx` sandbox for the current project:

```sh
ai-sbx-codex
ai-sbx-claude
ai-sbx-opencode
```

Copy the shared AI agent config into the current project:

```sh
ai-lazy-init
```

Run Ralph with Codex for five iterations, sleeping 30 seconds between runs:

```sh
ai-ralph-codex 5 30
```

Run Ralph with Claude for five iterations, sleeping 30 seconds between runs:

```sh
ai-ralph-claude 5 30
```

Run Ralph with OpenCode for five iterations:

```sh
ai-ralph-opencode 5
```

## Generated Files

`ai-lazy-init` copies `ai/lazy-ai-config/` into the current project. The copied
content includes:

- `.agents/GUIDELINES.md`
- `.agents/PROGRESS.md`
- `.agents/settings.json`
- `.agents/code-standards/conventional-commits-messages.md`
- `.agents/skills/*/SKILL.md`
- `.opencode/opencode.json`

It also writes:

- `.agents/.gitignore` containing `*`
- `.opencode/.gitignore` containing `*`

`dev-lazy-gh` copies `development/lazy-gh-workflow/` into the current project.
The copied content includes:

- `.github/workflows/ci.yml`
- `.github/workflows/publish-pypi.yml`

It then replaces `<pypi_project>` in `publish-pypi.yml` with the current
directory name.

## Safety Notes

- `bouli-sandbox` runs `rm -r ~/sandbox`, so it deletes the existing sandbox before recreating it.
- `dev-push-loop` runs forever until interrupted with `Ctrl+C`.
- `make create` and `make clean` use `sudo` to modify `/usr/local/bin`.
- `dev-garbage-collector` refuses to run from `/`, from your home directory, or from a directory without `.git`, `pyproject.toml`, `package.json`, or `go.mod`.
- Default garbage collection removes project-local caches and build outputs for Python, JavaScript, and Go.
- `--dependencies` also removes `node_modules`.
- `--go-cache` runs `go clean -cache -testcache`, which affects Go caches outside the project directory.
- AI sandbox scripts rename `.agents` and `.claude` in the current project to match the selected tool.
- `ai-sbx-opencode` removes and recreates the current project's OpenCode sandbox before running it.

## Tests

Run the active cleanup tests with:

```sh
bash tests/test_clean_garbage_collector.sh
```

There are also `tests/test_lazy_folders_*.sh` files. They currently reference
`development/lazy_folders.py`, which is not present in this repository and is
not installed by the Makefile.

Shell syntax checks:

```sh
bash -n development/clean_garbage_collector.sh
bash -n development/sandbox_launcher.sh
bash -n ai/sbx_codex.sh
bash -n ai/sbx_claude.sh
bash -n ai/sbx_opencode.sh
```

## Notes for AI Agents

- Keep command names in sync with `Makefile`; it is the source of truth for installed symlinks.
- Preserve the README version string unless a version bump is explicitly requested. Version replacement is configured in `.bumpversion.toml`.
- These are personal automation scripts, not a packaged CLI. Avoid adding dependency managers or project structure unless requested.
- When adding a command, update both Makefile targets: `create` for the symlink and executable bit, and `clean` for symlink removal.
- Be careful with destructive shell commands. Several scripts intentionally remove local directories, generated files, or sandboxes.
