# Shrimp Buddy — iOS (SwiftUI)

Native iOS app for the Shrimp Buddy aquaculture management platform.

## Quick Setup

### 1. Set your backend URL
Open `ShrimpBuddy/Config/APIConfig.swift` and update:

```swift
static let baseURL = "http://localhost:8085/api/v1"
```

### 2. Open in Xcode
- Open `ShrimpBuddy.xcodeproj` (or create one pointing to this folder)
- Select your development team in Signing & Capabilities
- Choose a simulator or device and press ▶

### 3. Minimum requirements
- iOS 16+
- Xcode 15+
- Swift 5.9+

---

## Project Structure

```
ShrimpBuddy/
├── Config/
│   ├── APIConfig.swift       ← Base URL & all endpoint paths
│   └── Theme.swift           ← Design tokens, shared components
├── Models/
│   └── Models.swift          ← All Codable data models
├── Services/
│   └── APIService.swift      ← All API calls (async/await)
├── Views/
│   ├── Auth/                 ← Login, Register, Forgot/Reset Password
│   ├── Dashboard/            ← Main dashboard
│   ├── Sections/             ← Farm sections list
│   ├── Ponds/                ← Ponds list, add pond, pond detail
│   ├── Feed/                 ← Feed schedule, inventory, dispatch
│   ├── Finance/              ← Finance ledger, harvest, market, reports
│   └── Staff/                ← Staff directory, audit log, settings
└── Navigation/
    └── MainTabView.swift     ← 5-tab app shell + all navigation
```

---

## API Contract

All calls use JWT Bearer token. On login/register, the token is persisted
in `UserDefaults` via `TokenStore`. All subsequent requests include:

```
Authorization: Bearer <token>
Content-Type: application/json
```

### Endpoints expected on your backend

| Method | Path | Description |
|--------|------|-------------|
| POST | /auth/login | Login |
| POST | /auth/register | Register |
| POST | /auth/forgot-password | Send reset link |
| POST | /auth/reset-password | Reset with OTP |
| GET | /dashboard | Dashboard stats |
| GET | /sections | Farm sections |
| GET | /ponds | All ponds (optional ?sectionId=) |
| GET | /ponds/:id | Pond detail |
| POST | /ponds | Create pond |
| GET | /feed-logs | Feed logs (optional ?pondId=&date=) |
| POST | /feed-logs | Log feed |
| GET | /feed-inventory | Feed stock |
| POST | /feed-dispatch | Dispatch feed |
| GET | /chemical-usage | Chemical logs |
| POST | /chemical-usage | Log chemical |
| GET | /chemical-inventory | Chemical stock |
| GET | /sampling-logs | Sampling logs |
| POST | /sampling-logs | Log sample |
| GET | /water-parameters/:pondId | Water params for pond |
| POST | /water-parameters | Log water params |
| GET | /finance | Transactions |
| POST | /finance | Add transaction |
| GET | /harvest-forecasts | Harvest forecast |
| GET | /market-prices | Market prices |
| GET | /reports | Farm reports |
| POST | /reports | Generate report |
| GET | /users | Staff users |
| GET | /audit-logs | Audit log entries |
| GET | /settings | App settings |
| PUT | /settings | Update settings |

### Response format
```json
{
  "success": true,
  "data": { ... },
  "message": "optional message",
  "error": "optional error string"
}
```
