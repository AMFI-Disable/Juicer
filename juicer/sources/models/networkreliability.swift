import Foundation

struct SpeedTestSummary: Equatable {
    let endpoint: String
    let bytes: Int
    let elapsed: TimeInterval
    let statusCode: Int

    var megabitsPerSecond: Double {
        guard elapsed > 0 else { return 0 }
        return Double(bytes * 8) / elapsed / 1_000_000
    }
}

struct DNSAnswer: Equatable, Identifiable {
    let id = UUID()
    let name: String
    let recordType: String
    let value: String
}

struct DNSDiagnosticResult: Equatable {
    let status: String
    let resolver: String
    let queryTimeMilliseconds: Int?
    let dnssec: String
    let answers: [DNSAnswer]
    let error: String?
}

enum NetworkInputValidation {
    static func hostname(_ value: String) -> String? {
        let host = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, host.count <= 253, !host.contains("..") else { return nil }
        let pattern = "^[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?$"
        guard host.range(of: pattern, options: .regularExpression) != nil else { return nil }
        return host
    }

    static func resolver(_ value: String) -> String? {
        let candidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty, candidate.count <= 253,
              candidate.range(of: #"^[A-Za-z0-9:.%-]+$"#, options: .regularExpression) != nil else { return nil }
        return candidate
    }

    static func ports(_ value: String) -> [Int] {
        Array(Set(value.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { (1...65535).contains($0) })).sorted()
    }

    static func bonjourService(_ value: String) -> String? {
        let service = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard service.range(of: #"^_[A-Za-z0-9-]+\._(tcp|udp)$"#, options: .regularExpression) != nil else { return nil }
        return service
    }
}

enum DNSDiagnosticParser {
    static func parse(_ output: String, resolver: String) -> DNSDiagnosticResult {
        let lines = output.split(whereSeparator: \.isNewline).map(String.init)
        let statusLine = lines.first(where: { $0.contains("status:") })
        let status: String
        if let rawStatus = statusLine?.components(separatedBy: "status:").last?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) {
            status = rawStatus
        } else {
            status = "UNKNOWN"
        }
        var queryTime: Int? = nil
        if let queryLine = lines.first(where: { $0.localizedCaseInsensitiveContains("Query time:") }) {
            let tokens = queryLine.split(whereSeparator: { $0 == " " || $0 == "\t" })
            if let idx = tokens.firstIndex(where: { $0.localizedCaseInsensitiveContains("Query") }), idx + 2 < tokens.count, let val = Int(tokens[idx + 2]) {
                queryTime = val
            }
        }
        let dnssec = lines.contains(where: { $0.contains(" ad;") || $0.contains(" ad,") }) ? "Validated (AD flag)" : "Not reported"
        var answers: [DNSAnswer] = []
        var inAnswer = false
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces) == ";; ANSWER SECTION:" { inAnswer = true; continue }
            if inAnswer && line.hasPrefix(";;") { inAnswer = false; continue }
            guard inAnswer else { continue }
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard parts.count >= 5 else { continue }
            answers.append(DNSAnswer(name: String(parts[0]), recordType: String(parts[3]), value: parts.dropFirst(4).joined(separator: " ")))
        }
        let error: String? = status == "NOERROR" ? nil : "Resolver returned status \(status). Check the hostname, resolver, and network connection."
        return DNSDiagnosticResult(status: status, resolver: resolver, queryTimeMilliseconds: queryTime, dnssec: dnssec, answers: answers, error: error)
    }
}

struct LANDiscoveryResult: Equatable {
    let service: String
    let instances: [String]
    let output: String
    let timedOut: Bool
}

enum PortScanState: String, Equatable { case pending, open, closed, timedOut, error }
struct PortScanResult: Identifiable, Equatable {
    let id = UUID()
    let port: Int
    var state: PortScanState
    var detail: String
}

enum LANDiscoveryParser {
    static func parse(_ output: String, service: String, timedOut: Bool = false) -> LANDiscoveryResult {
        let instances = output.split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty && !$0.contains("DATE:") && !$0.hasPrefix("Browsing") }
        return LANDiscoveryResult(service: service, instances: instances, output: output, timedOut: timedOut)
    }
}
