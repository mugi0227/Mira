#!/usr/bin/env python3
"""Advisory screenshot design review using Gemini (Python standard library only)."""
import argparse
import base64
import json
import os
from pathlib import Path
import time
import urllib.error
import urllib.parse
import urllib.request

SEVERITY = {"high": 0, "medium": 1, "low": 2}
PROMPT = """あなたは余白ともちもち感を大切にするiPhoneアプリのデザイナーです。
スクリーンショットを視覚的に審査し、日本語で具体的な改善案を返してください。
画面端・カードの隅（特にカレンダー）の内側余白、要素間の窮屈な隙間、文字の省略（…）、
重なり、ステータスバー・ホームインジケータ・フローティングボタンへの衝突、
タップ領域の密集、余白リズムの不均一を確認してください。問題を捏造しないでください。
scoreは余白を含むレイアウト品質（1=悪い、10=良い）。severityはhigh/medium/low。
boxは問題箇所の[x0,y0,x1,y1]、画像左上原点で0〜1の正規化座標（任意）。
以下の機械検出は誤検知もあるヒントです。必ず画像で確かめてください：
"""
SCHEMA = {"type": "OBJECT", "properties": {
    "score": {"type": "INTEGER", "minimum": 1, "maximum": 10},
    "summary": {"type": "STRING"},
    "findings": {"type": "ARRAY", "items": {"type": "OBJECT", "properties": {
        **{key: {"type": "STRING"} for key in ("area", "issue", "suggestion")},
        "severity": {"type": "STRING", "enum": list(SEVERITY)},
        "box": {"type": "ARRAY", "items": {"type": "NUMBER", "minimum": 0, "maximum": 1},
                "minItems": 4, "maxItems": 4}},
        "required": ["area", "issue", "severity", "suggestion"]}}},
    "required": ["score", "summary", "findings"]}


def validate(result):
    if not isinstance(result, dict) or not isinstance(result.get("score"), (int, float)) or not 1 <= result["score"] <= 10:
        raise ValueError("Invalid review score")
    if not isinstance(result.get("summary"), str) or not isinstance(result.get("findings"), list):
        raise ValueError("Invalid review summary/findings")
    for finding in result["findings"]:
        if finding.get("severity") not in SEVERITY or any(not isinstance(finding.get(k), str) for k in ("area", "issue", "suggestion")):
            raise ValueError("Invalid finding")
        box = finding.get("box")
        if box is not None and (not isinstance(box, list) or len(box) != 4 or any(not isinstance(v, (int, float)) or not 0 <= v <= 1 for v in box)):
            raise ValueError("Invalid finding box")
    return result


def review(path, key, model, hints):
    body = {"contents": [{"role": "user", "parts": [
        {"text": PROMPT + json.dumps(hints, ensure_ascii=False)},
        {"inlineData": {"mimeType": "image/png", "data": base64.b64encode(path.read_bytes()).decode()}}]}],
        "generationConfig": {"temperature": 0, "responseMimeType": "application/json", "responseSchema": SCHEMA}}
    request = urllib.request.Request(
        "https://generativelanguage.googleapis.com/v1beta/models/" + urllib.parse.quote(model, safe="") + ":generateContent",
        data=json.dumps(body).encode(), headers={"Content-Type": "application/json", "x-goog-api-key": key})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=90) as response:
                data = json.load(response)
            parts = data["candidates"][0]["content"]["parts"]
            return validate(json.loads("".join(p.get("text", "") for p in parts)))
        except urllib.error.HTTPError as error:
            if attempt == 2 or (error.code != 429 and not 500 <= error.code <= 599):
                raise RuntimeError(f"Gemini HTTP {error.code}") from None
            time.sleep(attempt + 1)


def build_report(screens, note=""):
    lines = ["# Mira ビジュアル余白レビュー", "", "参考情報（advisory）。機械検出は誤検知を含みます。", ""]
    if note:
        lines += [note, ""]
    for name, result in screens.items():
        lines += [f"## {name}", ""]
        if "error" in result:
            lines += [f"レビューできませんでした: {result['error']}", ""]
            continue
        lines += [f"スコア: {result['score']}/10", "", result["summary"], ""]
        findings = sorted(result["findings"], key=lambda f: SEVERITY[f["severity"]])
        if not findings:
            lines += ["指摘なし。", ""]
        for finding in findings:
            lines += [f"- **{finding['severity']} — {finding['area']}**: {finding['issue']}",
                      f"  - 改善案: {finding['suggestion']}"]
            if "box" in finding:
                lines.append(f"  - 範囲: {finding['box']}")
        lines.append("")
    return "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", nargs="?", type=Path, default=Path("/tmp/mira-screenshots"))
    parser.add_argument("--out", type=Path, default=Path("/tmp/mira-visual-review/report.md"))
    parser.add_argument("--json", type=Path, default=Path("/tmp/mira-visual-review/report.json"))
    parser.add_argument("--audit-dir", type=Path, default=Path("/tmp/mira-layout-audit"))
    parser.add_argument("--fail-on", choices=["high", "medium", "none"], default="none")
    parser.add_argument("--mock", type=Path, help="One review object reused for every PNG")
    args = parser.parse_args(argv)
    key = os.environ.get("GEMINI_API_KEY")
    screens, note = {}, ""
    if not key and not args.mock:
        note = "GEMINI_API_KEY が未設定のため、ビジュアルレビューをスキップしました。"
    else:
        for path in sorted(args.directory.glob("*.png")):
            try:
                hints_path = args.audit_dir / (path.stem + ".json")
                hints = json.loads(hints_path.read_text()) if hints_path.exists() else []
                screens[path.stem] = validate(json.loads(args.mock.read_text())) if args.mock else review(
                    path, key, os.environ.get("GEMINI_MODEL", "gemini-3.8-flash"), hints)
            except Exception as error:
                screens[path.stem] = {"error": f"{type(error).__name__}: {error}"}
        if not screens:
            note = "PNG が見つかりませんでした。"
    for path, content in [(args.out, build_report(screens, note)),
                          (args.json, json.dumps({"note": note, "screens": screens}, ensure_ascii=False, indent=2))]:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
    print(note or f"Reviewed {len(screens)} screens: {args.out}")
    return int(args.fail_on != "none" and any(
        SEVERITY[f["severity"]] <= SEVERITY[args.fail_on]
        for result in screens.values() for f in result.get("findings", [])))


if __name__ == "__main__":
    raise SystemExit(main())
