import SwiftUI
import AppKit

typealias aistudioview = AIStudioView

struct AIStudioView: View {
    @ObservedObject private var manager = AIManager.shared
    @State private var selectedTab = "Chat"
    @State private var promptInputText = ""
    @State private var selectedModelID: String = ""
    @State private var vaultSearchQuery = ""

    var body: some View {
        VStack(spacing: 0) {
            JuicerFeatureHeader(
                title: "Juicer AI & LLM Studio",
                subtitle: "Monitor local Ollama & LM Studio runtimes, run code diagnostics, and organize prompt vaults.",
                icon: "sparkles",
                refreshing: manager.isRefreshing,
                action: { manager.checkLocalServices() }
            )
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))

            daemonStatusBar()

            Divider()

            HStack {
                Picker("", selection: $selectedTab) {
                    Text("AI Chat Assistant").tag("Chat")
                    Text("Local Models (\(manager.localModels.count))").tag("Models")
                    Text("Prompt Vault (\(manager.promptVault.count))").tag("Vault")
                }
                .pickerStyle(.segmented)
                .frame(width: 380)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            switch selectedTab {
            case "Chat":
                chatView()
            case "Models":
                modelsView()
            default:
                vaultView()
            }
        }
        .onAppear {
            if selectedModelID.isEmpty, let firstModel = manager.localModels.first {
                selectedModelID = firstModel.name
            }
        }
        .allowWindowDragAndFit()
    }

    @ViewBuilder
    private func daemonStatusBar() -> some View {
        HStack(spacing: 16) {
            daemonBadge(name: "Ollama (11434)", isActive: manager.isOllamaActive)
            daemonBadge(name: "LM Studio (1234)", isActive: manager.isLMStudioActive)

            Spacer()

            if !manager.isOllamaActive && !manager.isLMStudioActive {
                Text("Tip: Run `ollama serve` in terminal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }

    private func daemonBadge(name: String, isActive: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isActive ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(name)
                .font(.caption.weight(.medium))
            Text(isActive ? "Online" : "Offline")
                .font(.caption2)
                .foregroundStyle(isActive ? .green : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().stroke(isActive ? Color.green.opacity(0.3) : Color.secondary.opacity(0.2)))
    }

    @ViewBuilder
    private func chatView() -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Active Model:").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $selectedModelID) {
                    if manager.localModels.isEmpty {
                        Text("No Model Available").tag("")
                    } else {
                        ForEach(manager.localModels) { model in
                            Text("\(model.name) (\(model.provider))").tag(model.name)
                        }
                    }
                }
                .frame(width: 220)

                Spacer()

                Button(action: { manager.chatMessages.removeAll() }) {
                    Label("Clear Chat", systemImage: "trash")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.2))

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(manager.chatMessages) { msg in
                            chatBubble(msg)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: manager.chatMessages.count) { _ in
                    if let lastMsg = manager.chatMessages.last {
                        withAnimation { proxy.scrollTo(lastMsg.id, anchor: .bottom) }
                    }
                }
            }

            Divider()

            HStack(alignment: .bottom, spacing: 8) {
                TextEditor(text: $promptInputText)
                    .font(.system(.body, design: .default))
                    .frame(minHeight: 40, maxHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))

                Button(action: sendPrompt) {
                    if manager.isGenerating {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(manager.isGenerating || promptInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
    }

    private func chatBubble(_ msg: AIChatMessage) -> some View {
        HStack {
            if msg.isUser { Spacer() }
            VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 4) {
                Text(msg.isUser ? "You" : "Juicer AI")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)

                Text(msg.text)
                    .textSelection(.enabled)
                    .padding(10)
                    .background(msg.isUser ? Color.accentColor.opacity(0.2) : Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
            }
            .frame(maxWidth: 540, alignment: msg.isUser ? .trailing : .leading)
            if !msg.isUser { Spacer() }
        }
    }

    private func sendPrompt() {
        let text = promptInputText
        promptInputText = ""
        manager.sendMessage(text, model: selectedModelID.isEmpty ? nil : selectedModelID)
    }

    @ViewBuilder
    private func modelsView() -> some View {
        if manager.localModels.isEmpty {
            JuicerEmptyState(
                title: "No Local LLM Runtimes Online",
                detail: "Start Ollama daemon (`ollama serve`) or LM Studio (`localhost:1234`) to execute local AI models."
            )
            .frame(maxHeight: .infinity)
        } else {
            List(manager.localModels) { model in
                HStack(spacing: 12) {
                    Image(systemName: model.provider == "Ollama" ? "cpu" : "cube.transparent")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.name).bold()
                        Text("Provider: \(model.provider) • Size: \(model.size)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Use in Chat") {
                        selectedModelID = model.name
                        selectedTab = "Chat"
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            }
            .listStyle(.inset)
        }
    }

    @ViewBuilder
    private func vaultView() -> some View {
        VStack(spacing: 10) {
            TextField("Search prompt templates or tags...", text: $vaultSearchQuery)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            List(filteredPrompts) { snippet in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(snippet.title).font(.headline)
                        Spacer()
                        Text(snippet.category).font(.caption).padding(.horizontal, 6).padding(.vertical, 2).background(Color.accentColor.opacity(0.15)).cornerRadius(4)
                    }

                    Text(snippet.content)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)

                    HStack {
                        ForEach(snippet.tags, id: \.self) { tag in
                            Text("#\(tag)").font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Apply Template") {
                            promptInputText = snippet.content
                            selectedTab = "Chat"
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 6)
            }
            .listStyle(.inset)
        }
        .padding(.top, 8)
    }

    private var filteredPrompts: [AIPromptSnippet] {
        if vaultSearchQuery.isEmpty { return manager.promptVault }
        return manager.promptVault.filter {
            $0.title.localizedCaseInsensitiveContains(vaultSearchQuery) ||
            $0.content.localizedCaseInsensitiveContains(vaultSearchQuery) ||
            $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(vaultSearchQuery) })
        }
    }
}
