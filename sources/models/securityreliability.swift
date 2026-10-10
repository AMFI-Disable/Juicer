import Foundation

struct SecurityHeuristicFinding: Equatable, Identifiable {
    let id = UUID()
    let path: String
    let rule: String
    let confidence: String
}

enum SecurityHeuristicParser {
    static func launchItemFindings(paths: [String]) -> [SecurityHeuristicFinding] {
        paths.filter { path in
            let name = path.lowercased()
            return name.contains("keylog") || name.contains("input") || name.contains("hook")
        }.map { SecurityHeuristicFinding(path: $0, rule: "Filename contains keylog, input, or hook", confidence: "Low") }
    }
}

enum USBInventoryParser {
    static func deviceNames(_ output: String) -> [String] {
        output.split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { $0.hasSuffix(":") && !$0.contains("USB:") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: ":")) }
            .filter { !$0.isEmpty }
    }
}
