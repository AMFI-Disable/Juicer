import SwiftUI

struct SystemPathAnalysisView: View {
    @State private var path: String = ""
    @State private var result: String = "Enter a path to analyze"

    var body: some View {
        VStack(spacing: 20) {
            Text("System Path Analyzer")
                .font(.headline)

            TextField("Enter file or directory path", text: $path)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("Analyze Path") {
                analyzePath()
            }
            .buttonStyle(.borderedProminent)

            TextEditor(text: .constant(result))
                .frame(height: 200)
                .border(Color.gray, width: 1)
        }
        .padding()
    }

    private func analyzePath() {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false

        if fileManager.fileExists(atPath: path, isDirectory: &isDir) {
            let attributes = try? fileManager.attributesOfItem(atPath: path)
            let type = isDir.boolValue ? "Directory" : "File"
            result = "Path: \(path)\nType: \(type)\nAttributes: \(String(describing: attributes))"
        } else {
            result = "Path does not exist."
        }
    }
}
