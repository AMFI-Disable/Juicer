import SwiftUI

struct MemoryPressureOptimizerView: View {
    @StateObject private var monitor = CPUMemoryMonitorManager()
    @StateObject private var purge = MemoryPurgeManager()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                JuicerFeatureHeader(title: "Memory Pressure Optimizer", subtitle: "Review memory pressure, then reclaim inactive memory when it is safe to do so.", icon: "memorychip", refreshing: monitor.isRefreshing || purge.purging, action: monitor.refresh)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                    JuicerMetricTile(title: "Pressure", value: monitor.memoryPressure.capitalized, detail: "reported by macOS", color: monitor.memoryPressure == "critical" ? .red : .green)
                    JuicerMetricTile(title: "Used", value: SystemMetricsSupport.bytes(monitor.memoryUsedBytes), detail: "of (SystemMetricsSupport.bytes(monitor.memoryTotalBytes))", color: .blue)
                    JuicerMetricTile(title: "Purgeable", value: SystemMetricsSupport.bytes(purge.reading.purgeable), detail: "estimated reclaimable memory", color: .orange)
                }
                JuicerFeatureList(title: "Recommended action") {
                    Text(monitor.memoryPressure == "critical" ? "Close demanding applications before purging memory." : "Purge is optional. macOS normally manages inactive memory automatically.")
                        .foregroundStyle(.secondary)
                    Button("Purge Inactive Memory") { purge.purge() }
                        .buttonStyle(.borderedProminent)
                        .disabled(purge.purging)
                }
            }
            .padding(24)
        }
        .onAppear { monitor.start(); purge.refresh() }
        .onDisappear { monitor.stop() }
    }
}
