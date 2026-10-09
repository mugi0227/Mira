import Foundation

@MainActor
extension MiraStore {
    /// Applies what the server knows about this person: premium imports and,
    /// for accounts with their own color code, that profile.
    func applyAccount(_ account: MiraAccount?) {
        self.account = account
        if let account, account.colorProfile != .standard, colorProfile != account.colorProfile {
            setColorProfile(account.colorProfile)
        }
    }

    func signInToMira(identityToken: String) async -> Bool {
        do {
            applyAccount(try await MiraAccountService.shared.signIn(identityToken: identityToken))
            toast = "サインインしたにゃ"
            return true
        } catch {
            toast = error.localizedDescription
            return false
        }
    }

    func refreshMiraAccount() async {
        guard MiraAccountService.shared.isSignedIn, MiraAccountService.shared.serverURL != nil else { return }
        if let account = try? await MiraAccountService.shared.refreshAccount() {
            applyAccount(account)
        }
    }

    func signOutOfMira() {
        MiraAccountService.shared.signOut()
        account = nil
    }

    /// Premium reads through the server; otherwise the personal key, if any.
    var canReadCalendarImages: Bool {
        account?.premium == true || GeminiSettingsStore.shared.hasKey
    }

    func readCalendarImage(_ image: Data, sourceIndex: Int) async throws -> [ImportCandidate] {
        if account?.premium == true {
            return try await ServerCalendarExtractor().extract(image: image, sourceIndex: sourceIndex, today: now)
        }
        return try await GeminiCalendarExtractor().extract(image: image, sourceIndex: sourceIndex, today: now)
    }
}
