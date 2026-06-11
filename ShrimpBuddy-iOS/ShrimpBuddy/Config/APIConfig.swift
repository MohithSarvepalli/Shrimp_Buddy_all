import Foundation

enum APIConfig {
    // ─── Set this to your web backend base URL ───────────────────────────────
    static let baseURL = "http://localhost:8085/api/v1"
    // ─────────────────────────────────────────────────────────────────────────

    enum Endpoints {
        // Auth
        static let login              = "\(baseURL)/auth/login"
        static let register           = "\(baseURL)/auth/register"
        static let forgotPassword     = "\(baseURL)/auth/forgot-password"
        static let resetPassword      = "\(baseURL)/auth/reset-password"
        // Dashboard
        static let dashboard          = "\(baseURL)/dashboard"
        // Sections
        static let sections           = "\(baseURL)/sections"
        // Ponds
        static let ponds              = "\(baseURL)/ponds"
        static func pondDetail(_ id: String) -> String { "\(baseURL)/ponds/\(id)" }
        // Feed
        static let feedLogs           = "\(baseURL)/feed-logs"
        static let feedInventory      = "\(baseURL)/feed-inventory"
        static let feedDispatch       = "\(baseURL)/feed-dispatch"
        // Chemicals
        static let chemicalUsage      = "\(baseURL)/chemical-usage"
        static let chemicalInventory  = "\(baseURL)/chemical-inventory"
        // Sampling
        static let samplingLogs       = "\(baseURL)/sampling-logs"
        // Water
        static let waterParameters    = "\(baseURL)/water-parameters"
        static func waterParams(_ pondId: String) -> String { "\(baseURL)/water-parameters/\(pondId)" }
        // Finance
        static let finance            = "\(baseURL)/finance"
        // Harvest
        static let harvest            = "\(baseURL)/harvest-forecasts"
        // Market
        static let marketPrices       = "\(baseURL)/market-prices"
        // Reports
        static let reports            = "\(baseURL)/reports"
        // Staff / User Management
        static let users              = "\(baseURL)/users"
        static func userDetail(_ id: String) -> String { "\(baseURL)/users/\(id)" }
        static let auditLogs          = "\(baseURL)/audit-logs"
        // Settings
        static let settings           = "\(baseURL)/settings"
        // Price List (feed/chemical master records)
        static let feedMaster         = "\(baseURL)/feed-master"
        static let chemicalMaster     = "\(baseURL)/chemical-master"
        // Dispatches (used for Finance cost calculation)
        static let feedDispatches     = "\(baseURL)/feed-dispatch"
        static let chemicalDispatches = "\(baseURL)/chemical-dispatches"
        // Other farm expenses
        static let farmExpenses       = "\(baseURL)/farm-expenses"
        static func farmExpenseDetail(_ id: String) -> String { "\(baseURL)/farm-expenses/\(id)" }
        // Audit & Compliance
        static let auditPolicies      = "\(baseURL)/audit-policies"
        static let complianceIssues   = "\(baseURL)/compliance-issues"
    }
}
