import SwiftUI

struct TicketListView: View {
    @EnvironmentObject private var vm: LansweeperViewModel
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        NavigationStack {
            Group {
                if !settings.isConfigured {
                    unconfiguredView
                } else {
                    ticketContent
                }
            }
            .navigationTitle("Help Desk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    serverDot
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
            }
        }
    }

    // MARK: - Not configured

    private var unconfiguredView: some View {
        VStack(spacing: 20) {
            Image(systemName: "server.rack")
                .font(.system(size: 52))
                .foregroundStyle(.orange)
            Text("Lansweeper Not Configured")
                .font(.title2.weight(.semibold))
            Text("Go to Settings and enter your Personal Access Token and Site ID.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
    }

    // MARK: - Main content

    private var ticketContent: some View {
        VStack(spacing: 0) {
            summaryBanner
            Divider()

            if vm.isLoading && vm.tickets.isEmpty {
                ProgressView("Loading tickets…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ticketList
            }
        }
    }

    // MARK: - Summary banner

    private var summaryBanner: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                statChip(icon: "🔴", count: vm.activeCritical, label: "Critical", color: .red)
                statChip(icon: "🟠", count: vm.activeHigh,     label: "High",     color: .orange)
                statChip(icon: "🟡", count: vm.activeMedium,   label: "Medium",   color: .yellow)
                statChip(icon: "🟢", count: vm.activeLow,      label: "Low",      color: .green)
                if vm.overdueCount > 0 {
                    statChip(icon: "⏰", count: vm.overdueCount, label: "Overdue", color: .red)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(Color(.secondarySystemBackground))
    }

    private func statChip(icon: String, count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Text(icon)
                Text("\(count)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(count > 0 ? color : .secondary)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Ticket list

    private var ticketList: some View {
        List {
            if vm.filteredTickets.isEmpty {
                ContentUnavailableView(
                    "No Tickets",
                    systemImage: "checkmark.circle",
                    description: Text("No tickets match the current filter.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(vm.filteredTickets) { ticket in
                    TicketRow(ticket: ticket)
                }
            }

            if let refresh = vm.lastRefresh {
                Section {
                    Text("Last updated \(refresh.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .listRowBackground(Color.clear)
            }
        }
        .searchable(text: $vm.searchQuery, prompt: "Search tickets…")
        .refreshable { await vm.refresh() }
    }

    // MARK: - Toolbar items

    private var serverDot: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(vm.glassesServer.isRunning ? .green : .red)
                .frame(width: 8, height: 8)
            Text(":8097")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var refreshButton: some View {
        Button {
            Task { await vm.refresh() }
        } label: {
            if vm.isLoading {
                ProgressView().scaleEffect(0.8)
            } else {
                Image(systemName: "arrow.clockwise")
            }
        }
        .disabled(vm.isLoading)
    }
}

// MARK: - Ticket row

struct TicketRow: View {
    let ticket: HelpDeskTicket
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Text(ticket.priority.icon)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("#\(ticket.caseNumber)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        StatusBadge(status: ticket.status)
                    }
                    Text(ticket.subject)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(expanded ? nil : 2)
                }
            }

            if expanded {
                VStack(alignment: .leading, spacing: 4) {
                    if !ticket.description.isEmpty {
                        Text(ticket.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(5)
                    }
                    HStack {
                        Label(ticket.assignedTo ?? "Unassigned", systemImage: "person")
                        Spacer()
                        if ticket.isOverdue {
                            Label("Overdue", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                        } else if let due = ticket.dueDate {
                            Label(due.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Label("Updated \(ticket.updatedOn.formatted(date: .abbreviated, time: .shortened))", systemImage: "clock")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.leading, 30)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } }
        .padding(.vertical, 4)
        .listRowBackground(
            ticket.priority == .critical && ticket.status.isActive
                ? Color.red.opacity(0.06)
                : Color.clear
        )
    }
}

// MARK: - Status badge

struct StatusBadge: View {
    let status: TicketStatus

    var color: Color {
        switch status {
        case .open:       return .blue
        case .assigned:   return .purple
        case .inProgress: return .orange
        case .pending:    return .yellow
        case .resolved:   return .green
        case .closed:     return .gray
        case .unknown:    return .gray
        }
    }

    var body: some View {
        Text(status.shortLabel)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}
