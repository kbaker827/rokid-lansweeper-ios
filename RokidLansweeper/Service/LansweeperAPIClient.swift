import Foundation

actor LansweeperAPIClient {

    private let graphQLURL = URL(string: "https://api.lansweeper.com/api/v2/graphql")!

    // MARK: - Sites

    func fetchSites(token: String) async throws -> [LansweeperSite] {
        let query = """
        query GetSites {
          me {
            sites {
              id
              name
            }
          }
        }
        """
        let response: [String: Any] = try await graphQL(query: query, variables: nil, token: token)
        guard let data = response["data"] as? [String: Any],
              let me   = data["me"]       as? [String: Any],
              let sites = me["sites"]     as? [[String: Any]]
        else { throw LansweeperError.parseError("sites") }

        return sites.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let name = dict["name"] as? String else { return nil }
            return LansweeperSite(id: id, name: name)
        }
    }

    // MARK: - Tickets

    func fetchTickets(
        token: String,
        siteId: String,
        statuses: [String] = ["Open", "Assigned", "In Progress", "Pending"],
        limit: Int = 50
    ) async throws -> [HelpDeskTicket] {
        let query = """
        query GetTickets($siteId: ID!, $limit: Int) {
          site(id: $siteId) {
            helpDeskCases(
              pagination: { limit: $limit, page: 1 }
              sorting: { key: updatedOn, order: desc }
            ) {
              total
              items {
                id
                caseNumber
                subject
                description
                status
                priority
                assignedTo { name email }
                requester { name email }
                createdOn
                updatedOn
                dueDate
              }
            }
          }
        }
        """
        let variables: [String: GraphQLVariable] = [
            "siteId": .string(siteId),
            "limit":  .int(limit)
        ]
        let response: [String: Any] = try await graphQL(query: query, variables: variables, token: token)

        guard let data     = response["data"]                         as? [String: Any],
              let site     = data["site"]                             as? [String: Any],
              let hdc      = site["helpDeskCases"]                   as? [String: Any],
              let items    = hdc["items"]                             as? [[String: Any]]
        else { throw LansweeperError.parseError("tickets") }

        return items.compactMap { parseTicket($0) }.filter { ticket in
            statuses.isEmpty || statuses.contains(ticket.status.rawValue)
        }
    }

    func fetchTicket(token: String, siteId: String, caseNumber: Int) async throws -> HelpDeskTicket? {
        let query = """
        query GetTicket($siteId: ID!, $caseNumber: Int!) {
          site(id: $siteId) {
            helpDeskCase(caseNumber: $caseNumber) {
              id
              caseNumber
              subject
              description
              status
              priority
              assignedTo { name email }
              requester { name email }
              createdOn
              updatedOn
              dueDate
            }
          }
        }
        """
        let variables: [String: GraphQLVariable] = [
            "siteId":     .string(siteId),
            "caseNumber": .int(caseNumber)
        ]
        let response: [String: Any] = try await graphQL(query: query, variables: variables, token: token)

        guard let data = response["data"] as? [String: Any],
              let site = data["site"]     as? [String: Any],
              let item = site["helpDeskCase"] as? [String: Any]
        else { return nil }

        return parseTicket(item)
    }

    // MARK: - Assets

    func fetchAssets(
        token: String,
        siteId: String,
        searchName: String? = nil,
        limit: Int = 20
    ) async throws -> [LansweeperAsset] {
        let filterClause = searchName.map {
            "filters: { assetBasicInfo: { name: { op: contains, value: \"\($0)\" } } }"
        } ?? ""

        let query = """
        query GetAssets($siteId: ID!) {
          site(id: $siteId) {
            assetResources(
              pagination: { limit: \(limit), page: 1 }
              \(filterClause)
            ) {
              total
              items {
                key
                assetBasicInfo {
                  name
                  ipAddress
                  type
                  domain
                }
                assetCustom {
                  stateName
                }
                operatingSystem {
                  caption
                }
              }
            }
          }
        }
        """
        let variables: [String: GraphQLVariable] = ["siteId": .string(siteId)]
        let response: [String: Any] = try await graphQL(query: query, variables: variables, token: token)

        guard let data    = response["data"]                       as? [String: Any],
              let site    = data["site"]                           as? [String: Any],
              let assets  = site["assetResources"]                as? [String: Any],
              let items   = assets["items"]                        as? [[String: Any]]
        else { throw LansweeperError.parseError("assets") }

        return items.compactMap { parseAsset($0) }
    }

    // MARK: - GraphQL executor

    private func graphQL(
        query: String,
        variables: [String: GraphQLVariable]?,
        token: String
    ) async throws -> [String: Any] {
        guard !token.isEmpty else { throw LansweeperError.missingToken }

        var request = URLRequest(url: graphQLURL)
        request.httpMethod = "POST"
        request.setValue("application/json",    forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)",     forHTTPHeaderField: "Authorization")

        var body: [String: Any] = ["query": query]
        if let vars = variables {
            var encoded: [String: Any] = [:]
            let encoder = JSONEncoder()
            for (k, v) in vars {
                if let data = try? encoder.encode(v),
                   let obj = try? JSONSerialization.jsonObject(with: data) {
                    encoded[k] = obj
                }
            }
            body["variables"] = encoded
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            if http.statusCode == 401 { throw LansweeperError.unauthorized }
            throw LansweeperError.httpError(http.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LansweeperError.parseError("JSON root")
        }

        // Surface GraphQL-level errors
        if let errors = json["errors"] as? [[String: Any]],
           let first  = errors.first,
           let msg    = first["message"] as? String {
            throw LansweeperError.graphQLError(msg)
        }

        return json
    }

    // MARK: - Parsers

    private func parseTicket(_ dict: [String: Any]) -> HelpDeskTicket? {
        guard let id         = dict["id"]         as? String,
              let caseNumber = dict["caseNumber"] as? Int,
              let subject    = dict["subject"]    as? String
        else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        func parseDate(_ key: String) -> Date? {
            guard let s = dict[key] as? String else { return nil }
            return iso.date(from: s) ?? ISO8601DateFormatter().date(from: s)
        }

        let statusRaw    = dict["status"]   as? String ?? "Unknown"
        let priorityRaw  = dict["priority"] as? String ?? "Unknown"
        let assignedDict = dict["assignedTo"] as? [String: Any]
        let requesterDict = dict["requester"] as? [String: Any]

        return HelpDeskTicket(
            id:          id,
            caseNumber:  caseNumber,
            subject:     subject,
            description: dict["description"] as? String ?? "",
            status:      TicketStatus.from(statusRaw),
            priority:    TicketPriority.from(priorityRaw),
            assignedTo:  assignedDict?["name"] as? String,
            requester:   requesterDict?["name"] as? String,
            createdOn:   parseDate("createdOn") ?? Date(),
            updatedOn:   parseDate("updatedOn") ?? Date(),
            dueDate:     parseDate("dueDate")
        )
    }

    private func parseAsset(_ dict: [String: Any]) -> LansweeperAsset? {
        guard let key  = dict["key"] as? String else { return nil }
        let basic = dict["assetBasicInfo"] as? [String: Any]
        let custom = dict["assetCustom"]   as? [String: Any]
        let os     = dict["operatingSystem"] as? [String: Any]

        guard let name = basic?["name"] as? String else { return nil }

        return LansweeperAsset(
            id:              key,
            name:            name,
            ipAddress:       basic?["ipAddress"]  as? String,
            type:            basic?["type"]        as? String,
            domain:          basic?["domain"]      as? String,
            stateName:       custom?["stateName"]  as? String,
            operatingSystem: os?["caption"]        as? String
        )
    }
}

// MARK: - Errors

enum LansweeperError: LocalizedError {
    case missingToken
    case unauthorized
    case httpError(Int)
    case parseError(String)
    case graphQLError(String)
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .missingToken:          return "Personal Access Token is not set. Go to Settings."
        case .unauthorized:          return "Invalid token (401). Check your PAT in Settings."
        case .httpError(let code):   return "HTTP error \(code) from Lansweeper API."
        case .parseError(let what):  return "Could not parse \(what) from Lansweeper response."
        case .graphQLError(let msg): return "Lansweeper API error: \(msg)"
        case .notConfigured:         return "Please set your API token and Site ID in Settings."
        }
    }
}
