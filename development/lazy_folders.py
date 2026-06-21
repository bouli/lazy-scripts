#!/usr/bin/env python3

import argparse
import datetime as dt
import hashlib
import os
import re
import shutil
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
LOCAL_GITIGNORE_CONTENT = "*\n"


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


@dataclass(frozen=True)
class CopySummary:
    copied: int
    skipped: int
    replaced: int


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


def configured_portfolio_path() -> Path:
    path = config_path()
    values = read_simple_yaml(path)
    configured = values.get("portfolio_path")
    if not configured:
        raise RuntimeError(
            f"Config is missing portfolio_path. Run {APP_NAME} init first."
        )
    portfolio_path = normalize_path(configured)
    portfolio_path.mkdir(parents=True, exist_ok=True)
    return portfolio_path


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


def project_target_path(identity: ProjectIdentity, target_folder: str) -> Path:
    return identity.project_root / target_folder


def warn_non_dot_target(target_folder: str) -> None:
    if not Path(target_folder).name.startswith("."):
        print(
            f"Warning: target folder {target_folder!r} is not a dot-folder.",
            file=sys.stderr,
        )


def ensure_local_target_gitignore(target_path: Path, *, yes: bool = False) -> None:
    gitignore = target_path / ".gitignore"
    if gitignore.exists():
        return

    if confirm(
        f"Create {gitignore} containing '*' so the local folder stays ignored?",
        yes=yes,
    ):
        target_path.mkdir(parents=True, exist_ok=True)
        gitignore.write_text(LOCAL_GITIGNORE_CONTENT, encoding="utf-8")


def ensure_local_target_gitignores(target_paths: list[Path], *, yes: bool = False) -> None:
    missing = [target_path for target_path in target_paths if not (target_path / ".gitignore").exists()]
    if not missing:
        return

    if len(missing) == 1:
        ensure_local_target_gitignore(missing[0], yes=yes)
        return

    formatted = ", ".join(str(target_path) for target_path in missing)
    if confirm(
        f"Create .gitignore containing '*' in these local folders: {formatted}?",
        yes=yes,
    ):
        for target_path in missing:
            target_path.mkdir(parents=True, exist_ok=True)
            (target_path / ".gitignore").write_text(
                LOCAL_GITIGNORE_CONTENT,
                encoding="utf-8",
            )


def excluded_from_copy(path: Path, relative_path: Path) -> bool:
    parts = relative_path.parts
    if ".git" in parts:
        return True
    if relative_path == Path(".gitignore"):
        return True
    if relative_path == Path(METADATA_FILE):
        return True
    return False


def iter_copy_files(source: Path) -> list[Path]:
    files: list[Path] = []
    for root, dirnames, filenames in os.walk(source):
        root_path = Path(root)
        dirnames[:] = [
            dirname
            for dirname in dirnames
            if not excluded_from_copy(root_path / dirname, (root_path / dirname).relative_to(source))
        ]
        for filename in filenames:
            path = root_path / filename
            relative_path = path.relative_to(source)
            if excluded_from_copy(path, relative_path):
                continue
            files.append(relative_path)
    return sorted(files)


def summarize_pending_copy(source: Path, destination: Path) -> tuple[int, int]:
    new_files = 0
    existing_files = 0
    for relative_path in iter_copy_files(source):
        if (destination / relative_path).exists():
            existing_files += 1
        else:
            new_files += 1
    return new_files, existing_files


def preview_existing_target(path: Path) -> None:
    print(f"Existing portfolio target: {path}")
    if not path.exists():
        return

    entries = sorted(
        entry.relative_to(path)
        for entry in path.rglob("*")
        if entry.name != METADATA_FILE and ".git" not in entry.relative_to(path).parts
    )
    if not entries:
        print("  (empty)")
        return
    for entry in entries[:40]:
        suffix = "/" if (path / entry).is_dir() else ""
        print(f"  {entry}{suffix}")
    if len(entries) > 40:
        print(f"  ... {len(entries) - 40} more")


def visible_portfolio_target_dirs(project_path: Path) -> list[Path]:
    return sorted(
        entry
        for entry in project_path.iterdir()
        if entry.is_dir() and entry.name not in {".git", METADATA_FILE}
    )


def print_tree_fallback(root: Path) -> None:
    print(root)
    entries = sorted(root.rglob("*"), key=lambda path: path.relative_to(root).parts)
    visible_entries = [
        entry
        for entry in entries
        if ".git" not in entry.relative_to(root).parts
        and entry.relative_to(root) != Path(METADATA_FILE)
    ]

    for index, entry in enumerate(visible_entries):
        relative = entry.relative_to(root)
        connector = "`--" if index == len(visible_entries) - 1 else "|--"
        indent = "    " * (len(relative.parts) - 1)
        suffix = "/" if entry.is_dir() else ""
        print(f"{indent}{connector} {entry.name}{suffix}")


def print_tree(path: Path) -> None:
    tree_command = shutil.which("tree")
    if tree_command:
        subprocess.run([tree_command, "-a", str(path)], check=True)
        return
    print_tree_fallback(path)


def list_command(args: argparse.Namespace) -> int:
    portfolio_path = configured_portfolio_path()
    project_folder = args.project or resolve_project_identity().project_folder
    project_path = portfolio_path / project_folder

    if not project_path.is_dir():
        raise RuntimeError(f"Portfolio project does not exist: {project_folder}")

    if args.folder:
        target_path = project_path / args.folder
        if not target_path.is_dir():
            raise RuntimeError(
                f"Portfolio target folder does not exist: {project_folder}/{args.folder}"
            )
        print_tree(target_path)
        return 0

    folders = visible_portfolio_target_dirs(project_path)
    if not folders:
        print(f"No saved target folders for project: {project_folder}")
        return 0

    for folder in folders:
        print(folder.name)
    return 0


def projects_command(args: argparse.Namespace) -> int:
    portfolio_path = configured_portfolio_path()
    projects = sorted(entry for entry in portfolio_path.iterdir() if entry.is_dir())

    if not projects:
        print(f"No portfolio projects found in: {portfolio_path}")
        return 0

    for project in projects:
        print(project.name)
    return 0


def copy_merge(source: Path, destination: Path, *, overwrite: bool = False) -> CopySummary:
    copied = 0
    skipped = 0
    replaced = 0
    destination.mkdir(parents=True, exist_ok=True)

    for relative_path in iter_copy_files(source):
        source_file = source / relative_path
        destination_file = destination / relative_path
        destination_file.parent.mkdir(parents=True, exist_ok=True)

        if destination_file.exists():
            if overwrite:
                shutil.copy2(source_file, destination_file)
                replaced += 1
            else:
                skipped += 1
            continue

        shutil.copy2(source_file, destination_file)
        copied += 1

    return CopySummary(copied=copied, skipped=skipped, replaced=replaced)


def init_command(args: argparse.Namespace) -> int:
    portfolio_path = normalize_path(args.portfolio_path or DEFAULT_PORTFOLIO)
    portfolio_path.mkdir(parents=True, exist_ok=True)
    written_config = write_config(portfolio_path)

    print(f"Portfolio path: {portfolio_path}")
    print(f"Config path: {written_config}")
    return 0


def add_command(args: argparse.Namespace) -> int:
    portfolio_path = configured_portfolio_path()
    identity = resolve_project_identity()
    target_folder = args.target_folder
    source_path = project_target_path(identity, target_folder)

    if not source_path.is_dir():
        raise RuntimeError(f"Local target folder does not exist: {source_path}")

    warn_non_dot_target(target_folder)
    print(f"Project folder: {identity.project_folder}")
    ensure_local_target_gitignore(source_path, yes=args.yes)

    metadata_path = ensure_portfolio_project_metadata(
        portfolio_path,
        identity,
        yes=args.yes,
    )
    project_path = metadata_path.parent
    destination_path = project_path / target_folder

    if destination_path.exists() and not args.yes:
        preview_existing_target(destination_path)
        if not confirm("Write into the existing portfolio target folder?", yes=args.yes):
            raise RuntimeError("Refusing to write into existing portfolio target folder.")

    new_files, existing_files = summarize_pending_copy(source_path, destination_path)
    if args.overwrite and existing_files and not args.yes:
        if not confirm(
            f"Replace {existing_files} same-path file(s) in the portfolio target?",
            yes=args.yes,
        ):
            raise RuntimeError("Refusing to replace existing portfolio files.")

    summary = copy_merge(source_path, destination_path, overwrite=args.overwrite)
    print(
        "Summary: "
        f"copied={summary.copied} "
        f"skipped={summary.skipped} "
        f"replaced={summary.replaced}"
    )
    if new_files == 0 and existing_files == 0:
        print("No copyable files found.")
    return 0


def pull_command(args: argparse.Namespace) -> int:
    portfolio_path = configured_portfolio_path()
    identity = resolve_project_identity()
    source_project_folder = args.use_template or identity.project_folder
    source_project_path = portfolio_path / source_project_folder

    if not source_project_path.is_dir():
        raise RuntimeError(f"Portfolio project does not exist: {source_project_folder}")

    if args.use_template:
        print(f"Template project folder: {source_project_folder}")
    else:
        print(f"Project folder: {identity.project_folder}")

    if args.target_folder:
        source_targets = [source_project_path / args.target_folder]
        if not source_targets[0].is_dir():
            raise RuntimeError(
                f"Portfolio target folder does not exist: "
                f"{source_project_folder}/{args.target_folder}"
            )
    else:
        source_targets = visible_portfolio_target_dirs(source_project_path)
        if not source_targets:
            print(f"No saved target folders for project: {source_project_folder}")
            return 0

    destination_targets = [
        identity.project_root / source_target.name for source_target in source_targets
    ]
    ensure_local_target_gitignores(destination_targets, yes=args.yes)

    total_existing_files = 0
    for source_target, destination_target in zip(source_targets, destination_targets):
        _, existing_files = summarize_pending_copy(source_target, destination_target)
        total_existing_files += existing_files

    if args.overwrite and total_existing_files and not args.yes:
        if not confirm(
            f"Replace {total_existing_files} same-path file(s) in local target folder(s)?",
            yes=args.yes,
        ):
            raise RuntimeError("Refusing to replace existing local files.")

    total = CopySummary(copied=0, skipped=0, replaced=0)
    for source_target, destination_target in zip(source_targets, destination_targets):
        summary = copy_merge(source_target, destination_target, overwrite=args.overwrite)
        total = CopySummary(
            copied=total.copied + summary.copied,
            skipped=total.skipped + summary.skipped,
            replaced=total.replaced + summary.replaced,
        )
        print(
            f"{source_target.name}: "
            f"copied={summary.copied} "
            f"skipped={summary.skipped} "
            f"replaced={summary.replaced}"
        )

    print(
        "Summary: "
        f"copied={total.copied} "
        f"skipped={total.skipped} "
        f"replaced={total.replaced}"
    )
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

    add_parser = subparsers.add_parser(
        "add",
        help="Copy a project-local target folder into the portfolio.",
    )
    add_parser.add_argument("target_folder", help="Project-local folder to add.")
    add_parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Replace same-path files in the portfolio after confirmation.",
    )
    add_parser.add_argument(
        "--yes",
        action="store_true",
        help="Accept prompts for non-interactive use.",
    )
    add_parser.set_defaults(func=add_command)

    pull_parser = subparsers.add_parser(
        "pull",
        help="Copy saved target folders from the portfolio into the current project.",
    )
    pull_parser.add_argument(
        "target_folder",
        nargs="?",
        help="Saved target folder to restore. Defaults to all saved folders.",
    )
    pull_parser.add_argument(
        "--use-template",
        help="Portfolio project folder to use as the pull source.",
    )
    pull_parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Replace same-path local files after confirmation.",
    )
    pull_parser.add_argument(
        "--yes",
        action="store_true",
        help="Accept prompts for non-interactive use.",
    )
    pull_parser.set_defaults(func=pull_command)

    list_parser = subparsers.add_parser(
        "list",
        help="List saved target folders for a portfolio project.",
    )
    list_parser.add_argument(
        "--project",
        help="Portfolio project folder to inspect. Defaults to the current project.",
    )
    list_parser.add_argument(
        "--folder",
        help="Saved target folder to show in tree mode.",
    )
    list_parser.set_defaults(func=list_command)

    projects_parser = subparsers.add_parser(
        "projects",
        help="List known portfolio project folders.",
    )
    projects_parser.set_defaults(func=projects_command)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except RuntimeError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
