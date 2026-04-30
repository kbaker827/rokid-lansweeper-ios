import Foundation
import Combine

@MainActor
final class LansweeperViewModel: ObservableObject {

    // MARK: - Published state
    @Published var tickets:      [HelpDeskTicket] = []
    @Published var sites:        [LansweeperSite] = []
    @Published var isLoading:    Bool = false
    @Published var errorMessage: String? = nil
    @Published var lastRefresh:  Date? = nil
    @Published var searchQuery:  String = ""
    @Published var selectedFilter: TicketFilter = .allActive

    // MARK: - Sub-objects
    let glassesServer = GlassesServer()

    // MARK: - Private
    private let api = LansweeperAPIClient()
    private var pollTask: Task<Void, Never>?
    private var prevTicketIds: Set<String> = []
    private var prevOverdueIds: Set<String> = []

    var settings: SettingsStore

    // MARK: - Init

    init(settings: SettingsStore) {
        self.settings = settings
        selectedFilter = settings.ticketFilter

        glassesServer.onRemoteQuery = { [weak self] query in
            Task { @MainActor [weak self] in
                guard let self, self.settings.glassesQueryEnabled else { return }
                await self.handleGlassesQuery(query)
            }
        }
        glassesServer.start()
    }

    // MARK: - Polling

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(settings.pollInterval))
            }
        }
    }

    func stopPolling() { pollTask?.cancel(); pollTask = nil }

    func refresh() async {
        guard settings.isConfigured else {
            errorMessage = "Configure your API token and site in Settings."
            return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            let statuses: [String]
            if settings.showResolved {
                statuses = [] // all
            } else {
                statuses = ["Open", "Assigned", "In Progress", "Pending"]
            }

            var fetched = try await api.fetchTickets(
                token:    settings.personalAccessToken,
                siteId:   settings.siteId,
                statuses: statuses,
                limit:    100
            )

            // Apply local filter
            fetched = applyFilter(fetched)

            checkAlerts(incoming: fetched)
            tickets      = fetched.sorted { $0.priority < $1.priority }
            lastRefresh  = Date()
            errorMessage = nil

            // Push to glasses
            glassesServer.broadcastSummary(tickets: tickets, format: settings.glassesFormat)

        } catch {
            errorMessage = error.localizedDescription
            glassesServer.broadcastError(error.localizedDescription)
        }
    }

    // MARK: - Alerts

    private func checkAlerts(incoming: [HelpDeskTicket]) {
        let incomingIds = Set(incoming.map { $0.id })

        // New tickets
        if !prevTicketIds.isEmpty {
            let newTickets = incoming.filter { !prevTicketIds.contains($0.id) }
            for ticket in newTickets {
                let shouldAlert: Bool
                switch ticket.priority {
                case .critical: shouldAlert = settings.alertNewCritical
                case .high:     shouldAlert = settings.alertNewHigh
                default:        shouldAlert = settings.alertNewAny
                }
                if shouldAlert {
                    glassesServer.broadcastAlert(ticket: ticket, reason: "NEW \(ticket.priority.displayName.uppercased())")
                }
            }
        }

        // Overdue tickets
        if settings.alertOverdue {
            let overdueIds = Set(incoming.filter { $0.isOverdue }.map { $0.id })
            let newOverdue = incoming.filter { $0.isOverdue && !prevOverdueIds.contains($0.id) }
            for ticket in newOverdue {
                glassesServer.broadcastAlert(ticket: ticket, reason: "OVERDUE")
            }
            prevOverdueIds = overdueIds
        }

        prevTicketIds = incomingIds
    }

    // MARK: - Site discovery

    func loadSites() async {
        guard !settings.personalAccessToken.isEmpty else { return }
        do {
            sites = try await api.fetchSites(token: settings.personalAccessToken)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Glasses query handler

    private func handleGlassesQuery(_ query: String) async {
        let lower = query.lowercased()

        // "ticket 123" or "#123"
        if lower.hasPrefix("ticket ") || lower.hasPrefix("#") {
            let numStr = lower.replacingOccurrences(of: "ticket ", with: "").replacingOccurrences(of: "#", with: "")
            if let caseNum = Int(numStr.trimmingCharacters(in: .whitespaces)) {
                await lookupTicket(caseNumber: caseNum)
                return
            }
        }

        // "asset <name>"
        if lower.hasPrefix("asset ") {
            let name = String(query.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            await lookupAsset(name: name)
            return
        }

        // Priority filters
        if lower.contains("critical") {
            let crit = tickets.filter { $0.priority == .critical && $0.status.isActive }
            if crit.isEmpty {
                glassesServer.broadcastStatus("✅ No critical tickets")
            } else {
                crit.prefix(3).forEach { glassesServer.broadcastTicket($0) }
            }
            return
        }
        if lower.contains("high") {
            let high = tickets.filter { $0.priority == .high && $0.status.isActive }
            if high.isEmpty {
                glassesServer.broadcastStatus("✅ No high priority tickets")
            } else {
                high.prefix(3).forEach { glassesServer.broadcastTicket($0) }
            }
            return
        }
        if lower.contains("overdue") {
            let od = tickets.filter { $0.isOverdue }
            if od.isEmpty {
                glassesServer.broadcastStatus("✅ No overdue tickets")
            } else {
                od.prefix(3).forEach { glassesServer.broadcastTicket($0) }
            }
            return
        }
        if lower.contains("unassigned") {
            let ua = tickets.filter { $0.assignedTo == nil && $0.status.isActive }
            glassesServer.broadcastStatus("👤 \(ua.count) unassigned active tickets")
            return
        }

        // "summary" or "status"
        if lower.contains("summary") || lower.contains("status") || lower.contains("count") {
            glassesServer.broadcastSummary(tickets: tickets, format: .summary)
            return
        }

        // "refresh"
        if lower.contains("refresh") || lower.contains("reload") {
            await refresh()
            return
        }

        // Default: show summary
        glassesServer.broadcastSummary(tickets: tickets, format: settings.glassesFormat)
    }

    private func lookupTicket(caseNumber: Int) async {
        glassesServer.broadcastStatus("🔍 Looking up #\(caseNumber)…")
        do {
            if let ticket = try await api.fetchTicket(
                token:      settings.personalAccessToken,
                siteId:     settings.siteId,
                caseNumber: caseNumber
            ) {
                glassesServer.broadcastTicket(ticket)
            } else {
                glassesServer.broadcastStatus("Ticket #\(caseNumber) not found")
            }
        } catch {
            glassesServer.broadcastError(error.localizedDescription)
        }
    }

    private func lookupAsset(name: String) async {
        glassesServer.broadcastStatus("🔍 Searching assets for '\(name)'…")
        do {
            let assets = try await api.fetchAssets(
                token:      settings.personalAccessToken,
                siteId:     settings.siteId,
                searchName: name,
                limit:      5
            )
            glassesServer.broadcastAssets(assets)
        } catch {
            glassesServer.broadcastError(error.localizedDescription)
        }
    }

    // MARK: - Filtered view

    var filteredTickets: [HelpDeskTicket] {
        var result = tickets
        if !searchQuery.isEmpty {
            result = result.filter {
                $0.subject.localizedCaseInsensitiveContains(searchQuery) ||
                "\($0.caseNumber)".contains(searchQuery) ||
                ($0.assignedTo?.localizedCaseInsensitiveContains(searchQuery) ?? false)
            }
        }
        return result
    }

    private func applyFilter(_ all: [HelpDeskTicket]) -> [HelpDeskTicket] {
        switch settings.ticketFilter {
        case .allActive:
            return all.filter { $0.status.isActive || settings.showResolved }
        case .myTickets:
            let email = settings.myEmail.lowercased()
            return all.filter { ($0.assignedTo ?? "").lowercased().contains(email) }
        case .critical:
            return all.filter { $0.priority == .critical }
        case .unassigned:
            return all.filter { $0.assignedTo == nil && $0.status.isActive }
        }
    }

    // MARK: - Summary stats

    var activeCritical: Int { tickets.filter { $0.priority == .critical && $0.status.isActive }.count }
    var activeHigh:     Int { tickets.filter { $0.priority == .high     && $0.status.isActive }.count }
    var activeMedium:   Int { tickets.filter { $0.priority == .medium   && $0.status.isActive }.count }
    var activeLow:      Int { tickets.filter { $0.priority == .low      && $0.status.isActive }.count }
    var overdueCount:   Int { tickets.filter { $0.isOverdue }.count }
    var activeTotal:    Int { tickets.filter { $0.status.isActive }.count }
}
