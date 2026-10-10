import Foundation

enum AnalyticsTimeHorizon: String, CaseIterable, Identifiable {
    case days30 = "30d"
    case days90 = "90d"
    case days365 = "365d"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .days30: return "30 Days"
        case .days90: return "90 Days"
        case .days365: return "1 Year"
        }
    }
}

struct CaskAnalyticsEntry: Decodable, Identifiable {
    let cask: String
    let count: String

    var id: String { cask }
    var installCount: Int {
        Int(count.replacingOccurrences(of: ",", with: "")) ?? 0
    }
}

struct CaskAnalyticsResponse: Decodable {
    let items: [CaskAnalyticsEntry]
}

@MainActor
class StoreAnalyticsManager: ObservableObject {
    @Published var topCharts: [CaskAnalyticsEntry] = []
    @Published var selectedHorizon: AnalyticsTimeHorizon = .days30
    @Published var isLoading = false

    func fetchAnalytics(horizon: AnalyticsTimeHorizon = .days30) {
        self.selectedHorizon = horizon
        self.isLoading = true

        let urlString = "https://formulae.brew.sh/api/analytics/cask-install/\(horizon.rawValue).json"
        guard let url = URL(string: urlString) else {
            self.isLoading = false
            return
        }

        Task.detached(priority: .userInitiated) {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let decoded = try JSONDecoder().decode(CaskAnalyticsResponse.self, from: data)
                await MainActor.run {
                    self.topCharts = Array(decoded.items.prefix(100))
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}
