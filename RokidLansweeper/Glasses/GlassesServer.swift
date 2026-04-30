import Foundation
import Network

/// Bidirectional TCP server on port 8097.
/// Glasses → Phone: "QUERY: ticket 123" / "QUERY: asset PC01" / "QUERY: critical" / plain text
/// Phone → Glasses: newline-delimited JSON packets
@MainActor
final class GlassesServer: ObservableObject {

    @Published var isRunning   = false
    @Published var clientCount = 0

    var onRemoteQuery: ((String) -> Void)?

    private var listener:    NWListener?
    private var connections: [ConnectionWrapper] = []
    private let port: NWEndpoint.Port = 8097
    private let queue = DispatchQueue(label: "LansweeperGlassesQ", qos: .userInitiated)

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        guard let l = try? NWListener(using: .tcp, on: port) else { return }
        listener = l
        l.newConnectionHandler = { [weak self] conn in
            Task { @MainActor [weak self] in self?.accept(conn) }
        }
        l.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in self?.isRunning = (state == .ready) }
        }
        l.start(queue: queue)
    }

    func stop() {
        listener?.cancel(); listener = nil
        connections.forEach { $0.cancel() }
        connections.removeAll()
        clientCount = 0; isRunning = false
    }

    // MARK: - Broadcast methods

    /// Push current help desk summary to glasses.
    func broadcastSummary(tickets: [HelpDeskTicket], format: GlassesFormat) {
        let active = tickets.filter { $0.status.isActive }
        let text: String
        switch format {
        case .minimal:
            let crit = active.filter { $0.priority == .critical }.count
            let high = active.filter { $0.priority == .high     }.count
            text = "🎫 \(active.count) active  🔴\(crit) crit  🟠\(high) high"

        case .summary:
            let crit = active.filter { $0.priority == .critical }.count
            let high = active.filter { $0.priority == .high     }.count
            let med  = active.filter { $0.priority == .medium   }.count
            let low  = active.filter { $0.priority == .low      }.count
            var lines = ["🎫 \(active.count) active  🔴\(crit) 🟠\(high) 🟡\(med) 🟢\(low)"]
            if let urgent = active.min(by: { $0.priority < $1.priority }) {
                lines.append("\(urgent.priority.icon) #\(urgent.caseNumber) \(urgent.subject)")
            }
            text = lines.joined(separator: "\n")

        case .detailed:
            if let urgent = active.min(by: { $0.priority < $1.priority }) {
                text = """
                \(urgent.priority.icon) #\(urgent.caseNumber) [\(urgent.status.shortLabel)]
                \(urgent.subject)
                👤 \(urgent.assignedTo ?? "Unassigned")
                """
            } else {
                text = "✅ No active tickets"
            }
        }
        broadcast(type: "helpdesk", text: text)
    }

    /// Alert glasses about a new or escalated ticket.
    func broadcastAlert(ticket: HelpDeskTicket, reason: String) {
        broadcast(type: "alert", text: "⚠️ [\(reason)] \(ticket.priority.icon) #\(ticket.caseNumber): \(ticket.subject)")
    }

    /// Push asset lookup result.
    func broadcastAssets(_ assets: [LansweeperAsset]) {
        if assets.isEmpty {
            broadcast(type: "asset", text: "No assets found")
        } else {
            let lines = assets.prefix(5).map { $0.compactLine }.joined(separator: "\n")
            broadcast(type: "asset", text: lines)
        }
    }

    /// Push a specific ticket detail.
    func broadcastTicket(_ ticket: HelpDeskTicket) {
        let overdue = ticket.isOverdue ? " ⚠️ OVERDUE" : ""
        let text = """
        \(ticket.priority.icon) #\(ticket.caseNumber) [\(ticket.status.shortLabel)]\(overdue)
        \(ticket.subject)
        👤 \(ticket.assignedTo ?? "Unassigned")  📅 \(ticket.updatedOn.formatted(date: .abbreviated, time: .omitted))
        """
        broadcast(type: "ticket", text: text)
    }

    func broadcastStatus(_ text: String) { broadcast(type: "status", text: text) }
    func broadcastError (_ text: String) { broadcast(type: "error",  text: "❌ \(text)") }

    // MARK: - Private

    private func accept(_ nwConn: NWConnection) {
        let w = ConnectionWrapper(connection: nwConn, queue: queue)
        w.onReceiveLine = { [weak self] line in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else { return }
                if let q = GlassesPacket.parseQuery(from: line) { self.onRemoteQuery?(q) }
            }
        }
        w.onDisconnect = { [weak self] in
            Task { @MainActor [weak self] in
                self?.connections.removeAll { $0 === w }
                self?.clientCount = self?.connections.count ?? 0
            }
        }
        connections.append(w)
        clientCount = connections.count
        w.start()
    }

    private func broadcast(type: String, text: String) {
        let packet = GlassesPacket.make(type: type, text: text)
        connections.forEach { $0.send(packet) }
    }
}

// MARK: - Connection wrapper

private final class ConnectionWrapper {
    let connection: NWConnection
    var onReceiveLine: ((String) -> Void)?
    var onDisconnect:  (() -> Void)?
    private let queue: DispatchQueue
    private var buffer = Data()

    init(connection: NWConnection, queue: DispatchQueue) {
        self.connection = connection; self.queue = queue
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            if case .failed = state { self?.onDisconnect?() }
            if case .cancelled = state { self?.onDisconnect?() }
        }
        connection.start(queue: queue)
        receiveNext()
    }

    func send(_ data: Data) { connection.send(content: data, completion: .contentProcessed { _ in }) }
    func cancel() { connection.cancel() }

    private func receiveNext() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, done, err in
            guard let self else { return }
            if let d = data, !d.isEmpty { self.buffer.append(d); self.flush() }
            if done || err != nil { self.onDisconnect?() } else { self.receiveNext() }
        }
    }

    private func flush() {
        while let idx = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<idx]
            buffer.removeSubrange(buffer.startIndex...idx)
            if let s = String(data: line, encoding: .utf8) { onReceiveLine?(s) }
        }
    }
}
