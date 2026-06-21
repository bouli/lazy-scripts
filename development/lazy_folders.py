#!/usr/bin/env python3

import argparse
import os
import sys
from pathlib import Path


APP_NAME = "lazy-folders"
DEFAULT_PORTFOLIO = "~/lazy-dot-folders"


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


def write_config(portfolio_path: Path) -> Path:
    path = config_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        f"portfolio_path: {yaml_single_quote(str(portfolio_path))}\n",
        encoding="utf-8",
    )
    return path


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
