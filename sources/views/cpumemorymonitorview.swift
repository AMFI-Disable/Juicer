import SwiftUI

@MainActor
struct cpumemorymonitorview: View {
    @StateObject private var manager = CPUMemoryMonitorManager()

    private func safePercent(_ value: Double) -> Double {
        guard !value.isNaN && !value.isInfinite else { return 0.0 }
        return min(100.0, max(0.0, value))
    }

    private var clampedCPUPercent: Double {
        safePercent(manager.cpuPercent)
    }

    private var memoryPercent: Double {
        let total = Double(max(1, manager.memoryTotalBytes))
        let used = Double(manager.memoryUsedBytes)
        return (used / total) * 100.0
    }

    private var clampedMemoryPercent: Double {
        safePercent(memoryPercent)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                JuicerFeatureHeader(
                    title: "CPU & Memory Monitor",
                    subtitle: "Real-time processor load, memory pressure, swap, and load averages.",
                    icon: "waveform.path.ecg",
                    refreshing: manager.isRefreshing,
                    action: manager.refresh
                )

                HStack(spacing: 12) {
                    JuicerMetricTile(
                        title: "CPU Usage",
                        value: SystemMetricsSupport.percent(clampedCPUPercent),
                        detail: "\(ProcessInfo.processInfo.processorCount) logical cores",
                        color: clampedCPUPercent > 85 ? .red : .blue
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("CPU Usage")
                    .accessibilityValue("\(SystemMetricsSupport.percent(clampedCPUPercent)), \(ProcessInfo.processInfo.processorCount) logical cores")

                    JuicerMetricTile(
                        title: "Memory Used",
                        value: SystemMetricsSupport.percent(clampedMemoryPercent),
                        detail: "\(SystemMetricsSupport.formatBytes(manager.memoryUsedBytes)) of \(SystemMetricsSupport.formatBytes(manager.memoryTotalBytes))",
                        color: .purple
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Memory Used")
                    .accessibilityValue("\(SystemMetricsSupport.percent(clampedMemoryPercent)), \(SystemMetricsSupport.formatBytes(manager.memoryUsedBytes)) of \(SystemMetricsSupport.formatBytes(manager.memoryTotalBytes))")

                    JuicerMetricTile(
                        title: "Swap Used",
                        value: SystemMetricsSupport.formatBytes(manager.swapUsedBytes),
                        detail: "Pressure: \(manager.memoryPressure.capitalized)",
                        color: manager.memoryPressure == "critical" ? .red : .orange
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Swap Used")
                    .accessibilityValue("\(SystemMetricsSupport.formatBytes(manager.swapUsedBytes)), Memory pressure: \(manager.memoryPressure.capitalized)")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Current Load")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)

                    HStack {
                        Text("CPU").frame(width: 80, alignment: .leading)
                        JuicerUsageBar(value: clampedCPUPercent, color: .blue)
                        Text(SystemMetricsSupport.percent(clampedCPUPercent)).frame(width: 64, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Current CPU Load")
                    .accessibilityValue(SystemMetricsSupport.percent(clampedCPUPercent))

                    HStack(spacing: 20) {
                        Text("Load average (1 / 5 / 15 min)")
                        Spacer()
                        Text(manager.loadAverages.map { String(format: "%.2f", $0) }.joined(separator: "  /  "))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Load Average 1, 5, and 15 minutes")
                    .accessibilityValue(manager.loadAverages.map { String(format: "%.2f", $0) }.joined(separator: ", "))
                }
                .padding(16)
                .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent samples")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)

                    ForEach(manager.samples.suffix(12)) { sample in
                        let sampleCPU = safePercent(sample.cpuPercent)
                        let sampleMem = safePercent(sample.memoryPercent)
                        HStack(spacing: 10) {
                            Text(SystemMetricsSupport.time(sample.date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 76, alignment: .leading)
                            Text("CPU").font(.caption)
                            JuicerUsageBar(value: sampleCPU, color: .blue)
                            Text("MEM").font(.caption)
                            JuicerUsageBar(value: sampleMem, color: .purple)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Sample at \(SystemMetricsSupport.time(sample.date))")
                        .accessibilityValue("CPU \(SystemMetricsSupport.percent(sampleCPU)), Memory \(SystemMetricsSupport.percent(sampleMem))")
                    }

                    if manager.samples.isEmpty {
                        JuicerEmptyState(title: "Collecting metrics", detail: "The first sample will appear shortly.")
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Collecting metrics")
                            .accessibilityHint("The first sample will appear shortly.")
                    }
                }
            }
            .padding(24)
        }
        .onAppear { manager.start() }
        .onDisappear { manager.stop() }
    }
}
