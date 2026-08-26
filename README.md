# Mira — 余白カレンダー

予定をたくさん入れるためではなく、**自分が送りたい生活を先に確保したうえで、人との予定も気持ちよく入れる**ためのiPhone向けSwiftUIデモです。

## できること

- 休息・読書・一人時間・個人プロジェクトなどの月間目標を設定
- 既存予定と基本拘束時間を避けて、余白を自動配置
- 最後の休息枠を無意識に潰さない「最終防衛」
- 誘いをすぐ確定せず置いておく「検討中」
- 複数候補日の仮押さえ、重複警告、共有文生成、日程確定
- 予定タイトル・時間帯・外出・前後バッファから負荷を推定
- ユーザーが明示的に訂正した負荷だけを記憶
- Apple Foundation Models対応環境ではオンデバイス分類を使用
- 非対応環境ではルールベースへ自動フォールバック
- Soft Minimal / Pixel Cat の着せ替え
- 3か月分の再現可能なデモデータ
- Yahoo!カレンダー等を想定したLegacy Calendar Importモック

## 技術構成

- SwiftUI
- SwiftData
- Observation
- Structured Concurrency
- UserNotifications
- Foundation Models（iOS 26以上・利用可能端末のみ）
- XcodeGen
- XCTest / XCUITest

デプロイメントターゲットはiOS 18です。Foundation Models部分だけ可用性を判定し、利用できない端末でも中心機能はすべて動作します。

## セットアップ

```bash
brew install xcodegen
./scripts/bootstrap.sh
open Mira.xcodeproj
```

コマンドライン：

```bash
make build
make test
```

Developer Programへの登録は、Simulatorでのビルド・動作確認には不要です。

## デモ

アプリ内のデモ時計は `2026-09-01 10:00 Asia/Tokyo` に固定されています。設定からサンプル状態へ戻せます。

推奨デモ導線：

1. オンボーディングで欲しい余白を選択
2. 余白を自動配置
3. 休息枠へ予定を追加し、別日へ再配置
4. 検討中の誘いを日程調整へ変換
5. 重複候補を確認して1件を確定
6. 予定負荷の理由を見て訂正
7. 未来月へ予定を入れ、暫定目標による警告を確認
8. Legacy Calendar Importモックを操作

詳しくは [`docs/demo-script.md`](docs/demo-script.md) を参照してください。

## 今回あえて接続していないもの

- EventKitによる実カレンダー読み書き
- CloudKit同期
- PDF・スクリーンショットの実OCR
- Yahoo!カレンダーAPI
- 外部LLM API
- Android版
- ToDo機能

これらはRepository / Service境界で後から差し替えられる設計です。

## UI方針

- Soft Minimalをベースに、Pixel Catを着せ替えとして重ねる
- 44pt以上のタップ領域
- 4/8ptのスペーシング体系
- SF Symbolsによる一貫した構造アイコン
- Dynamic Type / VoiceOver / Reduce Motion対応
- 色だけに依存しない状態表現
- 原因と結果を伝える短いモーション

デザイン判断は `ui-ux-pro-max-skill` のモバイルUI原則と、Insporaに掲載される余白・カード・マイクロインタラクションの事例を参考にし、特定作品を複製せず独自のデザインシステムへ落としています。

## ドキュメント

- [`docs/product-spec.md`](docs/product-spec.md)
- [`docs/architecture.md`](docs/architecture.md)
- [`docs/design-system/MASTER.md`](docs/design-system/MASTER.md)
- [`docs/implementation-status.md`](docs/implementation-status.md)
- [`docs/demo-script.md`](docs/demo-script.md)
