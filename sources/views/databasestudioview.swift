import SwiftUI
import AppKit

typealias databasestudioview = DatabaseStudioView

struct DatabaseDaemonItem: Identifiable {
    var id: String { name }
    let name: String
    let port: Int
    let isRunning: Bool
}

struct SQLiteTableColumn: Identifiable {
    let id = UUID()
    let cid: Int
    let name: String
    let type: String
    let notNull: Bool
    let pk: Bool
}

class DatabaseStudioManager: ObservableObject {
    @Published var daemons: [DatabaseDaemonItem] = []
    @Published var isScanning = false
    @Published var sqlitePath = ""
    @Published var sqliteTables: [String] = []
    @Published var selectedTable: String?
    @Published var selectedTableColumns: [SQLiteTableColumn] = []
    @Published var selectedTableRows: [[String: String]] = []
    @Published var dumpMessage: String = ""
    @Published var isDumping = false

    private var isInitialized = false

    init() {}

    func ensureInitialized() {
        guard !isInitialized else { return }
        isInitialized = true
        self.scanDaemons()
    }

    func purgeMemory() {
        selectedTableRows.removeAll(keepingCapacity: false)
        selectedTableColumns.removeAll(keepingCapacity: false)
    }

    func scanDaemons() {
        self.isScanning = true
        Task.detached(priority: .userInitiated) {
            let pgRunning = self.checkPort(5432)
            let mysqlRunning = self.checkPort(3306)
            let redisRunning = self.checkPort(6379)
            let mongoRunning = self.checkPort(27017)

            let list = [
                DatabaseDaemonItem(name: "PostgreSQL", port: 5432, isRunning: pgRunning),
                DatabaseDaemonItem(name: "MySQL / MariaDB", port: 3306, isRunning: mysqlRunning),
                DatabaseDaemonItem(name: "Redis Cache", port: 6379, isRunning: redisRunning),
                DatabaseDaemonItem(name: "MongoDB", port: 27017, isRunning: mongoRunning)
            ]

            await MainActor.run {
                self.daemons = list
                self.isScanning = false
            }
        }
    }

    func openSQLiteFile(path: String) {
        self.sqlitePath = path
        self.selectedTable = nil
        self.selectedTableColumns.removeAll()
        self.selectedTableRows.removeAll()

        Task.detached(priority: .userInitiated) {
            let output = self.runSQLiteCommand(dbPath: path, args: [".tables"])
            let tables = output.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            await MainActor.run {
                self.sqliteTables = tables
                if let first = tables.first {
                    self.inspectTable(first)
                }
            }
        }
    }

    func inspectTable(_ tableName: String) {
        self.selectedTable = tableName
        guard !sqlitePath.isEmpty else { return }

        Task.detached(priority: .userInitiated) {
            // Fetch Schema (PRAGMA table_info)
            let schemaOutput = self.runSQLiteCommand(dbPath: self.sqlitePath, args: ["PRAGMA table_info('\(tableName)');"])
            var cols: [SQLiteTableColumn] = []
            let lines = schemaOutput.components(separatedBy: "\n")
            for line in lines where !line.isEmpty {
                let parts = line.components(separatedBy: "|")
                if parts.count >= 6 {
                    let cid = Int(parts[0]) ?? 0
                    let name = parts[1]
                    let type = parts[2]
                    let notNull = parts[3] == "1"
                    let pk = parts[5] == "1"
                    cols.append(SQLiteTableColumn(cid: cid, name: name, type: type, notNull: notNull, pk: pk))
                }
            }

            // Fetch Sample Data (50 rows in CSV mode)
            let dataOutput = self.runSQLiteCommand(dbPath: self.sqlitePath, args: ["-header", "-csv", "SELECT * FROM '\(tableName)' LIMIT 50;"])
            var rows: [[String: String]] = []
            let dataLines = dataOutput.components(separatedBy: "\n").filter { !$0.isEmpty }
            if let headerLine = dataLines.first {
                let headers = headerLine.components(separatedBy: ",")
                for line in dataLines.dropFirst() {
                    let values = line.components(separatedBy: ",")
                    var rowDict: [String: String] = [:]
                    for (idx, h) in headers.enumerated() {
                        let cleanH = h.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                        let val = idx < values.count ? values[idx].trimmingCharacters(in: CharacterSet(charactersIn: "\"")) : ""
                        rowDict[cleanH] = val
                    }
                    rows.append(rowDict)
                }
            }

            let finalCols = cols
            let finalRows = rows
            await MainActor.run {
                self.selectedTableColumns = finalCols
                self.selectedTableRows = finalRows
            }
        }
    }

    func exportDumpToFile() {
        guard !sqlitePath.isEmpty else { return }
        let panel = NSSavePanel()
        panel.title = "Export SQLite Dump"
        panel.nameFieldStringValue = "backup_\(Int(Date().timeIntervalSince1970)).sql"
        panel.allowedContentTypes = [.plainText]

        guard panel.runModal() == .OK, let targetURL = panel.url else { return }

        isDumping = true
        dumpMessage = "Exporting SQL dump..."

        Task.detached(priority: .userInitiated) {
            let sqlDump = self.runSQLiteCommand(dbPath: self.sqlitePath, args: [".dump"])
            do {
                try sqlDump.write(to: targetURL, atomically: true, encoding: .utf8)
                await MainActor.run {
                    self.isDumping = false
                    self.dumpMessage = "Successfully exported SQL dump to \(targetURL.lastPathComponent)!"
                }
            } catch {
                await MainActor.run {
                    self.isDumping = false
                    self.dumpMessage = "Error writing dump file: \(error.localizedDescription)"
                }
            }
        }
    }

    private func checkPort(_ port: Int) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nc")
        process.arguments = ["-z", "-w", "1", "127.0.0.1", "\(port)"]
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    private func runSQLiteCommand(dbPath: String, args: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [dbPath] + args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch { return "" }
    }
}

struct DatabaseStudioView: View {
    @StateObject private var manager = DatabaseStudioManager()
    @State private var selectedTab = "Daemons"

    var body: some View {
        VStack(spacing: 0) {
            JuicerFeatureHeader(
                title: "Juicer Database Studio",
                subtitle: "Inspect local Postgres, MySQL, SQLite, and Redis databases, browse schema & dumps.",
                icon: "cylinder.split.1x2.fill",
                refreshing: manager.isScanning,
                action: { manager.scanDaemons() }
            )
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))

            Divider()

            HStack {
                Picker("", selection: $selectedTab) {
                    Text("Local DB Daemons").tag("Daemons")
                    Text("SQLite Inspector").tag("SQLite")
                    Text("SQL Dump Studio").tag("Dump")
                }
                .pickerStyle(.segmented)
                .frame(width: 380)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            switch selectedTab {
            case "Daemons":
                daemonsView()
            case "SQLite":
                sqliteView()
            default:
                dumpStudioView()
            }
        }
        .onAppear {
            manager.ensureInitialized()
        }
        .allowWindowDragAndFit()
    }

    @ViewBuilder
    private func daemonsView() -> some View {
        List(manager.daemons) { daemon in
            HStack(spacing: 12) {
                Circle()
                    .fill(daemon.isRunning ? Color.green : Color.secondary.opacity(0.5))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(daemon.name).bold()
                    Text("Port \(daemon.port)").font(.caption.monospaced()).foregroundStyle(.secondary)
                }

                Spacer()

                Text(daemon.isRunning ? "Active (Port \(daemon.port))" : "Offline")
                    .font(.caption).bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(daemon.isRunning ? Color.green.opacity(0.15) : Color.secondary.opacity(0.15))
                    .foregroundStyle(daemon.isRunning ? Color.green : Color.secondary)
                    .cornerRadius(4)
            }
            .padding(.vertical, 4)
        }
        .listStyle(.inset)
    }

    @ViewBuilder
    private func sqliteView() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("Path to .sqlite or .db file...", text: $manager.sqlitePath)
                    .textFieldStyle(.roundedBorder)
                Button("Choose File...") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = true
                    panel.allowedContentTypes = [.data, .database]
                    if panel.runModal() == .OK, let url = panel.url {
                        manager.openSQLiteFile(path: url.path)
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if !manager.sqliteTables.isEmpty {
                HSplitView {
                    // Left Column: Tables List
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tables (\(manager.sqliteTables.count))").font(.headline)
                        List(manager.sqliteTables, id: \.self) { table in
                            HStack {
                                Image(systemName: "tablecells").foregroundStyle(table == manager.selectedTable ? Color.accentColor : Color.secondary)
                                Text(table).font(.system(.body, design: .monospaced))
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                manager.inspectTable(table)
                            }
                        }
                        .listStyle(.inset)
                    }
                    .frame(minWidth: 180, maxWidth: 260)
                    .padding()

                    // Right Column: Schema Columns & Sample Data Preview
                    VStack(alignment: .leading, spacing: 10) {
                        if let tableName = manager.selectedTable {
                            HStack {
                                Text("Table: \(tableName)").font(.headline)
                                Spacer()
                                Text("\(manager.selectedTableColumns.count) columns • \(manager.selectedTableRows.count) rows preview")
                                    .font(.caption).foregroundStyle(.secondary)
                            }

                            // Schema Column Table
                            Text("Column Schema:").font(.subheadline).bold()
                            ScrollView(.horizontal) {
                                HStack(spacing: 8) {
                                    ForEach(manager.selectedTableColumns) { col in
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 4) {
                                                if col.pk { Image(systemName: "key.fill").font(.caption2).foregroundStyle(.orange) }
                                                Text(col.name).font(.caption.bold())
                                            }
                                            Text(col.type).font(.caption2.monospaced()).foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.secondary.opacity(0.1))
                                        .cornerRadius(6)
                                    }
                                }
                            }

                            Divider()

                            // Data Sample Rows
                            Text("Sample Rows (First 50):").font(.subheadline).bold()
                            if manager.selectedTableRows.isEmpty {
                                Text("Table contains no rows.")
                                    .font(.caption).foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                List(0..<manager.selectedTableRows.count, id: \.self) { rowIdx in
                                    let row = manager.selectedTableRows[rowIdx]
                                    HStack(spacing: 12) {
                                        ForEach(manager.selectedTableColumns) { col in
                                            Text(row[col.name] ?? "null")
                                                .font(.caption.monospaced())
                                                .lineLimit(1)
                                                .frame(width: 110, alignment: .leading)
                                        }
                                    }
                                }
                                .listStyle(.inset)
                            }
                        }
                    }
                    .padding()
                }
            } else {
                JuicerEmptyState(title: "No SQLite Database Loaded", detail: "Enter a path or click 'Choose File...' to inspect SQLite schema and preview sample rows.")
                    .frame(maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private func dumpStudioView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.badge.arrow.up")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("SQL Database Dump & Export Studio")
                .font(.title2.bold())
            Text("Generate full SQL dumps (.sql) for active SQLite database files with single-click export.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            if !manager.sqlitePath.isEmpty {
                VStack(spacing: 8) {
                    Text("Selected Database:").font(.caption).foregroundStyle(.secondary)
                    Text(manager.sqlitePath).font(.caption.monospaced()).bold()
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }

            if !manager.dumpMessage.isEmpty {
                Text(manager.dumpMessage)
                    .font(.caption)
                    .foregroundStyle(manager.dumpMessage.contains("Error") ? Color.red : Color.green)
            }

            Button(action: { manager.exportDumpToFile() }) {
                HStack {
                    if manager.isDumping { ProgressView().controlSize(.small) }
                    Text("Export SQL Dump File (.sql)")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(manager.sqlitePath.isEmpty || manager.isDumping)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
