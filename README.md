# Bouli Lazy Scripts v0.5.1

Personal command-line scripts for development and AI sandbox workflows.

This repository is intended to be installed by creating symlinks from the scripts in this repo into `/usr/local/bin`. After installation, the commands can be run from any shell.

## Repository Layout

```text
.
├── Makefile                         # Installs/removes command symlinks
├── ai/                              # AI sandbox helper scripts
│   ├── ai_lazy_init.sh
│   ├── sbx_cline.sh
│   ├── sbx_codex.sh
│   ├── sbx_codex_ralph.sh
│   ├── sbx_opencode.sh
│   ├── sbx_opencode_ralph.sh
│   └── lazy-ai-config/
│       ├── .agents/
│       └── .opencode/opencode.json
├── development/                     # General development utilities
│   ├── clean_garbage_collector.sh
│   ├── gh_lazy_init.sh
│   ├── lazy_folders.py
│   ├── lazy-gh-workflow/
│   ├── push_loop.sh
│   └── sandbox_launcher.sh
```

## Requirements

The scripts are written for a Unix-like environment and currently assume macOS in several places.

Required for installation:

- `make`
- `sudo`
- write access to `/usr/local/bin`
- `bash`, `sh`, and `zsh`

Optional runtime tools, depending on which scripts you use:

- `sbx` for AI sandbox commands
- `uv` and `uvx`
- `code` command from Visual Studio Code
- `git`
- local Ollama server on `localhost:11434` for the OpenCode sandbox config

## Install Commands

From the repository root:

```sh
make create
```

This creates symlinks in `/usr/local/bin` and marks the source scripts executable.

To remove the installed symlinks:

```sh
make clean
```

`make clean` only removes the command symlinks listed in the Makefile. It does not delete this repository or files copied into other projects.

## Installed Commands

### Development

| Command | Source | Purpose |
| --- | --- | --- |
| `bouli-sandbox` | `development/sandbox_launcher.sh` | Recreates `~/sandbox` with `uv`, runs `uv sync`, and opens it in VS Code. |
| `dev-sandbox` | `development/sandbox_launcher.sh` | Alias for `bouli-sandbox`. |
| `bouli-garbage-collector` | `development/clean_garbage_collector.sh` | Cleans supported project-local Python, JavaScript, and Go artifacts after listing the matched targets. |
| `dev-garbage-collector` | `development/clean_garbage_collector.sh` | Alias for `bouli-garbage-collector`. |
| `dev-push-loop` | `development/push_loop.sh` | Pushes `main` to `origin` every 60 seconds forever. |
| `dev-lazy-gh` | `development/gh_lazy_init.sh` | Copies reusable GitHub Actions workflows into the current project and fills the PyPI project name from the current directory. |
| `lazy-folders` | `development/lazy_folders.py` | Manages a central portfolio for project-local lazy folders. Supports `init`, `add`, `list`, and `projects`. |
| `dev-lazy-folders` | `development/lazy_folders.py` | Alias for `lazy-folders`. |

### AI

| Command | Source | Purpose |
| --- | --- | --- |
| `ai-sbx-codex` | `ai/sbx_codex.sh` | Ensures an `openai` secret exists in `sbx`, creates a Codex sandbox named from the current directory, then runs it. |
| `ai-sbx-opencode` | `ai/sbx_opencode.sh` | Recreates and runs an OpenCode sandbox named from the current directory, with access to local Ollama. |
| `ai-lazy-init` | `ai/ai_lazy_init.sh` | Copies `ai/lazy-ai-config/` into the current directory, including `.agents/` skills and `.opencode/opencode.json`. |
| `ai-ralph-codex <iterations> [sleep_seconds]` | `ai/sbx_codex_ralph.sh` | Runs the Ralph Codex skill inside the current project's Codex sandbox repeatedly, optionally sleeping between runs. |
| `ai-ralph-opencode <iterations>` | `ai/sbx_opencode_ralph.sh` | Runs the Ralph OpenCode command inside the current project's OpenCode sandbox repeatedly. |

`ai/sbx_cline.sh` exists in the repository but is not linked by the Makefile. It appears to be a draft Cline sandbox setup script.

## Common Usage

Create a disposable development sandbox:

```sh
bouli-sandbox
```

Preview generated Python, JavaScript, and Go cleanup targets in the current project:

```sh
dev-garbage-collector --dry-run
```

Clean generated Python, JavaScript, and Go artifacts in the current project:

```sh
bouli-garbage-collector
```

The default cleanup is equivalent to:

```sh
dev-garbage-collector --all
```

Run a deeper JavaScript dependency cleanup when you intentionally want to remove `node_modules`:

```sh
dev-garbage-collector --dependencies
```

Run broader Go cache cleanup when you intentionally want to clear shared Go build and test caches:

```sh
dev-garbage-collector --go-cache
```

Copy reusable GitHub Actions workflows into the current project:

```sh
dev-lazy-gh
```

Initialize the default lazy folder portfolio at `~/lazy-dot-folders`:

```sh
lazy-folders init
```

Use a custom lazy folder portfolio path:

```sh
lazy-folders init ~/lazy-folders-portfolio
```

Add a project-local lazy folder to the configured portfolio:

```sh
lazy-folders add .notes
```

Run the same add operation without prompts, replacing same-path portfolio files:

```sh
lazy-folders add .notes --overwrite --yes
```

List saved folders for the current project:

```sh
lazy-folders list
```

List saved folders for a named portfolio project:

```sh
lazy-folders list --project app
```

Inspect one saved folder with tree-style nested output:

```sh
lazy-folders list --project app --folder .notes
```

List known portfolio projects:

```sh
lazy-folders projects
```

Start Codex in an `sbx` sandbox for the current project:

```sh
ai-sbx-codex
```

Start OpenCode in an `sbx` sandbox for the current project:

```sh
ai-sbx-opencode
```

Copy the OpenCode lazy AI config into the current directory:

```sh
ai-lazy-init
```

Run Ralph with Codex for five iterations, sleeping 30 seconds between runs:

```sh
ai-ralph-codex 5 30
```

Run Ralph with OpenCode for five iterations:

```sh
ai-ralph-opencode 5
```

## Generated Files and Paths

`ai-lazy-init` copies these paths into the current project:

- `.agents/`
- `.agents/.gitignore`
- `.opencode/opencode.json`
- `.opencode/.gitignore`

`dev-lazy-gh` copies these paths into the current project:

- `.github/workflows/ci.yml`
- `.github/workflows/publish-pypi.yml`

`lazy-folders init` creates the configured central portfolio directory and writes:

- default portfolio: `~/lazy-dot-folders`
- custom portfolio: the path passed to `lazy-folders init <portfolio-path>`
- config file: `$XDG_CONFIG_HOME/lazy-folders/config.yml`, or `~/.config/lazy-folders/config.yml` when `XDG_CONFIG_HOME` is unset
- config field: `portfolio_path`

`lazy-folders add <target-folder>` writes to:

- portfolio project folder: `<portfolio>/<resolved-project-folder>/`
- internal metadata: `<portfolio>/<resolved-project-folder>/.lazy-folders.yml`
- saved target folder: `<portfolio>/<resolved-project-folder>/<target-folder>/`
- local ignore file when accepted or `--yes` is used: `<target-folder>/.gitignore` containing `*`

`lazy-folders list` reads from:

- current project listing: `<portfolio>/<resolved-project-folder>/`
- explicit project listing: `<portfolio>/<project-folder>/`
- tree view: `<portfolio>/<project-folder>/<target-folder>/`

Normal listing hides internal metadata such as `.lazy-folders.yml`.

## Safety Notes

- `bouli-sandbox` runs `rm -r ~/sandbox`, so it deletes the existing `~/sandbox` directory before recreating it.
- `dev-push-loop` runs forever until interrupted with `Ctrl+C`.
- `make create` and `make clean` use `sudo` to modify `/usr/local/bin`.
- `bouli-garbage-collector` and `dev-garbage-collector` refuse to run from `/`, from your home directory, or from a directory without a project marker: `.git`, `pyproject.toml`, `package.json`, or `go.mod`.
- `bouli-garbage-collector` and `dev-garbage-collector` permanently remove matched project-local Python, JavaScript, and Go artifacts. Use `--dry-run` to preview the same target set without deleting anything.
- `--dependencies` also removes JavaScript dependencies such as `node_modules`; it is intentionally separate from the default cleanup.
- `--go-cache` also runs `go clean -cache -testcache`; it is intentionally separate from the default cleanup because it affects Go caches outside the project directory.
- `dev-lazy-gh` copies workflow files into the current project and rewrites `<pypi_project>` in `publish-pypi.yml` using the current directory name.
- `ai-ralph-codex` and `ai-ralph-opencode` expect matching `sbx` sandboxes for the current project name.
- `lazy-folders init` is safe to run repeatedly. It creates the portfolio directory if needed and updates only the lazy-folders YAML config file.
- `lazy-folders add` preserves destination-only portfolio files. Existing same-path files are skipped by default and replaced only with `--overwrite`.
- `lazy-folders add --overwrite` prompts before replacing same-path files unless `--yes` is also provided.
- `lazy-folders add` does not copy the target folder's top-level `.gitignore`, any `.git` directory, or internal `.lazy-folders.yml` metadata into saved content.
- `lazy-folders add` can create a missing local target-folder `.gitignore` containing `*`; `--yes` accepts that prompt automatically.

## Notes for AI Agents

Use this section as the operating guide when modifying the repository.

- Prefer updating source scripts and then documenting the matching installed command in this README.
- Keep command names in sync with the `Makefile`; it is the source of truth for installed symlinks.
- Do not assume every script is installed. `ai/sbx_cline.sh` is present but not currently linked by `make create`.
- Preserve the current version string in the README unless a version bump is explicitly requested. Version replacement is configured in `.bumpversion.toml`.
- The scripts are personal automation scripts, not a packaged CLI. Avoid adding dependency managers or project structure unless requested.
- Be careful with destructive shell commands. Several scripts intentionally remove local directories or generated files.
- When adding a new command, update both `Makefile` targets: `create` for the symlink and executable bit, and `clean` for removing the symlink.
- Keep paths explicit. Some scripts rely on `~/scripts`, `/usr/local/bin`, and macOS application paths.

## Maintenance Checklist

When changing behavior:

1. Update the relevant script.
2. Update the command table in this README.
3. Update installation links in the `Makefile` if a command is added, renamed, or removed.
4. Run a syntax check for edited shell scripts where practical:

   ```sh
   bash -n path/to/script.sh
   ```

5. For Python changes, run:

   ```sh
   python3 -m py_compile path/to/script.py
   ```
