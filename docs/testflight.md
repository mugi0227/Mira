# TestFlight配信

`main` に `Mira/`・`project.yml` の変更が入るたびに、GitHub Actions（`.github/workflows/testflight.yml`）が
アーカイブ → 署名 → App Store Connectへのアップロードまで自動で行います。Macも証明書の手作業も不要です。

署名はApp Store Connect APIキーを使ったXcodeの自動署名（クラウド署名）で行い、
Bundle ID・証明書・プロビジョニングプロファイルはXcodeが必要に応じて自動作成します。
ビルド番号はワークフローの実行番号（`github.run_number`）で自動採番されます。

## 初回だけ必要な手作業

### 1. App Store Connect APIキーを作る

1. [App Store Connect](https://appstoreconnect.apple.com) → **ユーザとアクセス** → **統合** → **App Store Connect API**
2. 初回は「アクセスをリクエスト」→ 同意
3. **チームキー** の「+」→ 名前は `GitHub Actions` など、アクセスは **Admin**
   （Adminでないと署名証明書を自動作成できません）
4. 次の3つを控える
   - `.p8` ファイル（**ダウンロードは1回きり**）
   - キーID
   - Issuer ID（キー一覧の上に表示）

### 2. Team IDを確認

[Apple Developer › アカウント › メンバーシップの詳細](https://developer.apple.com/account) の「チームID」（英数字10桁）。

### 3. GitHubにSecretsを登録

リポジトリの **Settings → Secrets and variables → Actions → New repository secret** で4つ登録します。

| Name | 値 |
| --- | --- |
| `APPLE_TEAM_ID` | 手順2のチームID |
| `ASC_KEY_ID` | 手順1のキーID |
| `ASC_ISSUER_ID` | 手順1のIssuer ID |
| `ASC_KEY_P8` | `.p8` ファイルの中身をまるごと（`-----BEGIN PRIVATE KEY-----` 行から `-----END PRIVATE KEY-----` 行まで） |

### 4. 1回目のワークフローを実行（Bundle IDの自動登録）

GitHubの **Actions → TestFlight → Run workflow**。
このときXcodeが Bundle ID `jp.mugi.mira` を自動登録します。
App Store Connect側にまだアプリが無いので、最後のアップロード段階で
`No suitable application records were found` のように失敗するのは想定どおりです。

### 5. App Store Connectにアプリを作る

App Store Connect → **アプリ** → 「+」→ **新規App**

- プラットフォーム: iOS
- 名前: App Storeで一意である必要があります（例: `余白カレンダー Mira`）。ホーム画面の表示名は `余白` のままです
- 言語: 日本語
- バンドルID: `jp.mugi.mira`（手順4で登録されたものを選択）
- SKU: 任意（例: `mira`）

### 6. もう一度ワークフローを実行

**Actions → TestFlight → Run workflow**。成功すると、5〜15分ほどの処理後にTestFlightへ出てきます。

### 7. 自分をテスターに追加

App Store Connect → アプリ → **TestFlight** → 内部テストの「+」でグループを作り、自分を追加。
iPhoneに [TestFlight](https://apps.apple.com/jp/app/testflight/id899247664) を入れ、届いた招待からインストールします。
内部グループは以降のビルドが自動配信されます。

## 2回目以降

`main` にアプリのコードが入れば自動でアップロードされ、iPhoneのTestFlightに新ビルドが届きます。
手動で出したいときは **Actions → TestFlight → Run workflow**。

暗号化の輸出コンプライアンスは `ITSAppUsesNonExemptEncryption = NO` を設定済みなので、毎回の質問は出ません。

## アプリアイコン

`Mira/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` は `scripts/generate_app_icon.py` で生成した仮アイコンです。
1024×1024・透過なしのPNGで差し替えればそのまま使えます。

## うまくいかないとき

| 症状 | 対処 |
| --- | --- |
| `GitHub secret ... is not set` | 手順3のSecrets名を確認 |
| 証明書・プロファイル作成で失敗 | APIキーのアクセスが **Admin** か確認 |
| `No suitable application records were found` | 手順5のアプリ作成がまだ、またはバンドルIDが違う |
| `jp.mugi.mira` が他チームで使用済み | `project.yml` の `PRODUCT_BUNDLE_IDENTIFIER` を変更 |
| ビルド番号の重複 | ワークフローを再実行（実行番号が進みます） |
