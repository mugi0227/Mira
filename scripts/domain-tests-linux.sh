#!/usr/bin/env bash
# Runs the pure-Foundation domain layer and its unit tests with SwiftPM (works on Linux).
# Usage: scripts/domain-tests-linux.sh [work-dir]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${1:-${TMPDIR:-/tmp}/mira-domain-tests}"
rm -rf "$WORK" && mkdir -p "$WORK/Sources/Mira" "$WORK/Tests/MiraTests"
for f in "$ROOT"/Mira/Core/*.swift "$ROOT"/Mira/Domain/*.swift; do ln -s "$f" "$WORK/Sources/Mira/"; done
for f in "$ROOT"/MiraTests/*.swift; do
  grep -q "import SwiftData\|import SwiftUI\|MiraStore" "$f" || ln -s "$f" "$WORK/Tests/MiraTests/"
done
cat > "$WORK/Package.swift" <<'PKG'
// swift-tools-version:5.10
import PackageDescription
let package = Package(
    name: "Mira",
    targets: [
        .target(name: "Mira", path: "Sources/Mira"),
        .testTarget(name: "MiraTests", dependencies: ["Mira"], path: "Tests/MiraTests")
    ]
)
PKG
cd "$WORK" && swift test 2>&1
