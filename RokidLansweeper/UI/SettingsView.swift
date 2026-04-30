import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var vm: LansweeperViewModel
    @EnvironmentObject private var settings: SettingsStore
    @State private var showPAT = false
    @State private var loadingSites = false

    var body: some View {
        NavigationStack {
            Form {

                // MARK: API credentials
                Section("Lansweeper API") {
                    LabeledContent("Personal Access Token") {
                        if showPAT {
                            TextField("Paste token…", text: $settings.personalAccessToken)
                                .multilineTextAlignment(.trailing)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        } else {
                            Text(settings.personalAccessToken.isEmpty ? "Not set" : "••••••••")
                                .foregroundStyle(settings.personalAccessToken.isEmpty ? .red : .secondary)
                        }
                    }
                    .onTapGesture { showPAT.toggle() }

                    Link("Create a PAT at app.lansweeper.com",
                         destination: URL(string: "https://app.lansweeper.com/")!)
                        .font(.footnote)
                }

                // MARK: Site
                Section("Site") {
                    if vm.sites.isEmpty {
                        Button {
                            loadingSites = true
                            Task {
                                await vm.loadSites()
                                loadingSites = false
                            }
                        } label: {
                            HStack {
                                Text("Load sites from API")
                                Spacer()
                                if loadingSites { ProgressView().scaleEffect(0.8) }
                            }
                        }
                        .disabled(settings.personalAccessToken.isEmpty || loadingSites)
                    } else {
                        ForEach(vm.sites) { site in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(site.name).font(.subheadline)
                                    Text(site.id).font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if settings.siteId == site.id {
                                    Image(systemName: "checkmark").foregroundStyle(.orange)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                settings.siteId   = site.id
                                settings.siteName = site.name
                            }
                        }

                        Button("Reload sites") {
                            loadingSites = true
                            Task { await vm.loadSites(); loadingSites = false }
                        }
                        .font(.footnote)
                    }

                    if !settings.siteId.isEmpty {
                        LabeledContent("Selected site", value: settings.siteName.isEmpty ? settings.siteId : settings.siteName)
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: My tickets
                Section("My Tickets") {
                    TextField("Your email address", text: $settings.myEmail)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    Text("Used to filter the 'Assigned to Me' view.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // MARK: Ticket filter
                Section("Default Filter") {
                    Picker("Show tickets", selection: $settings.ticketFilter) {
                        ForEach(TicketFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    Toggle("Include resolved/closed", isOn: $settings.showResolved)
                }

                // MARK: Polling
                Section("Polling") {
                    HStack {
                        Text("Refresh every")
                        Spacer()
                        Text("\(settings.pollInterval)s").foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(settings.pollInterval) },
                        set: { settings.pollInterval = Int($0) }
                    ), in: 30...300, step: 30) {
                        Text("Interval")
                    } minimumValueLabel: { Text("30s").font(.caption) }
                      maximumValueLabel: { Text("5m").font(.caption)  }
                }

                // MARK: Alerts
                Section("Glasses Alerts") {
                    Toggle("New critical tickets",  isOn: $settings.alertNewCritical)
                    Toggle("New high tickets",      isOn: $settings.alertNewHigh)
                    Toggle("Any new ticket",        isOn: $settings.alertNewAny)
                    Toggle("Overdue tickets",       isOn: $settings.alertOverdue)
                }

                // MARK: Glasses
                Section("Glasses Integration") {
                    Toggle("Accept queries from glasses", isOn: $settings.glassesQueryEnabled)

                    Picker("Display format", selection: $settings.glassesFormat) {
                        ForEach(GlassesFormat.allCases) { fmt in
                            VStack(alignment: .leading) {
                                Text(fmt.displayName)
                                Text(fmt.description).font(.caption).foregroundStyle(.secondary)
                            }
                            .tag(fmt)
                        }
                    }

                    LabeledContent("TCP port", value: "8097").foregroundStyle(.secondary)
                }

                // MARK: About
                Section("About") {
                    LabeledContent("App",     value: "Rokid Lansweeper HUD")
                    LabeledContent("Version", value: "1.0")
                    LabeledContent("API",     value: "GraphQL v2")
                    Link("Lansweeper API docs",
                         destination: URL(string: "https://docs.lansweeper.com/docs/api/getting-started")!)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
