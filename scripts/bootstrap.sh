#!/usr/bin/env bash
set -euo pipefail

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen が必要です。Homebrew がある場合は 'brew install xcodegen' を実行してください。" >&2
  exit 1
fi

xcodegen generate
printf '\n✅ Mira.xcodeproj を生成しました。Xcodeで開いてください。\n'
