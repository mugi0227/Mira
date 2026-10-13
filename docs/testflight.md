# TestFlight配信

`main` または配信用の `codex/testflight-release` にアプリ・ウィジェット・共有コード・配信設定の変更が入るたびに、GitHub Actions（`.github/workflows/testflight.yml`）が
アーカイブ → 署名 → App Store Connectへのアップロードまで自動で行います。Macも証明書の手作業も不要です。

署名はApp Store Connect APIキーを使ったXcodeの自動署名（クラウド署名）で行い、
Bundle ID・証明書・プロビジョニングプロファイルはXcodeが必要に応じて自動作成します。
ビルド番号はワークフローの実行番号（`github.run_number`）で自動採番されます。

## 初回だけ必要な手作業

### 1. GitHubにSecretsを登録

thirtyと**同じ値**をそのまま使えます（APIキーはチーム共通なので、新しく作る必要はありません）。
Team ID（`572NVCGLGQ`）はワークフローに直書き済みです。

リポジトリの **Settings → Secrets and variables → Actions → New repository secret** で3つ登録します。

| Name | 値 |
| --- | --- |
| `ASC_KEY_ID` | App Store Connect APIキーのキーID |
| `ASC_ISSUER_ID` | Issuer ID（キー一覧の上に表示） |
| `ASC_KEY_P8` | `AuthKey_XXXX.p8` の中身をまるごと（`-----BEGIN PRIVATE KEY-----` 行から `-----END PRIVATE KEY-----` 行まで） |

GitHub CLIが使えるPCなら、次のコマンドで一発です。

```bash
REPO=mugi0227/Mira
gh secret set ASC_KEY_ID    -R "$REPO" -b "<キーID>"
gh secret set ASC_ISSUER_ID -R "$REPO" -b "<Issuer ID>"
gh secret set ASC_KEY_P8    -R "$REPO" < ~/path/to/AuthKey_XXXX.p8
```

APIキーを新しく作る場合は、App Store Connect → **ユーザとアクセス** → **統合** → **App Store Connect API** →
チームキーの「+」で、アクセスを **Admin** にしてください（Adminでないと署名証明書を自動作成できません）。

### 2. 1回目のワークフローを実行（Bundle IDの自動登録）

GitHubの **Actions → TestFlight → Run workflow**。
このときXcodeが Bundle ID `jp.mugi.mira` を自動登録します。
App Store Connect側にまだアプリが無いので、最後のアップロード段階で
`No suitable application records were found` のように失敗するのは想定どおりです。

### 3. App Store Connectにアプリを作る

App Store Connect → **アプリ** → 「+」→ **新規App**

- プラットフォーム: iOS
- 名前: App Storeで一意である必要があります（例: `余白カレンダー Mira`）。ホーム画面の表示名は `余白` のままです
- 言語: 日本語
- バンドルID: `jp.mugi.mira`（手順2で登録されたものを選択）
- SKU: 任意（例: `mira`）

### 4. もう一度ワークフローを実行

**Actions → TestFlight → Run workflow**。成功すると、5〜15分ほどの処理後にTestFlightへ出てきます。

### 5. 自分をテスターに追加

App Store Connect → アプリ → **TestFlight** → 内部テストの「+」でグループを作り、自分を追加。
iPhoneに [TestFlight](https://apps.apple.com/jp/app/testflight/id899247664) を入れ、届いた招待からインストールします。
内部グループは以降のビルドが自動配信されます。

## 2回目以降

`main` または `codex/testflight-release` にアプリのコードが入れば自動でアップロードされます。処理完了と内部テストグループへの配信をTestFlightで確認してください。
手動で出したいときは **Actions → TestFlight → Run workflow**。

暗号化の輸出コンプライアンスは `ITSAppUsesNonExemptEncryption = NO` を設定済みなので、毎回の質問は出ません。

## アプリアイコン

`Mira/Assets.xcassets/AppIcon.appiconset/app_icon.png` の既存アイコンを使います。1024×1024・透過なしのPNGです。

## ウィジェットとサインイン

アプリ `jp.mugi.mira` とウィジェット `jp.mugi.mira.widget` は、App Group `group.jp.mugi.mira` を共有します。
Apple Developerで両方のApp IDにこのグループを関連付けます。アプリにはSign in with Appleも有効にします。
配信ブランチは `claude/uiux-review` のUI改善と、別ブランチにあったTestFlight設定を統合しています。

## うまくいかないとき

| 症状 | 対処 |
| --- | --- |
| `GitHub secret ... is not set` | 手順1のSecrets名を確認 |
| 証明書・プロファイル作成で失敗 | APIキーのアクセスが **Admin** か確認 |
| `No suitable application records were found` | 手順3のアプリ作成がまだ、またはバンドルIDが違う |
| `jp.mugi.mira` が他チームで使用済み | `project.yml` の `PRODUCT_BUNDLE_IDENTIFIER` を変更 |
| ビルド番号の重複 | ワークフローを再実行（実行番号が進みます） |
