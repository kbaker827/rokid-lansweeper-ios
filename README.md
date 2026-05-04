# Rokid Lansweeper HUD

> **🔵 Connectivity Update — May 2025**
> The glasses connection has been migrated from **raw TCP sockets** to
> **Bluetooth via the Rokid AI glasses SDK** (`pod 'RokidSDK' ~> 1.10.2`).
> No Wi-Fi port forwarding is needed. See **SDK Setup** below.

iOS app that bridges **Lansweeper Help Desk** with **Rokid AR glasses** — bidirectional ticket monitoring and asset lookup.

```
👓 Voice command / 📱 iPhone monitor
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

## Voice commands from the glasses

Speak any of these into the glasses microphone — the Rokid SDK delivers them via `onAsrResult()`:

| What you say | Result |
|--------------|--------|
| `ticket 123` | Look up ticket #123 by case number |
| `asset PC01` | Search assets matching "PC01" |
| `critical` | Show all critical open tickets |
| `high` | Show all high priority tickets |
| `overdue` | Show overdue tickets |
| `unassigned` | Show unassigned active tickets |
| `summary` | Push current summary to glasses |
| `refresh` | Reload data from Lansweeper API |

## Data sent to the glasses

Messages are sent via `RokidMobileSDK.vui.sendMessage(topic:text:to:)`. The topic values map to display layouts on the glasses:

| Topic | Example text |
|-------|-------------|
| `helpdesk` | `🎫 12 active  🔴2 🟠4 🟡5 🟢1` |
| `alert` | `⚠️ [NEW CRITICAL] 🔴 #1042: DB server down` |
| `ticket` | `🔴 #1042 [OPEN]\nDB server down\n👤 John Doe` |
| `asset` | `PC01 · 192.168.1.10 · Windows 11 [Active]` |
| `status` | `🔍 Looking up #1042…` |
| `error` | `❌ Invalid token` |

## SDK Setup

The glasses now connect over **Bluetooth via the Rokid AI glasses SDK** — no Wi-Fi port or TCP server needed.

The only thing left for each app is filling in the three credential constants (`kAppKey`, `kAppSecret`, `kAccessKey`) from [account.rokid.com/#/setting/prove](https://account.rokid.com/#/setting/prove), then running `pod install`.

1. **Get credentials** at <https://account.rokid.com/#/setting/prove> and paste them into `RokidLansweeper/Glasses/GlassesServer.swift`:
   ```swift
   private let kAppKey    = "YOUR_APP_KEY"
   private let kAppSecret = "YOUR_APP_SECRET"
   private let kAccessKey = "YOUR_ACCESS_KEY"
   ```

2. **Install CocoaPods dependencies** from the repo root:
   ```bash
   pod install
   open *.xcworkspace   # always open the .xcworkspace, not .xcodeproj
   ```

3. **Pair your glasses** once in the Rokid companion app — the SDK auto-connects over Bluetooth every launch.

## Setup

1. Open `RokidLansweeper.xcworkspace` in Xcode 15+ (after running `pod install`).
2. Set your team in Signing & Capabilities.
3. Build and run on iPhone (iOS 17+).
4. In **Settings**:
   - Paste your **Personal Access Token** (create one at [app.lansweeper.com](https://app.lansweeper.com) → Profile → API Access Tokens)
   - Tap **Load sites from API** and select your site
   - Enter your email address for "Assigned to Me" filtering

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
- CocoaPods 1.15+ — run `pod install` after cloning
- Lansweeper Personal Access Token ([app.lansweeper.com](https://app.lansweeper.com))
- Lansweeper site with Help Desk enabled
- Rokid AI glasses (paired via Bluetooth — no Wi-Fi needed)
