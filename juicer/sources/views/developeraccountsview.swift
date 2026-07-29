import SwiftUI
import AppKit

struct developeraccountsview: View {
    @StateObject private var manager = KeychainAccountManager()
    @State private var selectedProvider = "GitHub"
    @State private var usernameInput = ""
    @State private var tokenInput = ""
    @State private var showAddAccountSheet = false
    @State private var selectedTab = "Accounts"

    var body: some View {
        VStack(spacing: 0) {
            JuicerFeatureHeader(
                title: "Developer Accounts & OAuth Vault",
                subtitle: "Manage GitHub, GitLab, Docker Hub, OpenAI, Anthropic, and Gemini authentication tokens securely in macOS Keychain.",
                icon: "key.fill",
                refreshing: manager.isLoading,
                action: { manager.loadAccountsFromKeychain() }
            )
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))

            Divider()

            HStack {
                Picker("", selection: $selectedTab) {
                    Text("Connected Accounts (\(manager.accounts.count))").tag("Accounts")
                    Text("Integrations & Services").tag("Services")
                }
                .pickerStyle(.segmented)
                .frame(width: 320)

                Spacer()

                Button("Connect New Account...") {
                    showAddAccountSheet = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            if selectedTab == "Accounts" {
                accountsListView()
            } else {
                servicesOverviewView()
            }
        }
        .sheet(isPresented: $showAddAccountSheet) {
            addAccountSheetView()
        }
        .allowWindowDragAndFit()
    }

    @ViewBuilder
    private func accountsListView() -> some View {
        if manager.accounts.isEmpty {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 80, height: 80)
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(Color.accentColor)
                }

                Text("No Connected Developer Accounts")
                    .font(.title3.bold())

                Text("Connect GitHub, Docker Hub, or AI service keys to unlock PR management, private container pulls, and cloud LLM benchmarks.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)

                Button("Connect GitHub / Service Account") {
                    showAddAccountSheet = true
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else {
            List(manager.accounts) { account in
                HStack(spacing: 14) {
                    Image(systemName: providerIcon(for: account.provider))
                        .font(.title2)
                        .foregroundStyle(providerColor(for: account.provider))
                        .frame(width: 38, height: 38)
                        .background(providerColor(for: account.provider).opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(account.username)
                                .font(.headline)

                            Text(account.provider)
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(providerColor(for: account.provider).opacity(0.18))
                                .foregroundStyle(providerColor(for: account.provider))
                                .cornerRadius(4)
                        }

                        Text("Type: \(account.tokenType) • Keychain Secured")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Test Connection") {
                        JuicerHaptic.performClick()
                    }
                    .buttonStyle(.bordered)

                    Button(action: {
                        JuicerHaptic.performClick()
                        manager.removeAccount(account)
                    }) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Disconnect Account & Purge Keychain Token")
                }
                .padding(.vertical, 6)
            }
            .listStyle(.inset)
        }
    }

    @ViewBuilder
    private func servicesOverviewView() -> some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                serviceCard(
                    title: "GitHub & GitLab Integration",
                    desc: "Unlocks PR creation/review, Actions CI/CD streaming, Gist sync, and repository cloning in Juicer Git Studio.",
                    icon: "arrow.triangle.pull",
                    color: .purple,
                    isConnected: manager.accounts.contains(where: { $0.provider == "GitHub" || $0.provider == "GitLab" })
                )

                serviceCard(
                    title: "Docker Hub & GHCR",
                    desc: "Enables searching and pulling private organization container images & vulnerability scanning in Juicer Docker Studio.",
                    icon: "cube.fill",
                    color: .cyan,
                    isConnected: manager.accounts.contains(where: { $0.provider == "DockerHub" })
                )

                serviceCard(
                    title: "OpenAI, Anthropic & Gemini",
                    desc: "Powers cloud vs local LLM speed benchmarking and token budget tracking in Juicer AI Studio.",
                    icon: "sparkles",
                    color: .orange,
                    isConnected: manager.accounts.contains(where: { $0.provider == "OpenAI" || $0.provider == "Anthropic" || $0.provider == "Gemini" })
                )

                serviceCard(
                    title: "Private Package Registries",
                    desc: "Authenticates private npm packages, PyPI feeds, and enterprise Homebrew taps in Juicer Store.",
                    icon: "shippingbox.fill",
                    color: .blue,
                    isConnected: false
                )
            }
            .padding()
        }
    }

    @ViewBuilder
    private func serviceCard(title: String, desc: String, icon: String, color: Color, isConnected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
                Spacer()
                Text(isConnected ? "Connected" : "Not Linked")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isConnected ? Color.green.opacity(0.18) : Color.gray.opacity(0.18))
                    .foregroundStyle(isConnected ? Color.green : Color.secondary)
                    .cornerRadius(4)
            }

            Text(desc)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.3), lineWidth: 1))
    }

    @ViewBuilder
    private func addAccountSheetView() -> some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "key.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                Text("Connect Developer Account")
                    .font(.title3.bold())
                Spacer()
                Button("Cancel") { showAddAccountSheet = false }
                    .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Select Provider:").bold()
                Picker("", selection: $selectedProvider) {
                    Text("GitHub").tag("GitHub")
                    Text("GitLab").tag("GitLab")
                    Text("Docker Hub").tag("DockerHub")
                    Text("OpenAI").tag("OpenAI")
                    Text("Anthropic").tag("Anthropic")
                    Text("Google Gemini").tag("Gemini")
                }
                .pickerStyle(.segmented)

                Text("Account Username / Identifer:").bold()
                TextField("e.g. octocat or developer@company.com", text: $usernameInput)
                    .textFieldStyle(.roundedBorder)

                Text("Personal Access Token (PAT) / API Key:").bold()
                SecureField("ghp_xxxx or sk-proj-xxxx", text: $tokenInput)
                    .textFieldStyle(.roundedBorder)

                Text("Tokens are hardware-encrypted directly inside the macOS System Keychain using SecItemAdd.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Save Account to Keychain") {
                    if !usernameInput.isEmpty && !tokenInput.isEmpty {
                        JuicerHaptic.performSuccess()
                        manager.saveToken(provider: selectedProvider, username: usernameInput, token: tokenInput)
                        usernameInput = ""
                        tokenInput = ""
                        showAddAccountSheet = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(usernameInput.isEmpty || tokenInput.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    private func providerIcon(for provider: String) -> String {
        switch provider {
        case "GitHub", "GitLab": return "arrow.triangle.pull"
        case "DockerHub": return "cube.fill"
        case "OpenAI", "Anthropic", "Gemini": return "sparkles"
        default: return "key.fill"
        }
    }

    private func providerColor(for provider: String) -> Color {
        switch provider {
        case "GitHub": return .purple
        case "GitLab": return .orange
        case "DockerHub": return .cyan
        case "OpenAI": return .green
        case "Anthropic": return .orange
        case "Gemini": return .blue
        default: return .accentColor
        }
    }
}
