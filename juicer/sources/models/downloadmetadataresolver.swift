import Foundation

actor DownloadMetadataResolver {
    static let shared = DownloadMetadataResolver()
    private var cache: [String: String] = [:]

    func downloadSizeFormatted(for urlString: String?) async -> String? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        if let cached = cache[urlString] { return cached }

        if let bytes = await loadContentLength(from: url) {
            let formatted = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
            cache[urlString] = formatted
            return formatted
        }
        return nil
    }

    private nonisolated func loadContentLength(from url: URL) async -> Int64? {
        var head = URLRequest(url: url, timeoutInterval: 12)
        head.httpMethod = "HEAD"
        if let response = try? await URLSession.shared.data(for: head).1,
           response.expectedContentLength > 0 {
            return response.expectedContentLength
        }

        var ranged = URLRequest(url: url, timeoutInterval: 12)
        ranged.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        guard let response = try? await URLSession.shared.data(for: ranged).1 as? HTTPURLResponse,
              let contentRange = response.value(forHTTPHeaderField: "Content-Range"),
              let totalStr = contentRange.split(separator: "/").last,
              let totalBytes = Int64(totalStr)
        else { return nil }
        return totalBytes
    }
}
