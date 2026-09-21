# Mira — 余白カレンダー

**自分が送りたい生活の余白を確保しながら、人との予定を決める**ためのiPhoneアプリです。入力や判断を途中で止めても、保存した続きから再開できます。

## できること

- 休息・読書・一人時間・個人プロジェクトなどの月間目標を設定
- 既存予定と基本拘束時間を避けて、余白を自動配置
- 予定入力中に余白・目標・重複・負荷を確認する「秘書」体験
- 最後の休息枠を無意識に潰さない「最終防衛」
- 誘いをすぐ確定せず置いておく「検討中」
- 複数候補日の仮押さえ、重複警告、共有文生成、日程確定
- 予定タイトル・時間帯・外出・前後バッファから負荷を推定
- ユーザーが明示的に訂正した負荷だけを記憶
- Apple Foundation Models対応環境ではオンデバイス分類を使用
- 非対応環境ではルールベースへ自動フォールバック
- Soft Minimal / Pixel Cat の着せ替え
- 入力・予定フォーム・調整候補・返信文・初期設定の下書き保存と再開
- 直前の予定追加・変更・余白配置を取り消す操作
- 未送信と返事待ちの区別、返信期限の通知と対象案件への移動
- EventKitによる選択カレンダーの読込み、明示操作による書出し、標準編集画面との連携
- オプションのJev意図分類（初期状態はオフ、Miraバックエンド経由）
- 3か月分の再現可能なデモデータ
- Yahoo!カレンダー等を想定したLegacy Calendar Importモック

## プロダクト原則

Miraは予定を禁止する管理者ではなく、**影響と別候補を示す秘書**です。

> それを入れるとこうなる。こっちなら楽。でも決めるのはあなた。

基本時間・既存予定・余白・調整中候補と重なっても、影響を説明したうえで本人が承認すれば登録できます。最後の休息枠を使う場合も確認を挟み、最終判断は利用者に委ねます。確認後に予定が変わった場合は影響を再計算し、もう一度確認します。

要求の正本は [`docs/requirements-specification.md`](docs/requirements-specification.md)、Grill-Meでの意思決定経緯は [`docs/grill-me-decisions.md`](docs/grill-me-decisions.md) を参照してください。

## 技術構成

- SwiftUI
- SwiftData
- Observation
- Structured Concurrency
- UserNotifications
- EventKit / EventKitUI
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

新規起動は現在日時を使い、サンプル予定は追加しません。設定のデモリセットを使うと、`2026-09-01 10:00 Asia/Tokyo` の固定時計とサンプル予定で試せます。既存のデモ利用者は、設定からローカルのサンプルを片付けて日常用へ移れます。

推奨デモ導線：

1. オンボーディングで欲しい余白を選択
2. 基本的に予定を入れない時間を設定
3. 余白を自動配置
4. 新しい予定を入力し、Miraの影響チェック・別候補を確認
5. 必要なら余白を別日へ移す、または明示的に例外追加
6. 検討中の誘いを日程調整へ変換
7. 重複候補を確認して1件を確定
8. 予定負荷の理由を見て訂正
9. 未来月へ予定を入れ、暫定目標による警告を確認
10. Legacy Calendar Importモックを操作

詳しくは [`docs/demo-script.md`](docs/demo-script.md) を参照してください。

## 検証と外部連携

`python scripts/test-domain.py` はSwiftが動く環境（WindowsではWSL）で、対応する実ソースをそのまま使ったロジックテストと全Swiftファイルの構文検査を行います。SwiftData・SwiftUI・EventKitを含むビルドとテストは、macOS/Xcodeの `make test` または `codemagic.yaml` で確認してください。

Jevは `backend/README.md` のバックエンドを配置し、設定画面で接続先とクライアントトークンを指定したときだけ利用します。プロバイダーのAPIキーはサーバー側に保管します。未設定・通信失敗・不確かな分類では端末の解釈へ戻ります。実Jev APIでの日本語精度評価は未完了です。

実装と検証の範囲は [`docs/implementation-status.md`](docs/implementation-status.md) を参照してください。

## 未実装のもの

- CloudKit同期
- PDF・スクリーンショットの実OCR
- Yahoo!カレンダーAPI
- Android版
- ToDo機能

これらはRepository / Service境界で後から差し替えられる設計です。

## UI方針

- Soft Minimalをベースに、Pixel Catを着せ替えとして重ねる
- 月間カレンダーは画面幅いっぱいの7列罫線グリッド
- 44pt以上のタップ領域
- 4/8ptのスペーシング体系
- SF Symbolsによる一貫した構造アイコン
- Dynamic Type / VoiceOver / Reduce Motion対応
- 色だけに依存しない状態表現
- 原因と結果を伝える短いモーション

デザイン判断は `ui-ux-pro-max-skill` のモバイルUI原則と、Insporaに掲載される余白・カード・マイクロインタラクションの事例を参考にし、特定作品を複製せず独自のデザインシステムへ落としています。

## ドキュメント

### 要求・意思決定

- **[`docs/requirements-specification.md`](docs/requirements-specification.md)** — 要求仕様の正本
- **[`docs/grill-me-decisions.md`](docs/grill-me-decisions.md)** — Grill-Meの決定ログと理由
- [`docs/product-spec.md`](docs/product-spec.md) — 短いプロダクト概要

### 設計・実装

- [`docs/architecture.md`](docs/architecture.md)
- [`docs/design-system/MASTER.md`](docs/design-system/MASTER.md)
- [`docs/implementation-status.md`](docs/implementation-status.md)
- [`docs/demo-script.md`](docs/demo-script.md)
