import SwiftUI

struct dnsmanagerview: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("DNS Tool", selection: $selectedTab) {
                Text("DNS Editor").tag(0)
                Text("DNS Diagnostics").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            if selectedTab == 0 {
                dnseditorview()
            } else {
                dnsdiagnosticsview()
            }
        }
    }
}
