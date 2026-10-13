# TestFlight配信

`main` または配信用の `codex/testflight-release` にアプリ・ウィジェット・共有コード・配信設定の変更が入るたびに、GitHub Actions（`.github/workflows/testflight.yml`）が
アーカイブ → 署名 → App Store Connectへのアップロードまで自動で行います。Macも証明書の手作業も不要です。

署名は、GitHub Secretsに保存した配布用の署名と、登録済みのApp Store用プロファイルを再利用します。
`ci/install_signing.py` が一時キーチェーンに署名を読み込み、APIキーでプロファイルを取得します。
CIごとに開発用証明書を作成すると枚数上限に達するため、アーカイブと書き出しを配布用署名へ統一しています。
署名の設定はRunnerのチェックアウトだけに適用し、終了時に秘密鍵ファイルと一時キーチェーンを削除します。
ビルド番号はワークフローの実行番号（`github.run_number`）で自動採番されます。
ウィジェットのバージョンとビルド番号も本体と揃え、アーカイブ後に一致を検査します。

2026/10/13に **0.2.0 (2)** の配信を確認しました。アプリ・ウィジェットの署名と番号一致の検査、Appleの処理が成功し、`Mira Internal` でテスト中です。
Appleのアップロード検査は警告・エラーともに0件でした。
[配信ビルド](https://github.com/mugi0227/Mira/actions/runs/38371133321) · [TestFlight](https://appstoreconnect.apple.com/apps/6822208886/testflight)

## 初回セットアップ（Miraは設定済み）

### 1. GitHubにSecretsを登録

thirtyと**同じ値**をそのまま使えます（APIキーはチーム共通なので、新しく作る必要はありません）。
Team ID（`572NVCGLGQ`）はワークフローに直書き済みです。

リポジトリの **Settings → Secrets and variables → Actions → New repository secret** に以下を登録します。APIキーの3つはthirtyと共通で、配布用署名の2つも登録済みです。

| Name | 値 |
| --- | --- |
| `ASC_KEY_ID` | App Store Connect APIキーのキーID |
| `ASC_ISSUER_ID` | Issuer ID（キー一覧の上に表示） |
| `ASC_KEY_P8` | `AuthKey_XXXX.p8` の中身をまるごと（`-----BEGIN PRIVATE KEY-----` 行から `-----END PRIVATE KEY-----` 行まで） |
| `MIRA_SIGNING_P12` | 配布用の証明書と秘密鍵を含む、暗号化したPKCS#12のBase64 |
| `MIRA_SIGNING_PASSWORD` | PKCS#12のパスワード |

GitHub CLIが使えるPCなら、次のコマンドで一発です。

```bash
REPO=mugi0227/Mira
gh secret set ASC_KEY_ID    -R "$REPO" -b "<キーID>"
gh secret set ASC_ISSUER_ID -R "$REPO" -b "<Issuer ID>"
gh secret set ASC_KEY_P8    -R "$REPO" < ~/path/to/AuthKey_XXXX.p8
```

APIキーを新しく作る場合は、App Store Connect → **ユーザとアクセス** → **統合** → **App Store Connect API** →
チームキーの「+」で、アクセスを **Admin** にしてください（初期設定で証明書・プロファイルを発行・取得するために使います）。

配布用の証明書・プロファイルの公開情報は `ci/signing.json` にあります。有効期限は2027/10/13です。
更新時は新しい配布用署名をSecretsに登録し、プロファイルIDと署名の指紋を更新します。
PKCS#12とパスワードはGitへ入れません。

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
| 配布用署名を取得できない | PKCS#12のSecretsと `ci/signing.json` の指紋・有効期限を確認 |
| プロファイル取得で失敗 | APIキーの権限と、登録済みのApp Storeプロファイルの状態を確認 |
| `No suitable application records were found` | 手順3のアプリ作成がまだ、またはバンドルIDが違う |
| `jp.mugi.mira` が他チームで使用済み | `project.yml` の `PRODUCT_BUNDLE_IDENTIFIER` を変更 |
| ビルド番号の重複 | 新しいworkflow runを起動する。既存runの再実行は同じ番号になるため、アップロード済みのrunは使わない |
