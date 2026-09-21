#!/usr/bin/env python3
"""Run unchanged, portable Mira Swift sources/tests in a generated Swift package.

This is supplementary domain validation, not an iOS build or Simulator test.
On Windows the script re-executes itself through WSL. An installed Swift or the
toolchain under .build/swift-linux is required; nothing is downloaded here.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IMPORTS = re.compile(r"^\s*(?:@testable\s+)?import\s+(\w+)", re.MULTILINE)
ALLOWED_IMPORTS = {"Foundation", "FoundationNetworking", "FoundationModels", "XCTest", "Mira"}
EXCLUDED = {
    "Mira/Services/CaseSearchEngine.swift": "Uses SwiftData ConversationCaseEntity, AdjustmentEntity and PendingInvitationEntity.",
    "Mira/Services/JevIntentRouter.swift": "Default configuration uses JevSettingsStore / Apple Security Keychain.",
    "MiraTests/JevIntentRouterTests.swift": "Depends on JevIntentRouter's Apple Security configuration boundary.",
    "MiraTests/PixelCatAssetMappingTests.swift": "CatMood belongs to the SwiftUI design system.",
    "MiraTests/ReminderPlanTests.swift": "ReminderPlan currently imports Apple UserNotifications.",
}


def wsl_path(path: str) -> str:
    return subprocess.check_output(["wsl.exe", "--exec", "wslpath", "-a", Path(path).resolve().as_posix()], text=True).strip()


def through_wsl(args) -> int:
    command = ["wsl.exe", "--exec", "python3", wsl_path(__file__), "--jobs", str(args.jobs)]
    if args.swift:
        command += ["--swift", wsl_path(args.swift) if re.match(r"^[A-Za-z]:", args.swift) else args.swift]
    if args.parse_only:
        command.append("--parse-only")
    if args.skip_parse:
        command.append("--skip-parse")
    return subprocess.call(command)


def find_swift(explicit: str | None) -> Path:
    candidates = [explicit, os.environ.get("SWIFT_BIN"), shutil.which("swift")]
    candidates += [str(path) for path in sorted((ROOT / ".build/swift-linux").glob("swift-*/usr/bin/swift"), reverse=True)]
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return Path(candidate).absolute()
    raise SystemExit("Swift not found. Pass --swift /absolute/path/to/swift or set SWIFT_BIN.")


def run_logged(command: list[str], log: Path) -> int:
    with log.open("w", encoding="utf-8") as output:
        process = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace")
        assert process.stdout is not None
        for line in process.stdout:
            output.write(line)
            output.flush()
            print(line, end="", flush=True)
        return process.wait()


def selected(paths: list[Path], excluded: dict[str, str]) -> list[Path]:
    included = []
    for path in paths:
        relative = path.relative_to(ROOT).as_posix()
        source = path.read_text(encoding="utf-8")
        unavailable = set(IMPORTS.findall(source)) - ALLOWED_IMPORTS
        if relative in EXCLUDED:
            excluded[relative] = EXCLUDED[relative]
        elif unavailable:
            excluded[relative] = "Apple/platform imports: " + ", ".join(sorted(unavailable))
        elif path.parent.name == "MiraTests" and re.search(r"\b(?:MiraStore|ModelContainer|ModelContext|CaseSearchEngine|ConversationCaseEntity|AdjustmentEntity|PendingInvitationEntity)\b", source):
            excluded[relative] = "Depends on the app store / SwiftData persistence."
        else:
            included.append(path)
    return included


def copy_exact(paths: list[Path], destination: Path) -> dict[str, str]:
    destination.mkdir(parents=True, exist_ok=True)
    expected_parent = destination.resolve()
    current_names = {path.name for path in paths}
    if len(current_names) != len(paths):
        raise SystemExit("Duplicate filenames in generated target; use distinct names before proceeding.")
    for stale in destination.glob("*.swift"):
        if stale.resolve().parent != expected_parent:
            raise SystemExit("Refusing to modify a generated source symlink outside the package.")
        if stale.name not in current_names:
            stale.unlink()
    fingerprints = {}
    for path in paths:
        target = destination / path.name
        if target.resolve().parent != expected_parent:
            raise SystemExit("Refusing to write outside generated target directory.")
        data = path.read_bytes()
        if not target.exists() or target.read_bytes() != data:
            target.write_bytes(data)
        fingerprints[path.relative_to(ROOT).as_posix()] = hashlib.sha256(data).hexdigest()
    return fingerprints


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--swift", help="Swift executable (auto-detected by default)")
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--parse-only", action="store_true", help="Parse all app/test Swift files without type-checking")
    parser.add_argument("--skip-parse", action="store_true", help="Only run the portable SwiftPM tests")
    args = parser.parse_args()
    if args.jobs < 1 or args.jobs > 32:
        parser.error("--jobs must be between 1 and 32")
    if args.parse_only and args.skip_parse:
        parser.error("--parse-only and --skip-parse cannot be combined")
    if sys.platform == "win32":
        return through_wsl(args)

    swift = find_swift(args.swift)
    package = ROOT / ".build/domain-validation"
    package.mkdir(parents=True, exist_ok=True)
    print("Supplementary validation only: Linux cannot validate SwiftUI, SwiftData, EventKit, Security, or iOS runtime behavior.", flush=True)
    print(f"Swift: {swift}\nGenerated package and logs: {package}", flush=True)
    subprocess.run([str(swift), "--version"], check=True)

    parse_status = 0
    if not args.skip_parse:
        all_sources = sorted(path for directory in ("Mira", "MiraOverrides", "MiraTests", "MiraUITests") for path in (ROOT / directory).rglob("*.swift"))
        print(f"Parsing all {len(all_sources)} Swift files (syntax only; unavailable imports are not type-checked).", flush=True)
        parse_status = run_logged([str(swift.parent / "swiftc"), "-frontend", "-parse", "-swift-version", "5", *map(str, all_sources)], package / "parse.log")
        print(f"Syntax parse exit status: {parse_status}", flush=True)
    if args.parse_only:
        return parse_status

    excluded: dict[str, str] = {}
    source_paths = sorted(path for directory in ("Core", "Domain", "Services") for path in (ROOT / "Mira" / directory).glob("*.swift"))
    sources = selected(source_paths, excluded)
    tests = selected(sorted((ROOT / "MiraTests").glob("*.swift")), excluded)
    source_hashes = copy_exact(sources, package / "Sources/Mira")
    test_hashes = copy_exact(tests, package / "Tests/MiraTests")
    (package / "Package.swift").write_text('''// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MiraDomainValidation",
    products: [.library(name: "Mira", targets: ["Mira"])],
    targets: [
        .target(name: "Mira"),
        .testTarget(name: "MiraTests", dependencies: ["Mira"])
    ],
    swiftLanguageVersions: [.v5]
)
''', encoding="utf-8")
    (package / "manifest.json").write_text(json.dumps({
        "scope": "Supplementary portable source validation; not an iOS build or Simulator test.",
        "source_policy": "Exact byte copies; no source rewrites, platform shims, or substitute implementations.",
        "sources_sha256": source_hashes, "tests_sha256": test_hashes, "excluded": excluded,
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Selected {len(sources)} source files and {len(tests)} test/support files; excluded {len(excluded)} files (manifest.json records reasons).", flush=True)
    test_status = run_logged([str(swift), "test", "--package-path", str(package), "--jobs", str(args.jobs)], package / "test.log")
    print(f"Portable SwiftPM test exit status: {test_status}", flush=True)
    return test_status or parse_status


if __name__ == "__main__":
    raise SystemExit(main())
