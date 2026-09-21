import SwiftUI

struct JevSettingsView: View {
    let palette: MiraThemePalette
    @State private var enabled = false
    @State private var endpoint = ""
    @State private var token = ""
    @State private var status: String?
    private let settings = JevSettingsStore.shared

    var body: some View {
        Form {
            Section {
                Toggle("クラウドの入力補助を使う", isOn: $enabled)
                    .onChange(of: enabled) { _, value in
                        if !value { settings.setEnabled(false) }
                        status = nil
                    }
            } footer: {
                Text("オンにして設定を保存すると、会話に入力した文章と、選択中の案件があるかどうかを、指定したサーバー経由でTypeSafe AIに送ります。会話履歴やカレンダー全体は送りません。予定の登録・変更は自分で選べます。")
            }

            Section {
                TextField("https://example.com/v1/intent", text: $endpoint)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Miraサーバーの接続先")
                SecureField("Miraサーバー用の接続トークン", text: $token)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("設定を保存") { save() }
                    .disabled(JevConfiguration.endpoint(from: endpoint) == nil || !JevConfiguration.validToken(token))
                if let status {
                    Text(status)
                        .font(.footnote)
                        .accessibilityIdentifier("jevSettingsStatus")
                }
            } header: {
                Text("接続設定")
            } footer: {
                Text("自分で用意したMiraサーバーの設定を入力します。TypeSafeのAPIキーはここに入力しません。サーバーの管理者は送信した文章を受け取れるため、信頼できる接続先を使ってください。")
            }

            Section {
                Text("日本語の分類精度は検証中です。通信できない時や判定が不確かな時は、端末内の処理を使います。オフにしてもMiraの入力や予定管理は使えます。")
                Link("TypeSafe AIのデータ取扱い", destination: URL(string: "https://typesafe.ai/legal/privacy-policy")!)
                Text("入力を学習に使わないことと、保存しないことは異なります。保存条件はサーバーの利用契約によります。")
                    .font(.footnote)
            } header: {
                Text("利用する前に")
            }

            if !settings.endpointText.isEmpty {
                Section {
                    Button("接続設定を削除", role: .destructive) {
                        settings.removeConfiguration()
                        enabled = false
                        endpoint = ""
                        token = ""
                        status = "接続設定を削除しました。端末内の処理を使います。"
                    }
                }
            }
        }
        .tint(palette.accent)
        .navigationTitle("クラウドの入力補助")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            endpoint = settings.endpointText
            token = settings.token(for: endpoint) ?? ""
            enabled = settings.isEnabled
        }
    }

    private func save() {
        if settings.save(endpointText: endpoint, token: token, enabled: enabled) {
            endpoint = settings.endpointText
            status = enabled ? "入力補助を有効にしました。接続確認は次の入力時に行います。" : "設定を保存しました。入力補助はオフです。"
        } else {
            status = "設定を保存できませんでした。接続先とトークンを確認してください。"
        }
    }
}
