import Foundation
import Combine

final class SettingsStore: ObservableObject {

    // MARK: - API credentials
    @Published var personalAccessToken: String {
        didSet { UserDefaults.standard.set(personalAccessToken, forKey: "ls_pat") }
    }

    // MARK: - Site
    @Published var siteId: String {
        didSet { UserDefaults.standard.set(siteId, forKey: "ls_site_id") }
    }
    @Published var siteName: String {
        didSet { UserDefaults.standard.set(siteName, forKey: "ls_site_name") }
    }

    // MARK: - Assignee filter (for "my tickets")
    @Published var myEmail: String {
        didSet { UserDefaults.standard.set(myEmail, forKey: "ls_my_email") }
    }

    // MARK: - Polling
    @Published var pollInterval: Int {
        didSet { UserDefaults.standard.set(pollInterval, forKey: "ls_poll_interval") }
    }

    // MARK: - Ticket filters
    @Published var ticketFilter: TicketFilter {
        didSet { UserDefaults.standard.set(ticketFilter.rawValue, forKey: "ls_ticket_filter") }
    }
    @Published var showResolved: Bool {
        didSet { UserDefaults.standard.set(showResolved, forKey: "ls_show_resolved") }
    }

    // MARK: - Alerts
    @Published var alertNewCritical: Bool {
        didSet { UserDefaults.standard.set(alertNewCritical, forKey: "ls_alert_critical") }
    }
    @Published var alertNewHigh: Bool {
        didSet { UserDefaults.standard.set(alertNewHigh, forKey: "ls_alert_high") }
    }
    @Published var alertNewAny: Bool {
        didSet { UserDefaults.standard.set(alertNewAny, forKey: "ls_alert_any") }
    }
    @Published var alertOverdue: Bool {
        didSet { UserDefaults.standard.set(alertOverdue, forKey: "ls_alert_overdue") }
    }

    // MARK: - Glasses
    @Published var glassesFormat: GlassesFormat {
        didSet { UserDefaults.standard.set(glassesFormat.rawValue, forKey: "ls_glasses_format") }
    }
    @Published var glassesQueryEnabled: Bool {
        didSet { UserDefaults.standard.set(glassesQueryEnabled, forKey: "ls_glasses_query") }
    }

    // MARK: - Init
    init() {
        let ud = UserDefaults.standard
        personalAccessToken = ud.string(forKey: "ls_pat")            ?? ""
        siteId              = ud.string(forKey: "ls_site_id")         ?? ""
        siteName            = ud.string(forKey: "ls_site_name")       ?? ""
        myEmail             = ud.string(forKey: "ls_my_email")        ?? ""
        pollInterval        = ud.integer(forKey: "ls_poll_interval").nonZero ?? 60
        ticketFilter        = TicketFilter(rawValue: ud.string(forKey: "ls_ticket_filter") ?? "") ?? .allActive
        showResolved        = ud.object(forKey: "ls_show_resolved")   as? Bool ?? false
        alertNewCritical    = ud.object(forKey: "ls_alert_critical")  as? Bool ?? true
        alertNewHigh        = ud.object(forKey: "ls_alert_high")      as? Bool ?? true
        alertNewAny         = ud.object(forKey: "ls_alert_any")       as? Bool ?? false
        alertOverdue        = ud.object(forKey: "ls_alert_overdue")   as? Bool ?? true
        glassesFormat       = GlassesFormat(rawValue: ud.string(forKey: "ls_glasses_format") ?? "") ?? .summary
        glassesQueryEnabled = ud.object(forKey: "ls_glasses_query")   as? Bool ?? true
    }

    var isConfigured: Bool { !personalAccessToken.isEmpty && !siteId.isEmpty }
}

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
