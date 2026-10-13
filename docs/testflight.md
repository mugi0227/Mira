# TestFlight配信

`main` または配信用の `codex/testflight-release` にアプリ・ウィジェット・共有コード・配信設定の変更が入るたびに、GitHub Actions（`.github/workflows/testflight.yml`）が
アーカイブ → 署名 → App Store Connectへのアップロードまで自動で行います。Macも証明書の手作業も不要です。

署名はApp Store Connect APIキーを使ったXcodeの自動署名（クラウド署名）で行い、
Bundle ID・証明書・プロビジョニングプロファイルはXcodeが必要に応じて自動作成します。
ビルド番号はワークフローの実行番号（`github.run_number`）で自動採番されます。
ウィジェットのバージョンとビルド番号も本体と揃え、アーカイブ後に一致を検査します。

2026/10/13に **0.2.0 (2)** の配信を確認しました。アプリ・ウィジェットの署名と番号一致の検査、Appleの処理が成功し、`Mira Internal` でテスト中です。
Appleのアップロード検査は警告・エラーともに0件でした。
[配信ビルド](https://github.com/mugi0227/Mira/actions/runs/38371133321) · [TestFlight](https://appstoreconnect.apple.com/apps/6822208886/testflight)

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

### 2. Apple Developerの識別子を登録

Apple Developerの **Certificates, Identifiers & Profiles → Identifiers** で、アプリ `jp.mugi.mira` とウィジェット `jp.mugi.mira.widget` を登録します。
App Group `group.jp.mugi.mira` を登録し、両方のApp IDのApp Groups設定で割り当てます。
アプリにはSign in with AppleをプライマリApp IDとして有効にします。Miraではすべて設定済みです。

### 3. App Store Connectにアプリを作る

App Store Connect → **アプリ** → 「+」→ **新規App**

- プラットフォーム: iOS
- 名前: App Storeで一意である必要があります（例: `余白カレンダー Mira`）。ホーム画面の表示名は `余白` のままです
- 言語: 日本語
- バンドルID: `jp.mugi.mira`（手順2で登録されたものを選択）
- SKU: 任意（例: `mira`）

### 4. ワークフローを実行

配信ブランチにアプリまたは配信設定の変更をPushします。アップロード後、TestFlightでAppleの処理完了を確認します。
ワークフローが既定の `main` に反映済みなら **Actions → TestFlight → Run workflow** でも起動できます。

### 5. 自分をテスターに追加

App Store Connect → アプリ → **TestFlight** → 内部テストの「+」でグループを作り、自分を追加。
iPhoneに [TestFlight](https://apps.apple.com/jp/app/testflight/id899247664) を入れ、届いた招待からインストールします。
内部グループは以降のビルドが自動配信されます。

## 2回目以降

`main` または `codex/testflight-release` にアプリのコードが入れば自動でアップロードされます。処理完了と内部テストグループへの配信をTestFlightで確認してください。
現在は配信ブランチへのPushで起動します。`workflow_dispatch` による手動起動はワークフローを既定の `main` へ反映した後に利用できます。

暗号化の輸出コンプライアンスは `ITSAppUsesNonExemptEncryption = NO` を設定済みなので、毎回の質問は出ません。

## アプリアイコン

`Mira/Assets.xcassets/AppIcon.appiconset/app_icon.png` の既存アイコンを使います。1024×1024・透過なしのPNGです。

## ウィジェットとサインイン

アプリ `jp.mugi.mira` とウィジェット `jp.mugi.mira.widget` は、App Group `group.jp.mugi.mira` を共有します。
Apple Developerで両方のApp IDにこのグループを関連付けます。アプリにはSign in with Appleも有効にします。
配信ブランチは `claude/uiux-review` のUI改善と、別ブランチにあったTestFlight設定を統合しています。

## 設定済みの配信先

- App Store Connect: Mira - 余白カレンダー（Apple ID `6822208886`、SKU `mira`、日本語）
- 内部テストグループ: `Mira Internal`（自動配信、本人のアカウントを追加済み）
- App Group: `group.jp.mugi.mira` をアプリとウィジェットの両方へ登録済み
- GitHub Actions: https://github.com/mugi0227/Mira/actions/workflows/testflight.yml

## うまくいかないとき

| 症状 | 対処 |
| --- | --- |
| `GitHub secret ... is not set` | 手順1のSecrets名を確認 |
| 証明書・プロファイル作成で失敗 | APIキーのアクセスが **Admin** か確認 |
| `No suitable application records were found` | 手順3のアプリ作成がまだ、またはバンドルIDが違う |
| `jp.mugi.mira` が他チームで使用済み | `project.yml` の `PRODUCT_BUNDLE_IDENTIFIER` を変更 |
| ビルド番号の重複 | 新しいworkflow runを起動する。既存runの再実行は同じ番号になるため、アップロード済みのrunは使わない |
