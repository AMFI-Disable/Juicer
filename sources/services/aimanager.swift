import Foundation
import Combine

struct AIModel: Identifiable, Hashable {
    let id: String
    let name: String
    let provider: String
    let size: String
    let modifiedAt: String
}

struct AIPromptSnippet: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let category: String
    let content: String
    let tags: [String]
}

struct AIChatMessage: Identifiable {
    let id = UUID()
    let isUser: Bool
    let text: String
    let timestamp: Date = Date()
}

final class AIManager: ObservableObject {
    static let shared = AIManager()

    @Published var isOllamaActive = false
    @Published var isLMStudioActive = false
    @Published var localModels: [AIModel] = []
    @Published var isRefreshing = false
    @Published var chatMessages: [AIChatMessage] = [
        AIChatMessage(isUser: false, text: "Hello! I am your Juicer AI Assistant. Select a model or prompt template from the vault to start debugging code or analyzing stack traces.")
    ]
    @Published var isGenerating = false

    @Published var promptVault: [AIPromptSnippet] = [
        AIPromptSnippet(
            title: "🔍 Security & Code Review",
            category: "Code Review",
            content: "Perform a comprehensive security, performance, and readability code review for the following code. Point out memory leaks, retain cycles, or inefficient loop logic:\n\n```swift\n\n```",
            tags: ["Review", "Security", "Swift"]
        ),
        AIPromptSnippet(
            title: "🐛 Stack Trace & Error Debugger",
            category: "Debugging",
            content: "Analyze this build log error or runtime stack trace. Explain the root cause in detail and provide the exact step-by-step fix:\n\n```text\n\n```",
            tags: ["Debug", "Xcode", "Crash"]
        ),
        AIPromptSnippet(
            title: "🏗️ System Architecture Planner",
            category: "Architecture",
            content: "Design a clean, modular architecture for a new feature. Outline component boundaries, data models, state flow, and edge cases.",
            tags: ["Architecture", "Design"]
        ),
        AIPromptSnippet(
            title: "📝 Docstring & API Spec Generator",
            category: "Documentation",
            content: "Generate standard Swift / Markdown documentation comments for the following methods and data models.",
            tags: ["Docs", "Comments"]
        )
    ]

    private var isInitialized = false

    private init() {}

    func ensureInitialized() {
        guard !isInitialized else { return }
        isInitialized = true
        checkLocalServices()
    }

    func purgeMemory() {
        if chatMessages.count > 10 {
            chatMessages = Array(chatMessages.prefix(5))
        }
    }

    func checkLocalServices() {
        isRefreshing = true

        let group = DispatchGroup()
        var models: [AIModel] = []
        var ollamaOk = false
        var lmStudioOk = false

        // 1. Query Ollama (http://localhost:11434/api/tags)
        group.enter()
        if let url = URL(string: "http://localhost:11434/api/tags") {
            var request = URLRequest(url: url)
            request.timeoutInterval = 2.5
            URLSession.shared.dataTask(with: request) { data, response, _ in
                defer { group.leave() }
                if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200,
                   let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let modelsArray = json["models"] as? [[String: Any]] {
                    ollamaOk = true
                    for item in modelsArray {
                        let name = item["name"] as? String ?? "Unknown"
                        let sizeBytes = item["size"] as? Int64 ?? 0
                        let sizeFormatted = ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
                        models.append(AIModel(id: name, name: name, provider: "Ollama", size: sizeFormatted, modifiedAt: "Local"))
                    }
                }
            }.resume()
        } else { group.leave() }

        // 2. Query LM Studio (http://localhost:1234/v1/models)
        group.enter()
        if let url = URL(string: "http://localhost:1234/v1/models") {
            var request = URLRequest(url: url)
            request.timeoutInterval = 2.5
            URLSession.shared.dataTask(with: request) { data, response, _ in
                defer { group.leave() }
                if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200,
                   let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dataArray = json["data"] as? [[String: Any]] {
                    lmStudioOk = true
                    for item in dataArray {
                        let name = item["id"] as? String ?? "Unknown Model"
                        models.append(AIModel(id: name, name: name, provider: "LM Studio", size: "Active VRAM", modifiedAt: "Local"))
                    }
                }
            }.resume()
        } else { group.leave() }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.isOllamaActive = ollamaOk
            self.isLMStudioActive = lmStudioOk
            self.localModels = models
            self.isRefreshing = false
        }
    }

    func sendMessage(_ userText: String, model: String? = nil) {
        guard !userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let userMsg = AIChatMessage(isUser: true, text: userText)
        chatMessages.append(userMsg)
        isGenerating = true

        let selectedModel = model ?? localModels.first?.name ?? "llama3"
        let selectedModelObj = localModels.first(where: { $0.name == selectedModel })
        let isLMStudioModel = selectedModelObj?.provider == "LM Studio"
        let useLMStudio = isLMStudioModel || (!isOllamaActive && isLMStudioActive)

        guard isOllamaActive || isLMStudioActive,
              let endpointURL = URL(string: useLMStudio ? "http://localhost:1234/v1/chat/completions" : "http://localhost:11434/api/generate") else {
            isGenerating = false
            chatMessages.append(AIChatMessage(
                isUser: false,
                text: "No supported local AI engine is available. Start Ollama (`ollama serve`) or LM Studio before sending a prompt."
            ))
            return
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0

        let payload: [String: Any]
        if useLMStudio {
            payload = [
                "model": selectedModel,
                "messages": [["role": "user", "content": userText]],
                "stream": false
            ]
        } else {
            payload = [
                "model": selectedModel,
                "prompt": userText,
                "stream": false
            ]
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isGenerating = false

                if let error = error {
                    let nsErr = error as NSError
                    let detail: String
                    if nsErr.domain == NSURLErrorDomain && nsErr.code == NSURLErrorTimedOut {
                        detail = "Connection timed out"
                    } else {
                        detail = error.localizedDescription
                    }
                    let aiMsg = AIChatMessage(
                        isUser: false,
                        text: "Local model request failed (\(detail)). Verify that \(selectedModel) is available and try again."
                    )
                    self?.chatMessages.append(aiMsg)
                    return
                }

                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                var parsedText: String?
                var apiError: String?

                if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let errStr = json["error"] as? String {
                        apiError = errStr
                    } else if let errDict = json["error"] as? [String: Any], let errStr = errDict["message"] as? String {
                        apiError = errStr
                    }

                    if useLMStudio {
                        if let choices = json["choices"] as? [[String: Any]],
                           let firstChoice = choices.first,
                           let msgDict = firstChoice["message"] as? [String: Any],
                           let content = msgDict["content"] as? String {
                            parsedText = content
                        }
                    } else {
                        if let resp = json["response"] as? String {
                            parsedText = resp
                        }
                    }
                }

                if let text = parsedText, !text.isEmpty {
                    let aiMsg = AIChatMessage(isUser: false, text: text)
                    self?.chatMessages.append(aiMsg)
                } else {
                    let detail = apiError ?? (statusCode > 0 ? "HTTP \(statusCode)" : "invalid response body")
                    let aiMsg = AIChatMessage(
                        isUser: false,
                        text: "Local model request failed (\(detail)). Verify that \(selectedModel) is available in \(useLMStudio ? "LM Studio" : "Ollama") and try again."
                    )
                    self?.chatMessages.append(aiMsg)
                }
            }
        }.resume()
    }
}
