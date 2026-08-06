import Foundation

enum AskpassScriptManager {
    static func create(token: String) -> URL? {
        let safeToken = token.filter { $0.isLetter || $0.isNumber || "-_+@.".contains($0) }
        let script = """
        #!/bin/sh
        osascript -e 'Tell application "System Events" to display dialog "Juicer needs administrative authorization to install package cask '\'"\(safeToken)"\'" :" default answer "" with hidden answer with title "Juicer Privileged Helper"' -e 'text returned of result' 2>/dev/null
        """
        
        let fileManager = FileManager.default
        guard let baseDir = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        
        let destDir = baseDir.appendingPathComponent("Juicer/askpass", isDirectory: true)
        let scriptURL = destDir.appendingPathComponent("askpass-\(UUID().uuidString).sh")
        
        do {
            try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
            return scriptURL
        } catch {
            return nil
        }
    }
    
    static func remove(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
