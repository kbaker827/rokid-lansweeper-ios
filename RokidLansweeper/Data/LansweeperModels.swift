import Foundation

// MARK: - Help Desk Ticket

struct HelpDeskTicket: Identifiable, Equatable {
    let id: String
    let caseNumber: Int
    let subject: String
    let description: String
    let status: TicketStatus
    let priority: TicketPriority
    let assignedTo: String?
    let requester: String?
    let createdOn: Date
    let updatedOn: Date
    let dueDate: Date?

    var isOverdue: Bool {
        guard let due = dueDate else { return false }
        return due < Date() && status != .resolved && status != .closed
    }

    var compactLine: String {
        let pIcon = priority.icon
        let sLabel = status.shortLabel
        return "\(pIcon) #\(caseNumber) [\(sLabel)] \(subject)"
    }
}

enum TicketStatus: String, CaseIterable {
    case open       = "Open"
    case assigned   = "Assigned"
    case inProgress = "In Progress"
    case pending    = "Pending"
    case resolved   = "Resolved"
    case closed     = "Closed"
    case unknown    = "Unknown"

    var shortLabel: String {
        switch self {
        case .open:       return "OPEN"
        case .assigned:   return "ASGN"
        case .inProgress: return "WIP"
        case .pending:    return "PEND"
        case .resolved:   return "DONE"
        case .closed:     return "CLSD"
        case .unknown:    return "???"
        }
    }

    var isActive: Bool {
        switch self {
        case .open, .assigned, .inProgress, .pending: return true
        default: return false
        }
    }

    static func from(_ raw: String) -> TicketStatus {
        return allCases.first { $0.rawValue.lowercased() == raw.lowercased() } ?? .unknown
    }
}

enum TicketPriority: Int, CaseIterable, Comparable {
    case critical = 1
    case high     = 2
    case medium   = 3
    case low      = 4
    case unknown  = 99

    var displayName: String {
        switch self {
        case .critical: return "Critical"
        case .high:     return "High"
        case .medium:   return "Medium"
        case .low:      return "Low"
        case .unknown:  return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .critical: return "🔴"
        case .high:     return "🟠"
        case .medium:   return "🟡"
        case .low:      return "🟢"
        case .unknown:  return "⚪️"
        }
    }

    static func < (lhs: TicketPriority, rhs: TicketPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func from(_ raw: String) -> TicketPriority {
        switch raw.lowercased() {
        case "critical", "1": return .critical
        case "high", "2":     return .high
        case "medium", "3":   return .medium
        case "low", "4":      return .low
        default:              return .unknown
        }
    }
}

// MARK: - Asset

struct LansweeperAsset: Identifiable, Equatable {
    let id: String
    let name: String
    let ipAddress: String?
    let type: String?
    let domain: String?
    let stateName: String?
    let operatingSystem: String?

    var compactLine: String {
        var parts: [String] = [name]
        if let ip = ipAddress { parts.append(ip) }
        if let os = operatingSystem { parts.append(os) }
        if let state = stateName { parts.append("[\(state)]") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Site

struct LansweeperSite: Identifiable, Equatable {
    let id: String
    let name: String
}

// MARK: - GraphQL helpers

struct GraphQLRequest: Encodable {
    let query: String
    let variables: [String: GraphQLVariable]?
}

enum GraphQLVariable: Encodable {
    case string(String)
    case int(Int)
    case bool(Bool)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v):    try container.encode(v)
        case .bool(let v):   try container.encode(v)
        }
    }
}

// MARK: - Glasses display format

enum GlassesFormat: String, CaseIterable, Identifiable {
    case summary  = "summary"
    case detailed = "detailed"
    case minimal  = "minimal"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .summary:  return "Summary"
        case .detailed: return "Detailed"
        case .minimal:  return "Minimal"
        }
    }

    var description: String {
        switch self {
        case .summary:  return "Priority counts + top urgent ticket"
        case .detailed: return "Full ticket details per update"
        case .minimal:  return "Counts only (Critical/High)"
        }
    }
}

// MARK: - Ticket filter

enum TicketFilter: String, CaseIterable, Identifiable {
    case allActive  = "All Active"
    case myTickets  = "Assigned to Me"
    case critical   = "Critical Only"
    case unassigned = "Unassigned"

    var id: String { rawValue }
}

// MARK: - Glasses wire packets

struct GlassesPacket {
    static func make(type: String, text: String) -> Data {
        let dict: [String: String] = ["type": type, "text": text]
        let data = (try? JSONSerialization.data(withJSONObject: dict)) ?? Data()
        return data + Data([0x0A])
    }

    static func parseQuery(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.uppercased().hasPrefix("QUERY:") {
            let q = trimmed.dropFirst("QUERY:".count).trimmingCharacters(in: .whitespaces)
            return q.isEmpty ? nil : q
        }
        return trimmed
    }
}
