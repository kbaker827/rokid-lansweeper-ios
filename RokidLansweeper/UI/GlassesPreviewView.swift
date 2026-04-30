import SwiftUI

struct GlassesPreviewView: View {
    @EnvironmentObject private var vm: LansweeperViewModel
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    glassesMockup
                    commandCard
                    formatCard
                    connectionCard
                }
                .padding()
            }
            .navigationTitle("Glasses Preview")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Glasses mockup

    private var glassesMockup: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black)
                    .aspectRatio(16/4, contentMode: .fit)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15), lineWidth: 1))

                VStack(alignment: .leading, spacing: 5) {
                    ForEach(previewLines, id: \.self) { line in
                        Text(line)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Color(red: 1.0, green: 0.65, blue: 0.0))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(12)
            }
            .padding(.horizontal)

            Text("Rokid AR Glasses · TCP :8097")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var previewLines: [String] {
        guard settings.isConfigured else {
            return ["Configure Lansweeper in Settings"]
        }
        if vm.tickets.isEmpty {
            return ["🎫 Waiting for ticket data…"]
        }
        let active = vm.tickets.filter { $0.status.isActive }
        let crit = active.filter { $0.priority == .critical }.count
        let high = active.filter { $0.priority == .high }.count
        let med  = active.filter { $0.priority == .medium }.count
        let low  = active.filter { $0.priority == .low }.count

        var lines = ["🎫 \(active.count) active  🔴\(crit) 🟠\(high) 🟡\(med) 🟢\(low)"]
        if let urgent = active.min(by: { $0.priority < $1.priority }) {
            lines.append("\(urgent.priority.icon) #\(urgent.caseNumber) \(urgent.subject)")
        }
        if vm.overdueCount > 0 {
            lines.append("⏰ \(vm.overdueCount) overdue")
        }
        return lines
    }

    // MARK: - Command card

    private var commandCard: some View {
        GroupBox("Glasses → Phone Commands") {
            VStack(alignment: .leading, spacing: 8) {
                commandRow(cmd: "QUERY: ticket 123",   desc: "Look up ticket #123")
                commandRow(cmd: "QUERY: asset PC01",    desc: "Search assets by name")
                commandRow(cmd: "QUERY: critical",      desc: "Show critical tickets")
                commandRow(cmd: "QUERY: high",          desc: "Show high priority tickets")
                commandRow(cmd: "QUERY: overdue",       desc: "Show overdue tickets")
                commandRow(cmd: "QUERY: unassigned",    desc: "Show unassigned tickets")
                commandRow(cmd: "QUERY: summary",       desc: "Push current summary")
                commandRow(cmd: "QUERY: refresh",       desc: "Reload from Lansweeper API")

                Divider().padding(.vertical, 4)
                Text("Plain text lines are also accepted — they trigger a summary push.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func commandRow(cmd: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(cmd)
                .font(.system(.caption2, design: .monospaced))
                .padding(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 6))
            Text(desc).font(.caption2).foregroundStyle(.secondary).padding(.leading, 6)
        }
    }

    // MARK: - Packet types card

    private var formatCard: some View {
        GroupBox("Phone → Glasses Packet Types") {
            VStack(alignment: .leading, spacing: 6) {
                packetRow(type: "helpdesk", example: "🎫 3 active  🔴1 🟠1 🟡1 🟢0")
                packetRow(type: "alert",    example: "⚠️ [NEW CRITICAL] 🔴 #42: Server down")
                packetRow(type: "ticket",   example: "🔴 #42 [OPEN]\\nServer down\\n👤 John Doe")
                packetRow(type: "asset",    example: "PC01 · 192.168.1.10 · Windows 11")
                packetRow(type: "status",   example: "🔍 Looking up #123…")
                packetRow(type: "error",    example: "❌ Invalid token")
            }
        }
    }

    private func packetRow(type: String, example: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("{\"type\":\"\(type)\",\"text\":\"...\"}")
                .font(.system(.caption2, design: .monospaced))
            Text(example)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, 8)
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Connection card

    private var connectionCard: some View {
        GroupBox("Connection") {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("TCP Server", systemImage: "antenna.radiowaves.left.and.right")
                    Spacer()
                    Text(vm.glassesServer.isRunning ? "Running" : "Stopped")
                        .foregroundStyle(vm.glassesServer.isRunning ? .green : .red)
                        .font(.subheadline.weight(.medium))
                }
                HStack {
                    Label("Port", systemImage: "network")
                    Spacer()
                    Text("8097").foregroundStyle(.secondary)
                }
                HStack {
                    Label("Clients", systemImage: "display.2")
                    Spacer()
                    Text("\(vm.glassesServer.clientCount)").foregroundStyle(.secondary)
                }
                HStack {
                    Label("Site", systemImage: "building.2")
                    Spacer()
                    Text(settings.siteName.isEmpty ? "Not set" : settings.siteName)
                        .foregroundStyle(.secondary)
                }
                if let refresh = vm.lastRefresh {
                    HStack {
                        Label("Last refresh", systemImage: "clock")
                        Spacer()
                        Text(refresh.formatted(date: .omitted, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .font(.subheadline)
        }
    }
}
