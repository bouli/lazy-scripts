#!/usr/bin/env python3

import argparse
import datetime as dt
import hashlib
import os
import re
import subprocess
import sys
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse


APP_NAME = "lazy-folders"
DEFAULT_PORTFOLIO = "~/lazy-dot-folders"
METADATA_FILE = ".lazy-folders.yml"
METADATA_VERSION = "1"


@dataclass(frozen=True)
class ProjectIdentity:
    project_folder: str
    raw_project_name: str
    resolution_method: str
    identity_kind: str
    identity_key: str
    project_root: Path
    git_root: Path | None = None
    selected_remote_name: str | None = None
    remote_url: str | None = None
    normalized_remote_identity: str | None = None
    repo_name: str | None = None


def config_path() -> Path:
    config_home = os.environ.get("XDG_CONFIG_HOME")
    if config_home:
        base = Path(config_home).expanduser()
    else:
        base = Path.home() / ".config"
    return base / APP_NAME / "config.yml"


def normalize_path(path: str) -> Path:
    return Path(path).expanduser().resolve()


def yaml_single_quote(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def yaml_unquote(value: str) -> str:
    value = value.strip()
    if value.startswith("'") and value.endswith("'"):
        return value[1:-1].replace("''", "'")
    return value


def read_simple_yaml(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}

    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or ":" not in line:
            continue
        key, value = line.split(":", 1)
        values[key.strip()] = yaml_unquote(value)
    return values


def write_simple_yaml(path: Path, values: dict[str, str]) -> None:
    lines = [f"{key}: {yaml_single_quote(value)}" for key, value in values.items()]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_config(portfolio_path: Path) -> Path:
    path = config_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        f"portfolio_path: {yaml_single_quote(str(portfolio_path))}\n",
        encoding="utf-8",
    )
    return path


def git_output(cwd: Path, *args: str) -> str | None:
    try:
        result = subprocess.run(
            ["git", "-C", str(cwd), *args],
            check=True,
            capture_output=True,
            text=True,
        )
    except (FileNotFoundError, subprocess.CalledProcessError):
        return None
    return result.stdout.strip()


def git_root(cwd: Path) -> Path | None:
    output = git_output(cwd, "rev-parse", "--show-toplevel")
    if not output:
        return None
    return Path(output).resolve()


def ordered_remotes(cwd: Path) -> list[str]:
    output = git_output(cwd, "remote")
    if not output:
        return []

    remotes = [line.strip() for line in output.splitlines() if line.strip()]
    preferred = [remote for remote in ("upstream", "origin") if remote in remotes]
    remaining = sorted(remote for remote in remotes if remote not in {"upstream", "origin"})
    return preferred + remaining


def remote_url(cwd: Path, remote: str) -> str | None:
    return git_output(cwd, "remote", "get-url", remote)


def repo_name_from_remote_url(url: str) -> str:
    cleaned = url.strip().rstrip("/")
    cleaned = cleaned.split("?", 1)[0].split("#", 1)[0]
    name = re.split(r"[/\\:]", cleaned)[-1]
    if name.endswith(".git"):
        name = name[:-4]
    return name


def normalized_remote_identity(url: str) -> str:
    cleaned = url.strip().rstrip("/")
    cleaned = cleaned.split("?", 1)[0].split("#", 1)[0]
    if cleaned.endswith(".git"):
        cleaned = cleaned[:-4]

    parsed = urlparse(cleaned)
    if parsed.scheme and parsed.netloc and parsed.path:
        return f"{parsed.netloc}{parsed.path}".strip("/").lower()

    scp_match = re.match(r"^[^@]+@([^:]+):(.+)$", cleaned)
    if scp_match:
        host, path = scp_match.groups()
        return f"{host}/{path}".strip("/").lower()

    return cleaned.lower()


def sanitize_project_folder(raw_name: str) -> str:
    ascii_name = (
        unicodedata.normalize("NFKD", raw_name).encode("ascii", "ignore").decode("ascii")
    )
    sanitized = re.sub(r"[^A-Za-z0-9._-]+", "-", ascii_name)
    sanitized = re.sub(r"-+", "-", sanitized).strip("-")
    if sanitized:
        return sanitized

    fallback = "project-" + hashlib.sha256(raw_name.encode("utf-8")).hexdigest()[:10]
    print(
        f"Warning: project name {raw_name!r} could not be sanitized; using {fallback}.",
        file=sys.stderr,
    )
    return fallback


def resolve_project_identity(cwd: Path | None = None) -> ProjectIdentity:
    current = (cwd or Path.cwd()).resolve()
    root = git_root(current)

    if root:
        for remote in ordered_remotes(root):
            url = remote_url(root, remote)
            if not url:
                continue
            repo_name = repo_name_from_remote_url(url)
            project_folder = sanitize_project_folder(repo_name)
            return ProjectIdentity(
                project_folder=project_folder,
                raw_project_name=repo_name,
                resolution_method="git-remote",
                identity_kind="remote",
                identity_key=normalized_remote_identity(url),
                project_root=root,
                git_root=root,
                selected_remote_name=remote,
                remote_url=url,
                normalized_remote_identity=normalized_remote_identity(url),
                repo_name=repo_name,
            )

        raw_name = root.name
        return ProjectIdentity(
            project_folder=sanitize_project_folder(raw_name),
            raw_project_name=raw_name,
            resolution_method="git-root",
            identity_kind="local-path",
            identity_key=str(root),
            project_root=root,
            git_root=root,
        )

    raw_name = current.name
    return ProjectIdentity(
        project_folder=sanitize_project_folder(raw_name),
        raw_project_name=raw_name,
        resolution_method="cwd",
        identity_kind="local-path",
        identity_key=str(current),
        project_root=current,
    )


def identity_metadata(identity: ProjectIdentity, existing: dict[str, str] | None = None) -> dict[str, str]:
    now = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
    metadata = {
        "version": METADATA_VERSION,
        "project_folder": identity.project_folder,
        "raw_project_name": identity.raw_project_name,
        "resolution_method": identity.resolution_method,
        "identity_kind": identity.identity_kind,
        "identity_key": identity.identity_key,
        "project_root": str(identity.project_root),
        "first_created_at": (existing or {}).get("first_created_at", now),
        "updated_at": now,
    }

    optional = {
        "git_root": str(identity.git_root) if identity.git_root else "",
        "selected_remote_name": identity.selected_remote_name or "",
        "remote_url": identity.remote_url or "",
        "normalized_remote_identity": identity.normalized_remote_identity or "",
        "repo_name": identity.repo_name or "",
    }
    metadata.update({key: value for key, value in optional.items() if value})
    return metadata


def metadata_collides(existing: dict[str, str], identity: ProjectIdentity) -> bool:
    if not existing:
        return False
    return (
        existing.get("identity_kind") not in {None, identity.identity_kind}
        or existing.get("identity_key") not in {None, identity.identity_key}
    )


def confirm(prompt: str, yes: bool = False) -> bool:
    if yes:
        return True
    if not sys.stdin.isatty():
        raise RuntimeError(f"{prompt} Re-run with --yes to confirm non-interactively.")
    answer = input(f"{prompt} [y/N] ").strip().lower()
    return answer in {"y", "yes"}


def ensure_portfolio_project_metadata(
    portfolio_path: Path,
    identity: ProjectIdentity,
    *,
    yes: bool = False,
    explicit_destination: bool = False,
) -> Path:
    project_path = portfolio_path / identity.project_folder
    metadata_path = project_path / METADATA_FILE
    existing = read_simple_yaml(metadata_path)

    if metadata_collides(existing, identity) and not explicit_destination:
        message = (
            f"Warning: portfolio project {identity.project_folder!r} is already "
            "associated with a different project identity."
        )
        print(message, file=sys.stderr)
        if not confirm("Continue despite this collision?", yes=yes):
            raise RuntimeError("Refusing to write portfolio metadata after identity collision.")

    project_path.mkdir(parents=True, exist_ok=True)
    write_simple_yaml(metadata_path, identity_metadata(identity, existing))
    return metadata_path


def init_command(args: argparse.Namespace) -> int:
    portfolio_path = normalize_path(args.portfolio_path or DEFAULT_PORTFOLIO)
    portfolio_path.mkdir(parents=True, exist_ok=True)
    written_config = write_config(portfolio_path)

    print(f"Portfolio path: {portfolio_path}")
    print(f"Config path: {written_config}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog=APP_NAME,
        description="Sync project-local lazy folders into a central portfolio.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    init_parser = subparsers.add_parser(
        "init",
        help="Create the portfolio directory and save its path in config.",
    )
    init_parser.add_argument(
        "portfolio_path",
        nargs="?",
        help=f"Portfolio directory to configure. Defaults to {DEFAULT_PORTFOLIO}.",
    )
    init_parser.set_defaults(func=init_command)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
