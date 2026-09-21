# 猫スキン：空色のデザイン

`index.html` は配色と画面の雰囲気を確認するための参考プレビューです。
iOS アプリの実行画面ではなく、予定や数値もサンプルです。
ホーム・調整・マイ余白・設定を下部タブで切り替えられます。
それ以外の操作は外観のみの表示です。

HTML を直接開くか、リポジトリのルートで `python -m http.server 8765 --bind 127.0.0.1` を実行し、`http://127.0.0.1:8765/docs/previews/cat-sky/` を開いてください。

SwiftUI 側は `MiraTheme.swift`、`MiraSurfaces.swift`、共通カードとボタン、各画面に実装しています。
猫の画像は既存の表情別アセットを使用しています。
保存済みスキンの識別子 `pixelCat` は継続します。

## 今回の確認

- 変更した Swift 30 ファイルの構文解析と UTF-8 検査：問題なし。
- `git diff --check`：通過。
- 参考プレビュー：375px / 390px で4画面を目視確認、844px の横向き相当で横のはみ出しなし。
- 参考プレビュー：猫画像の読み込みとタブ切り替えを確認。
- 明暗両方の主要な文字・ボタン配色を数値で確認。
- `GrillMeFlowUITests.testCatSkinKeepsNavigationAndSheetsUsable` に、4タブとスキン選択・予定追加・案件指定シートの操作確認を追加。

Windows 環境に Xcode がないため、SwiftUI のビルド、XCTest の実行、実機の表示確認は未実施です。
参考プレビューの確認は、実機の Safe Area・キーボード・Dynamic Type・ダークモードの表示検証を代替しません。
macOS では既存の `make build` / `make test`、または Codemagic の iOS 検証ワークフローで確認できます。
