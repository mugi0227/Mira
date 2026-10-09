import AuthenticationServices
import SwiftUI
import UIKit

/// Sign in with Apple to the Mira server. Premium accounts can read old
/// calendars from photos without any key on the device.
struct AccountSettingsView: View {
    @Environment(MiraStore.self) private var store
    let palette: MiraThemePalette

    @State private var serverText = MiraAccountService.shared.serverText
    @State private var isWorking = false

    var body: some View {
        Form {
            if let account = store.account {
                Section("サインイン中") {
                    HStack {
                        Label(account.premium ? "プレミアム" : "スタンダード", systemImage: account.premium ? "crown.fill" : "person.fill")
                            .foregroundStyle(account.premium ? palette.warning : palette.primaryText)
                        Spacer()
                        if account.colorProfile != .standard {
                            Text("専用の色ルール")
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                        }
                    }
                    Button {
                        UIPasteboard.general.string = account.userId
                        store.toast = "ユーザーIDをコピーしたにゃ"
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ユーザーID（タップでコピー）")
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                            Text(account.userId)
                                .font(.caption.monospaced())
                                .foregroundStyle(palette.primaryText)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    Button("サインアウト", role: .destructive) { store.signOutOfMira() }
                }
                .listRowBackground(palette.surface)
            } else {
                Section {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = []
                    } onCompletion: { result in
                        Task { await complete(result) }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 48)
                    .disabled(MiraAccountService.shared.serverURL == nil || isWorking)
                } header: {
                    Text("アカウント")
                } footer: {
                    Text("サインインすると、プレミアムのアカウントでは写真からの「カレンダーの引っ越し」がそのまま使えます。メールアドレスなどは受け取りません。")
                }
                .listRowBackground(palette.surface)
            }

            Section {
                TextField("https://…", text: $serverText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .onSubmit { MiraAccountService.shared.serverText = serverText }
                Button("保存") { MiraAccountService.shared.serverText = serverText }
                    .disabled(serverText == MiraAccountService.shared.serverText)
            } header: {
                Text("サーバー")
            } footer: {
                Text("Cloud RunにデプロイしたMiraサーバーのURL。配布版ではアプリに埋め込みます。")
            }
            .listRowBackground(palette.surface)
        }
        .scrollContentBackground(.hidden)
        .miraScreenBackground(palette)
        .navigationTitle("アカウント")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if isWorking { ProgressView() } }
        .task { await store.refreshMiraAccount() }
    }

    private func complete(_ result: Result<ASAuthorization, Error>) async {
        MiraAccountService.shared.serverText = serverText
        guard case .success(let authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let data = credential.identityToken,
              let token = String(data: data, encoding: .utf8) else {
            if case .failure(let error) = result, (error as? ASAuthorizationError)?.code != .canceled {
                store.toast = "サインインできませんでした"
            }
            return
        }
        isWorking = true
        _ = await store.signInToMira(identityToken: token)
        isWorking = false
    }
}
