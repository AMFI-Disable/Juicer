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
        var host = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if host.hasPrefix("https://") {
            host = String(host.dropFirst(8))
        } else if host.hasPrefix("http://") {
            host = String(host.dropFirst(7))
        }
        if let slashIdx = host.firstIndex(of: "/") {
            host = String(host[..<slashIdx])
        }
        if let colonIdx = host.firstIndex(of: ":"), !host.contains("]") {
            host = String(host[..<colonIdx])
        }
        host = host.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !host.isEmpty, host.count <= 253, !host.contains("..") else { return nil }

        let pattern = "^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$"
        guard host.range(of: pattern, options: .regularExpression) != nil else { return nil }

        let labels = host.split(separator: ".")
        for label in labels {
            guard label.count >= 1 && label.count <= 63 else { return nil }
            guard !label.hasPrefix("-") && !label.hasSuffix("-") else { return nil }
        }
        return host
    }

    static func ipAddress(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 45 else { return nil }

        let ipv4Parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        if ipv4Parts.count == 4 {
            for part in ipv4Parts {
                guard let num = Int(part), (0...255).contains(num),
                      part == String(num) else { return nil }
            }
            return trimmed
        }

        if trimmed.contains(":") {
            let hexChars = CharacterSet(charactersIn: "0123456789abcdefABCDEF:")
            guard trimmed.unicodeScalars.allSatisfy({ hexChars.contains($0) }) else { return nil }
            return trimmed
        }

        return nil
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
    static func parse(_ output: String, resolver: String, maxRecords: Int = 100) -> DNSDiagnosticResult {
        let boundedOutput = String(output.prefix(65_536))

        if output.contains("timed out") || output.contains("no servers could be reached") {
            return DNSDiagnosticResult(
                status: "TIMEOUT",
                resolver: resolver,
                queryTimeMilliseconds: nil,
                dnssec: "Not reported",
                answers: [],
                error: "DNS query timed out. Server \(resolver) did not respond."
            )
        }
        if output.contains("connection refused") || output.contains("couldn't get address") {
            return DNSDiagnosticResult(
                status: "UNREACHABLE",
                resolver: resolver,
                queryTimeMilliseconds: nil,
                dnssec: "Not reported",
                answers: [],
                error: "Unable to reach DNS resolver \(resolver)."
            )
        }

        let lines = boundedOutput.split(whereSeparator: \.isNewline).prefix(1000).map(String.init)
        let statusLine = lines.first(where: { $0.contains("status:") })
        let status: String
        if let rawStatus = statusLine?.components(separatedBy: "status:").last?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) {
            let sanitizedStatus = rawStatus.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
            status = sanitizedStatus.isEmpty ? "UNKNOWN" : String(sanitizedStatus.prefix(20))
        } else {
            status = "UNKNOWN"
        }

        var queryTime: Int?
        if let queryLine = lines.first(where: { $0.localizedCaseInsensitiveContains("Query time:") }) {
            let tokens = queryLine.split(whereSeparator: { $0 == " " || $0 == "\t" })
            if let idx = tokens.firstIndex(where: { $0.localizedCaseInsensitiveContains("Query") }), idx + 2 < tokens.count, let val = Int(tokens[idx + 2]) {
                if (0...300_000).contains(val) {
                    queryTime = val
                }
            }
        }

        let dnssec = lines.contains(where: { $0.contains(" ad;") || $0.contains(" ad,") }) ? "Validated (AD flag)" : "Not reported"
        var answers: [DNSAnswer] = []
        var inAnswer = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == ";; ANSWER SECTION:" { inAnswer = true; continue }
            if inAnswer && trimmed.hasPrefix(";;") { inAnswer = false; continue }
            guard inAnswer else { continue }
            let parts = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard parts.count >= 5 else { continue }
            let rawName = String(parts[0]).trimmingCharacters(in: CharacterSet(charactersIn: "."))
            let recordType = String(parts[3]).components(separatedBy: CharacterSet.letters.inverted).joined()
            let rawValue = parts.dropFirst(4).joined(separator: " ")
            let sanitizedValue = String(rawValue.prefix(256)).trimmingCharacters(in: .whitespacesAndNewlines)

            guard !rawName.isEmpty, !recordType.isEmpty, answers.count < maxRecords else { continue }
            answers.append(DNSAnswer(name: String(rawName.prefix(253)), recordType: String(recordType.prefix(16)), value: sanitizedValue))
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
