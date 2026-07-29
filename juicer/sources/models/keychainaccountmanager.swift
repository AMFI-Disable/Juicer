import Foundation
import Security
import Combine

struct DeveloperAccount: Identifiable, Hashable {
    var id: String { "\(provider)-\(username)" }
    let provider: String // "GitHub", "GitLab", "DockerHub", "OpenAI", "Anthropic", "Gemini"
    let username: String
    let tokenType: String // "OAuth", "PAT", "API Key"
    let avatarUrl: String?
    let lastUsedDate: String
}

class KeychainAccountManager: ObservableObject {
    @Published var accounts: [DeveloperAccount] = []
    @Published var activeAccount: DeveloperAccount?
    @Published var isLoading = false
    @Published var statusMessage = ""

    private let serviceName = "com.even.juicer.keychain"

    init() {
        self.loadAccountsFromKeychain()
    }

    func loadAccountsFromKeychain() {
        self.isLoading = true
        Task.detached(priority: .userInitiated) {
            let savedAccounts = self.fetchSavedAccountList()
            await MainActor.run {
                self.accounts = savedAccounts
                self.activeAccount = savedAccounts.first
                self.isLoading = false
                self.statusMessage = savedAccounts.isEmpty ? "No developer accounts connected." : "Loaded \(savedAccounts.count) connected account(s)."
            }
        }
    }

    func saveToken(provider: String, username: String, token: String, tokenType: String = "PAT", avatarUrl: String? = nil) {
        let accountKey = "\(provider.lowercased())_\(username)"
        guard let data = token.data(using: .utf8) else { return }

        // Delete existing item if present
        let queryDelete: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountKey
        ]
        SecItemDelete(queryDelete as CFDictionary)

        // Add new Keychain item
        let queryAdd: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(queryAdd as CFDictionary, nil)
        if status == errSecSuccess {
            let df = DateFormatter()
            df.dateStyle = .short
            let newAcc = DeveloperAccount(provider: provider, username: username, tokenType: tokenType, avatarUrl: avatarUrl, lastUsedDate: df.string(from: Date()))

            // Persist metadata in UserDefaults
            var list = fetchSavedAccountMetadata()
            list.removeAll { $0["id"] == newAcc.id }
            list.append([
                "id": newAcc.id,
                "provider": provider,
                "username": username,
                "tokenType": tokenType,
                "avatarUrl": avatarUrl ?? "",
                "lastUsedDate": newAcc.lastUsedDate
            ])
            UserDefaults.standard.set(list, forKey: "juicer.accounts.metadata")

            self.loadAccountsFromKeychain()
        }
    }

    func removeAccount(_ account: DeveloperAccount) {
        let accountKey = "\(account.provider.lowercased())_\(account.username)"
        let queryDelete: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountKey
        ]
        SecItemDelete(queryDelete as CFDictionary)

        var list = fetchSavedAccountMetadata()
        list.removeAll { $0["id"] == account.id }
        UserDefaults.standard.set(list, forKey: "juicer.accounts.metadata")

        self.loadAccountsFromKeychain()
    }

    func getToken(for account: DeveloperAccount) -> String? {
        let accountKey = "\(account.provider.lowercased())_\(account.username)"
        let queryRead: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(queryRead as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data, let token = String(data: data, encoding: .utf8) {
            return token
        }
        return nil
    }

    // MARK: - Helpers
    private func fetchSavedAccountList() -> [DeveloperAccount] {
        let meta = fetchSavedAccountMetadata()
        return meta.compactMap { dict in
            guard let provider = dict["provider"], let username = dict["username"], let tokenType = dict["tokenType"] else { return nil }
            let avatar = dict["avatarUrl"]?.isEmpty == false ? dict["avatarUrl"] : nil
            let date = dict["lastUsedDate"] ?? "Recently"
            return DeveloperAccount(provider: provider, username: username, tokenType: tokenType, avatarUrl: avatar, lastUsedDate: date)
        }
    }

    private func fetchSavedAccountMetadata() -> [[String: String]] {
        return UserDefaults.standard.array(forKey: "juicer.accounts.metadata") as? [[String: String]] ?? []
    }
}
