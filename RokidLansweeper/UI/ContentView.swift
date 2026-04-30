import SwiftUI

struct ContentView: View {
    @StateObject private var settings = SettingsStore()
    @StateObject private var vm: LansweeperViewModel

    init() {
        let s = SettingsStore()
        _settings = StateObject(wrappedValue: s)
        _vm       = StateObject(wrappedValue: LansweeperViewModel(settings: s))
    }

    var body: some View {
        TabView {
            TicketListView()
                .tabItem { Label("Tickets", systemImage: "ticket") }

            GlassesPreviewView()
                .tabItem { Label("Glasses", systemImage: "eyeglasses") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .environmentObject(vm)
        .environmentObject(settings)
        .tint(.orange)
        .task { vm.startPolling() }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }
}
