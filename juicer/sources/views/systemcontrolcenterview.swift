import SwiftUI
import AppKit

struct systemcontrolcenterview: View {
    let onSelect: (NavigationItem) -> Void

    @StateObject private var cpuManager = CPUMemoryMonitorManager()
    @StateObject private var batteryManager = BatteryHealthManager()
    @StateObject private var thermalManager = ThermalMonitorManager()

    private let quickActions: [NavigationItem] = [.statusMonitor, .cpuMemoryMonitor, .batteryHealth, .workflowCenter]
    private let monitoring: [NavigationItem] = [.statusMonitor, .cpuMemoryMonitor, .gpuMonitor, .diskIOMonitor]
    private let power: [NavigationItem] = [.batteryHealth, .batterySaver, .powerSchedule, .thermalMonitor, .fanController, .memoryPurge, .swapManager]
    private let processTools: [NavigationItem] = [.processKiller, .startupItems, .loginItemDelays, .systemLogs, .systemServices, .kextManager]
    private let diagnostics: [NavigationItem] = [.memoryPressureOptimizer, .pathSecurityAuditor, .duplicateSanitizer]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                healthSummary
                toolSection("Start here", subtitle: "Common system tasks", items: quickActions)
                toolSection("Monitoring", subtitle: "Live hardware and usage data", items: monitoring)
                toolSection("Power & thermals", subtitle: "Battery, cooling, and memory controls", items: power)
                toolSection("Processes & logs", subtitle: "Startup items, services, and diagnostics", items: processTools)
                toolSection("System checks", subtitle: "Review issues before making changes", items: diagnostics)
            }
            .padding(32)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            cpuManager.start()
            batteryManager.refresh()
            thermalManager.refresh()
        }
        .onDisappear { cpuManager.stop() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("System Center", systemImage: "cpu.fill")
                .font(.largeTitle.bold())
                .foregroundStyle(JuicerWorkspace.system.themeColor)
            Text("A quiet starting point for understanding and maintaining this Mac.")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Choose a workflow below. Juicer keeps observation separate from actions so you can review a state before changing it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var healthSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current health").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                JuicerMetricTile(title: "CPU", value: SystemMetricsSupport.percent(cpuManager.cpuPercent), detail: "current load", color: .blue)
                JuicerMetricTile(title: "Memory", value: SystemMetricsSupport.bytes(cpuManager.memoryUsedBytes), detail: cpuManager.memoryPressure.capitalized + " pressure", color: .purple)
                JuicerMetricTile(title: "Battery", value: batteryManager.reading.present ? SystemMetricsSupport.percent(batteryManager.reading.capacity) : "No battery", detail: batteryManager.reading.charging ? "charging" : "power status", color: .green)
                JuicerMetricTile(title: "Thermals", value: thermalManager.reading.level, detail: thermalManager.reading.detail, color: thermalManager.reading.throttling ? .orange : .green)
            }
        }
    }

    private func toolSection(_ title: String, subtitle: String, items: [NavigationItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                ForEach(items) { item in
                    Button { onSelect(item) } label: {
                        HStack(spacing: 10) {
                            JuicerSymbol(name: item.iconName, fallback: "square.grid.2x2")
                                .frame(width: 22)
                                .foregroundStyle(JuicerWorkspace.system.themeColor)
                            Text(item.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
