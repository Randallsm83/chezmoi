#!/usr/bin/env python3
"""Resolve mpm search results into plausible mise install targets."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from collections import OrderedDict
from dataclasses import dataclass
from typing import Iterable

PACKAGE_BACKENDS = {"cargo", "gem", "npm", "pipx"}
SUPPORTED_MANAGERS = {
    "cargo",
    "gem",
    "npm",
    "pip",
    "pipx",
    "pwsh-gallery",
    "scoop",
    "winget",
}
SUMMARY_PATTERNS = (
    "would install",
    "ERROR",
    "error:",
    "there is nothing to install",
    "no binaries",
    "not a valid plugin",
)
WINGET_EXTENDED_PARSE_CRASH_RE = re.compile(
    r"Traceback \(most recent call last\):[\s\S]*"
    r"meta_package_manager[\\/]managers[\\/]winget\.py[\s\S]*"
    r"ValueError: not enough values to unpack \(expected 5, got 4\)\s*$"
)



@dataclass(frozen=True)
class Candidate:
    target: str
    source: str
    package: str


def split_csv(values: Iterable[str] | None) -> list[str]:
    items: list[str] = []
    for value in values or []:
        for item in value.split(","):
            item = item.strip()
            if item:
                items.append(item)
    return items


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="mpmise",
        description="Search with mpm, then dry-run plausible mise install targets.",
    )
    parser.add_argument("query", help="Package/tool name to search for.")
    parser.add_argument(
        "-Manager",
        "--manager",
        "--managers",
        dest="managers",
        action="append",
        default=[],
        help="Restrict mpm to managers such as cargo,npm,scoop,winget. Repeat or comma-separate.",
    )
    parser.add_argument(
        "-GitHubRepo",
        "--github-repo",
        dest="github_repos",
        action="append",
        default=[],
        help="Owner/repo to verify as github:owner/repo and aqua:owner/repo. Repeat or comma-separate.",
    )
    parser.add_argument("-Fuzzy", "--fuzzy", action="store_true", help="Use fuzzy mpm search.")
    parser.add_argument("-Extended", "--extended", action="store_true", help="Search descriptions too.")
    parser.add_argument("-Limit", "--limit", type=int, default=20, help="Maximum mpm rows to convert.")
    args = parser.parse_args(argv)
    if args.limit < 1 or args.limit > 200:
        parser.error("--limit must be between 1 and 200")
    args.managers = split_csv(args.managers)
    args.github_repos = split_csv(args.github_repos)
    unknown = [manager for manager in args.managers if manager not in SUPPORTED_MANAGERS]
    if unknown:
        parser.error(f"unsupported manager(s): {', '.join(unknown)}")
    return args


def run_checked(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


def build_mpm_args(
    args: argparse.Namespace,
    *,
    managers: list[str] | None = None,
    exclude_winget: bool = False,
) -> list[str]:
    command = ["mpm", "--no-summary", "--table-format", "json"]
    command.extend(f"--{manager}" for manager in (args.managers if managers is None else managers))
    if exclude_winget:
        command.append("--no-winget")
    command.append("search")
    if not args.fuzzy:
        command.append("--exact")
    if args.extended:
        command.append("--extended")
    command.append(args.query)
    return command


def is_winget_extended_parse_crash(output: str) -> bool:
    return bool(WINGET_EXTENDED_PARSE_CRASH_RE.search(output.strip()))


def build_winget_retry_args(args: argparse.Namespace) -> list[str] | None:
    if not args.extended:
        return None
    if args.managers:
        if "winget" not in args.managers:
            return None
        non_winget_managers = [manager for manager in args.managers if manager != "winget"]
        if not non_winget_managers:
            return None
        return build_mpm_args(args, managers=non_winget_managers)
    return build_mpm_args(args, exclude_winget=True)


def print_command(command: list[str]) -> None:
    print(" ".join(command))


def load_mpm_rows(data: object) -> list[dict[str, str]]:
    if not isinstance(data, dict):
        raise ValueError("mpm JSON root was not an object")

    rows: list[dict[str, str]] = []
    for manager_id, manager_data in data.items():
        if not isinstance(manager_data, dict):
            raise ValueError(f"mpm JSON for manager '{manager_id}' was not an object")
        packages = manager_data.get("packages")
        if not isinstance(packages, list):
            raise ValueError(f"mpm JSON for manager '{manager_id}' has no packages list")
        for index, package in enumerate(packages):
            if not isinstance(package, dict):
                raise ValueError(f"mpm JSON package {index} for manager '{manager_id}' was not an object")
            rows.append(
                {
                    "Manager": str(manager_id),
                    "Package": str(package.get("id") or ""),
                    "Name": str(package.get("name") or ""),
                    "Version": str(package.get("latest_version") or ""),
                    "Description": str(package.get("description") or ""),
                }
            )
    return rows


def print_table(rows: list[dict[str, object]], columns: list[str]) -> None:
    if not rows:
        return
    widths = {column: len(column) for column in columns}
    for row in rows:
        for column in columns:
            widths[column] = max(widths[column], len(str(row.get(column, ""))))
    print("  ".join(column.ljust(widths[column]) for column in columns))
    print("  ".join("-" * widths[column] for column in columns))
    for row in rows:
        print("  ".join(str(row.get(column, "")).ljust(widths[column]) for column in columns))


def add_candidate(candidates: OrderedDict[str, Candidate], target: str, source: str, package: str) -> None:
    if target and target not in candidates:
        candidates[target] = Candidate(target, source, package)


def build_candidates(rows: list[dict[str, str]], github_repos: list[str], limit: int) -> OrderedDict[str, Candidate]:
    candidates: OrderedDict[str, Candidate] = OrderedDict()
    for row in rows[:limit]:
        manager = row["Manager"]
        package = row["Package"]
        if manager == "cargo":
            add_candidate(candidates, f"cargo:{package}", manager, package)
        elif manager == "gem":
            add_candidate(candidates, f"gem:{package}", manager, package)
        elif manager == "npm":
            add_candidate(candidates, f"npm:{package}", manager, package)
        elif manager in {"pip", "pipx"}:
            add_candidate(candidates, f"pipx:{package}", manager, package)
        elif manager == "winget":
            match = re.match(r"^([A-Za-z0-9_-]+)\.([A-Za-z0-9_-]+)$", package)
            if match:
                owner, repo = match.groups()
                add_candidate(candidates, f"github:{owner}/{repo}", manager, package)
                if row["Name"]:
                    add_candidate(candidates, f"github:{owner}/{row['Name']}", manager, package)

    for repo in github_repos:
        if not re.match(r"^[^/\s]+/[^/\s]+$", repo):
            print(f"WARNING: Skipping invalid GitHub repo '{repo}' (expected owner/repo).", file=sys.stderr)
            continue
        add_candidate(candidates, f"github:{repo}", "manual", repo)
        add_candidate(candidates, f"aqua:{repo}", "manual", repo)
    return candidates


def summarize_output(output: str) -> str:
    lines = [line.strip() for line in output.splitlines() if line.strip()]
    for line in lines:
        if any(pattern in line for pattern in SUMMARY_PATTERNS):
            return line
    return lines[0] if lines else ""


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    for command in ("mpm", "mise"):
        if shutil.which(command) is None:
            print(f"WARNING: {command} not found.", file=sys.stderr)
            return 127

    mpm_args = build_mpm_args(args)

    print_command(mpm_args)
    proc = run_checked(mpm_args)
    if proc.returncode != 0 and is_winget_extended_parse_crash(proc.stdout):
        retry_args = build_winget_retry_args(args)
        if retry_args is not None:
            print(
                "WARNING: mpm winget extended search hit a known parser crash; retrying without winget.",
                file=sys.stderr,
            )
            print_command(retry_args)
            proc = run_checked(retry_args)
    if proc.returncode != 0:
        print(proc.stdout, end="")
        print("WARNING: mpm search failed.", file=sys.stderr)
        return proc.returncode
    if not proc.stdout.strip():
        print("WARNING: mpm returned no JSON output.", file=sys.stderr)
        return 1

    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        print(f"WARNING: Could not parse mpm JSON output: {exc}", file=sys.stderr)
        return 1

    try:
        rows = load_mpm_rows(data)
    except ValueError as exc:
        print(f"WARNING: Unexpected mpm JSON output: {exc}", file=sys.stderr)
        return 1
    if not rows:
        print(f"WARNING: No mpm packages matched '{args.query}'.", file=sys.stderr)
        return 0

    print("\nmpm matches\n")
    print_table(rows[: args.limit], ["Manager", "Package", "Name", "Version", "Description"])

    candidates = build_candidates(rows, args.github_repos, args.limit)
    if not candidates:
        print(
            "WARNING: No direct mise candidates could be inferred. Use -GitHubRepo owner/repo "
            "for GitHub-release tools, or install via the listed package manager.",
            file=sys.stderr,
        )
        return 0

    print("\nmise dry-runs\n")
    result_rows: list[dict[str, object]] = []
    for candidate in candidates.values():
        target = f"{candidate.target}@latest"
        proc = run_checked(["mise", "install", "--dry-run", target])
        backend = candidate.target.split(":", 1)[0]
        is_package_backend = backend in PACKAGE_BACKENDS
        if proc.returncode:
            status = "FAIL"
        elif is_package_backend:
            status = "CHECK"
        else:
            status = "OK"
        detail = summarize_output(proc.stdout)
        if proc.returncode == 0 and is_package_backend:
            detail = f"{detail}; dry-run does not prove this package exposes a CLI binary"
        result_rows.append(
            {
                "Status": status,
                "Target": candidate.target,
                "Source": candidate.source,
                "Package": candidate.package,
                "Detail": detail,
            }
        )
    print_table(result_rows, ["Status", "Target", "Source", "Package", "Detail"])
    print("\nUse an OK target with: mise use -g <target>")
    print("CHECK means mise accepts the target, but the ecosystem package may still be a library or may not expose a CLI.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
