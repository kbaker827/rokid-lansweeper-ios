# Rokid Lansweeper HUD


> **🔵 Connectivity Update — May 2025**
> The glasses connection has been migrated from **raw TCP sockets** to
> **Bluetooth via the Rokid AI glasses SDK** (`pod 'RokidSDK' ~> 1.10.2`).
> No Wi-Fi port forwarding is needed. See **SDK Setup** below.

iOS app that bridges **Lansweeper Help Desk** with **Rokid AR glasses** — bidirectional ticket monitoring and asset lookup.

```
👓 Glasses query / 📱 iPhone monitor
         ↓
  iPhone (RokidLansweeper)
         ↓  GraphQL API
  api.lansweeper.com
         ↓  ticket & asset data
  iPhone ──Bluetooth/RokidSDK──▶ Rokid Glasses (live HUD)
```

## What appears on the glasses

```
🎫 12 active  🔴2 🟠4 🟡5 🟢1
🔴 #1042 [OPEN] Database server unreachable
⏰ 3 overdue
```

Alerts fire instantly on your glasses when:
- A new **Critical** or **High** ticket is opened
- A ticket becomes **overdue**

## Three display formats

| Format | Glasses output |
|--------|----------------|
| **Summary** | Active count by priority + top urgent ticket |
| **Detailed** | Full details of the most urgent open ticket |
| **Minimal** | Critical + High counts only |

## Glasses → Phone commands (TCP :8097)

Send any of these over TCP to trigger an instant response:

| Command | Result |
|---------|--------|
| `QUERY: ticket 123` | Look up ticket #123 by case number |
| `QUERY: asset PC01` | Search assets matching "PC01" |
| `QUERY: critical` | Show all critical open tickets |
| `QUERY: high` | Show all high priority tickets |
| `QUERY: overdue` | Show overdue tickets |
| `QUERY: unassigned` | Show unassigned active tickets |
| `QUERY: summary` | Push current summary to glasses |
| `QUERY: refresh` | Reload data from Lansweeper API |

Plain text lines are also accepted as queries.

## Phone → Glasses packet types

```json
{"type":"helpdesk", "text":"🎫 12 active  🔴2 🟠4 🟡5 🟢1"}
{"type":"alert",    "text":"⚠️ [NEW CRITICAL] 🔴 #1042: DB server down"}
{"type":"ticket",   "text":"🔴 #1042 [OPEN]\nDB server down\n👤 John Doe"}
{"type":"asset",    "text":"PC01 · 192.168.1.10 · Windows 11 [Active]"}
{"type":"status",   "text":"🔍 Looking up #1042…"}
{"type":"error",    "text":"❌ Invalid token"}
```

## Setup

1. Open `RokidLansweeper.xcodeproj` in Xcode 15+.
2. Set your team in Signing & Capabilities.
3. Build and run on iPhone (iOS 17+).
4. In **Settings**:
   - Paste your **Personal Access Token** (create one at [app.lansweeper.com](https://app.lansweeper.com) → Profile → API Access Tokens)
   - Tap **Load sites from API** and select your site
   - Enter your email address for "Assigned to Me" filtering
5. Connect Rokid glasses to the same Wi-Fi; point TCP client at `<phone-ip>:8097`.

## Lansweeper API

Uses the [Lansweeper GraphQL API v2](https://docs.lansweeper.com/docs/api/getting-started):

```
POST https://api.lansweeper.com/api/v2/graphql
Authorization: Bearer <personal-access-token>
Content-Type: application/json

{"query": "query GetTickets($siteId: ID!) { site(id: $siteId) { helpDeskCases { ... } } }", "variables": {...}}
```

### Queries used

| Feature | GraphQL query |
|---------|--------------|
| Sites list | `me { sites { id name } }` |
| Ticket list | `site { helpDeskCases { items { id caseNumber subject status priority ... } } }` |
| Single ticket | `site { helpDeskCase(caseNumber: N) { ... } }` |
| Asset search | `site { assetResources(filters: ...) { items { assetBasicInfo { name ipAddress ... } } } }` |

## Ticket priority colours

| Priority | Icon | Alert |
|----------|------|-------|
| Critical | 🔴 | Always alerts glasses |
| High | 🟠 | Alerts glasses (configurable) |
| Medium | 🟡 | No alert by default |
| Low | 🟢 | No alert |

## Requirements

- iOS 17.0+
- Xcode 15+
- Lansweeper Personal Access Token ([app.lansweeper.com](https://app.lansweeper.com))
- Lansweeper site with Help Desk enabled
- Rokid AR glasses on the same Wi-Fi (optional — app works standalone as a ticket dashboard)
