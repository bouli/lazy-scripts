# Bouli Lazy Scripts v0.3.1

Personal command-line scripts for development, AI sandbox workflows, and OBS streaming automation.

This repository is intended to be installed by creating symlinks from the scripts in this repo into `/usr/local/bin`. After installation, the commands can be run from any shell.

## Repository Layout

```text
.
├── Makefile                         # Installs/removes command symlinks
├── ai/                              # AI sandbox helper scripts
│   ├── afk_ralph.sh
│   ├── ai_lazy_init.sh
│   ├── sbx_cline.sh
│   ├── sbx_codex.sh
│   ├── sbx_opencode.sh
│   └── lazy-ai-config/opencode.json
├── development/                     # General development utilities
│   ├── clean_garbage_collector.sh
│   ├── push_loop.sh
│   └── sandbox_launcher.sh
└── streaming/                       # OBS and streaming helpers
    ├── background.sh
    ├── bs.py
    ├── bsc.sh
    ├── bsi.sh
    ├── bso.sh
    ├── bss.sh
    └── interval.sh
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
- `ffmpeg`
- OBS installed at `/Applications/OBS.app`
- Python 3 for `bs`
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

`make clean` only removes the command symlinks listed in the Makefile. It does not delete this repository or generated streaming files.

## Installed Commands

### Development

| Command | Source | Purpose |
| --- | --- | --- |
| `bouli-sandbox` | `development/sandbox_launcher.sh` | Recreates `~/sandbox` with `uv`, runs `uv sync`, and opens it in VS Code. |
| `bouli-garbage-collector` | `development/clean_garbage_collector.sh` | Removes `.venv` and `__pycache__` folders from the current directory and a small fixed depth below it. |
| `push-loop` | `development/push_loop.sh` | Pushes `main` to `origin` every 60 seconds forever. |

### AI

| Command | Source | Purpose |
| --- | --- | --- |
| `ai-sbx-codex` | `ai/sbx_codex.sh` | Ensures an `openai` secret exists in `sbx`, creates a Codex sandbox named from the current directory, then runs it. |
| `ai-sbx-opencode` | `ai/sbx_opencode.sh` | Recreates and runs an OpenCode sandbox named from the current directory, with access to local Ollama. |
| `ai-lazy-init` | `ai/ai_lazy_init.sh` | Copies `ai/lazy-ai-config/` into the current directory. |
| `ralph-afk <iterations>` | `ai/afk_ralph.sh` | Runs `ralph` inside the `current-ai` sandbox repeatedly. |

`ai/sbx_cline.sh` exists in the repository but is not linked by the Makefile. It appears to be a draft Cline sandbox setup script.

### Streaming

| Command | Source | Purpose |
| --- | --- | --- |
| `bs <message>` | `streaming/bs.py` | Writes a wrapped message to `streaming/public/message.txt` for OBS text sources. |
| `bsi` | `streaming/bsi.sh` | Runs `bouliobs interval` through `uvx`. |
| `bsc` | `streaming/bsc.sh` | Runs `bouliobs cam` through `uvx`. |
| `bss` | `streaming/bss.sh` | Runs `bouliobs screen` through `uvx`. |
| `bso` | `streaming/bso.sh` | Opens OBS. |
| `bouli-streaming-background` | `streaming/background.sh` | Concatenates WAV files from `~/scripts/streaming/inputs/background/` into `~/scripts/streaming/public/background.wav`. |
| `bouli-streaming-interval` | `streaming/interval.sh` | Builds a forward-and-reverse interval MP4 from `~/scripts/streaming/inputs/interval/video.mp4` and copies `video.txt` into the public folder. |

## Common Usage

Create a disposable development sandbox:

```sh
bouli-sandbox
```

Clean generated Python environments and caches near the current directory:

```sh
bouli-garbage-collector
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

Write a message for OBS:

```sh
bs Starting soon
```

This writes to:

```text
streaming/public/message.txt
```

## Generated Files and Paths

The streaming scripts use these generated folders:

- `~/scripts/streaming/wrk/`
- `~/scripts/streaming/public/`

Expected input folders for media scripts:

- `~/scripts/streaming/inputs/background/` containing `.wav` files
- `~/scripts/streaming/inputs/interval/` containing `video.mp4` and `video.txt`

These input folders are not created by `make create`.

## Safety Notes

- `bouli-sandbox` runs `rm -r ~/sandbox`, so it deletes the existing `~/sandbox` directory before recreating it.
- `push-loop` runs forever until interrupted with `Ctrl+C`.
- `make create` and `make clean` use `sudo` to modify `/usr/local/bin`.
- `bouli-garbage-collector` permanently removes matching `.venv` and `__pycache__` directories near the current working directory.
- The streaming build scripts delete files inside `~/scripts/streaming/wrk/` before rebuilding media.

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
   python3 -m py_compile streaming/bs.py
   ```
