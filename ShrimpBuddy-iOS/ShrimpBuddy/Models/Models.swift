import Foundation

// MARK: - Auth

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct AuthResponse: Codable {
    let token: String
    let userId: String
    let name: String
    let email: String
    let user: AppUser?   // backward compat: some servers embed the user object
}

// MARK: - Farm

struct FarmResponse: Codable, Identifiable {
    let id: String
    let name: String?
    let role: String?
    let location: String?
    let feedManagementMode: String?
    let chemManagementMode: String?
}

struct RegisterRequest: Codable {
    let farmName: String
    let name: String
    let email: String
    let password: String
}

// MARK: - App User

struct AppUser: Codable, Identifiable {
    let id: String
    let name: String
    let email: String
    let role: String
    let status: String   // "active" | "inactive"
    let initials: String
}

// MARK: - Dashboard

struct DashboardStats: Codable {
    let activePonds: Int
    let stablePonds: Int
    let attentionPonds: Int
    let criticalPonds: Int
    let feedLoggedToday: Double
    let feedDailyTarget: Double
    let avgSurvival: Double
    let survivalChange: Double
    let fcr: Double
    let alerts: [Alert]
    let sectionHealth: [SectionHealth]
    let timeline: [TimelineEvent]
    let feedTrend: [FeedTrendPoint]
    let sectionFeedLogs: [SectionFeedLog]

    // backward-compat decode
    enum CodingKeys: String, CodingKey {
        case activePonds, stablePonds, attentionPonds, criticalPonds
        case feedLoggedToday, feedDailyTarget, avgSurvival, survivalChange, fcr
        case alerts, sectionHealth, timeline, feedTrend, sectionFeedLogs
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        activePonds    = try c.decode(Int.self,    forKey: .activePonds)
        stablePonds    = try c.decode(Int.self,    forKey: .stablePonds)
        attentionPonds = try c.decodeIfPresent(Int.self, forKey: .attentionPonds) ?? 0
        criticalPonds  = try c.decode(Int.self,    forKey: .criticalPonds)
        feedLoggedToday = try c.decode(Double.self, forKey: .feedLoggedToday)
        feedDailyTarget = try c.decode(Double.self, forKey: .feedDailyTarget)
        avgSurvival    = try c.decode(Double.self,  forKey: .avgSurvival)
        survivalChange = try c.decodeIfPresent(Double.self, forKey: .survivalChange) ?? 0
        fcr            = try c.decodeIfPresent(Double.self, forKey: .fcr) ?? 0
        alerts         = try c.decodeIfPresent([Alert].self,         forKey: .alerts)          ?? []
        sectionHealth  = try c.decodeIfPresent([SectionHealth].self, forKey: .sectionHealth)   ?? []
        timeline       = try c.decodeIfPresent([TimelineEvent].self, forKey: .timeline)        ?? []
        feedTrend      = try c.decodeIfPresent([FeedTrendPoint].self, forKey: .feedTrend)      ?? []
        sectionFeedLogs = try c.decodeIfPresent([SectionFeedLog].self, forKey: .sectionFeedLogs) ?? []
    }

    init(activePonds: Int, stablePonds: Int, attentionPonds: Int, criticalPonds: Int,
         feedLoggedToday: Double, feedDailyTarget: Double,
         avgSurvival: Double, survivalChange: Double, fcr: Double,
         alerts: [Alert], sectionHealth: [SectionHealth],
         timeline: [TimelineEvent], feedTrend: [FeedTrendPoint],
         sectionFeedLogs: [SectionFeedLog]) {
        self.activePonds     = activePonds
        self.stablePonds     = stablePonds
        self.attentionPonds  = attentionPonds
        self.criticalPonds   = criticalPonds
        self.feedLoggedToday = feedLoggedToday
        self.feedDailyTarget = feedDailyTarget
        self.avgSurvival     = avgSurvival
        self.survivalChange  = survivalChange
        self.fcr             = fcr
        self.alerts          = alerts
        self.sectionHealth   = sectionHealth
        self.timeline        = timeline
        self.feedTrend       = feedTrend
        self.sectionFeedLogs = sectionFeedLogs
    }

    static func empty() -> DashboardStats {
        DashboardStats(activePonds: 0, stablePonds: 0, attentionPonds: 0, criticalPonds: 0,
                       feedLoggedToday: 0, feedDailyTarget: 0, avgSurvival: 0,
                       survivalChange: 0, fcr: 0, alerts: [], sectionHealth: [],
                       timeline: [], feedTrend: [], sectionFeedLogs: [])
    }
}

struct FeedTrendPoint: Codable, Identifiable {
    var id: String { label }
    let label: String  // e.g. "Mon", "Tue"
    let value: Double  // kg
}

struct SectionFeedLog: Codable, Identifiable {
    let id: String
    let sectionName: String
    let feedKg: Double
    let time: String
    let status: String
}

struct Alert: Codable, Identifiable {
    let id: String
    let message: String
    let severity: String // warning | critical | info
}

struct SectionHealth: Codable, Identifiable {
    let id: String
    let name: String
    let status: String // STABLE | ATTENTION | CRITICAL
}

struct TimelineEvent: Codable, Identifiable {
    let id: String
    let time: String
    let event: String
    let detail: String
    let status: String
}

// MARK: - Sections

/// Renamed from Section → SectionRecord to avoid collision with SwiftUI.Section.
struct SectionRecord: Codable, Identifiable {
    let id: String
    let name: String
    let code: String?
    let pondCount: Int?
    let biomassKg: Double?
    let stockedDate: String?
}

/// Shrimp Buddy views use FarmSection throughout; it has identical structure to SectionRecord.
struct FarmSection: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let code: String?
    let pondCount: Int?
    let biomassKg: Double?
    let stockedDate: String?
}

// MARK: - Ponds

struct Pond: Codable, Identifiable {
    let id: String
    let name: String           // display name (Shrimp Buddy)
    let sectionId: String
    let sectionName: String?
    let owner: String?
    let species: String?       // Vannamei | Black Tiger | Monodon
    let type: String?          // backward compat alias for species
    let doc: Int?              // Day of culture
    let abw: Double?           // Average body weight (grams)
    let feedTodayKg: Double?
    let survivalPct: Double?
    let status: String?        // STABLE | ATTENTION | CRITICAL
    let stockingDate: String?  // Shrimp Buddy field name
    let stockedDate: String?   // backward compat
    let seedCount: Int?
    let pondSizeHa: Double?
    let pondId: String?        // backward compat
}

struct CreatePondRequest: Codable {
    let sectionId: String
    let name: String
    let owner: String?
    let species: String
    let pondSizeHa: Double?
    let seedCount: Int?
    let stockingDate: String
}

// MARK: - Feed

struct FeedLog: Codable, Identifiable {
    let id: String
    let pondId: String?      // optional — Shrimp Buddy server may omit
    let pondLabel: String?   // display name for pond
    let feedName: String?    // legacy field
    let feedType: String?    // preferred field
    let totalKg: Double?
    let date: String?
    let time: String?
    let status: String?      // Fed | Pending
    let loggedBy: String?
    let sectionId: String?
    let sectionName: String?
    let notes: String?
}

struct UpdateFeedLogRequest: Codable {
    let date: String?
    let feedType: String?
    let totalKg: Double?
    let feed1Kg: Double?
    let notes: String?
}

struct UpdateChemicalLogRequest: Codable {
    let date: String?
    let chemicalName: String?
    let qty: Double?
    let unit: String?
    let purpose: String?
    let notes: String?
}

struct UpdateFeedDispatchRequest: Codable {
    let date: String?
    let feedType: String?
    let qtyKg: Double?
    let bags: Int?
    let ratePerKg: Double?
    let receivedBy: String?
    let notes: String?
}

struct UpdateChemDispatchRequest: Codable {
    let date: String?
    let chemicalName: String?
    let qtyDispatched: Double?
    let unit: String?
    let ratePerUnit: Double?
    let receivedBy: String?
    let notes: String?
}

struct UpdateChemicalMasterRequest: Codable {
    let name: String?
    let category: String?
    let unit: String?
    let ratePerUnit: Double?
}

struct UpdateCentralReceiptRequest: Codable {
    let date: String?
    let itemName: String?
    let qty: Double?
    let unit: String?
    let ratePerUnit: Double?
    let supplier: String?
    let invoiceNo: String?
    let notes: String?
}

struct CreateFeedLogRequest: Codable {
    let pondId: String
    let date: String?
    let feedName: String?  = nil
    let feedType: String?
    let feed1Kg: Double?
    let totalKg: Double?
    let time: String?      = nil
    let notes: String?
}

struct FeedInventoryItem: Codable, Identifiable {
    let id: String
    let name: String
    let stockKg: Double?
    let category: String?
    let pricePerKg: Double?
    let ratePerKg: Double?   // Shrimp Buddy preferred field
    let lastUpdated: String?
    let isActive: Bool?
    let sectionId: String?
}

struct FeedDispatch: Codable, Identifiable {
    let id: String
    let sectionId: String?
    let sectionName: String?
    let sectionCode: String?
    let feedType: String?
    let qtyKg: Double?
    let bags: Int?
    let ratePerKg: Double?
    let date: String?
    let receivedBy: String?
    let notes: String?
    // backward compat
    let toSectionId: String?
    let toSectionName: String?
    let feedVariety: String?
    let quantityKg: Double?
    let dispatchedBy: String?
}

struct FeedDispatchRequest: Codable {
    let sectionId: String
    let date: String
    let feedType: String
    let qtyKg: Double
    let bags: Int?
    let ratePerKg: Double?
    let receivedBy: String?
    let notes: String?
}

// Request body for creating a central receipt
struct CentralReceiptRequest: Codable {
    let itemType: String
    let itemName: String
    let qty: Double
    let unit: String
    let date: String
    let category: String?
    let ratePerUnit: Double?
    let supplier: String?
    let invoiceNo: String?
    let notes: String?
}

// Central store receipts (feed or chemical purchase records)
struct CentralReceipt: Codable, Identifiable {
    let id: String
    let itemType: String?    // "FEED" | "CHEMICAL"
    let itemName: String?
    let qty: Double?
    let unit: String?
    let category: String?
    let supplier: String?
    let invoiceNo: String?
    let ratePerUnit: Double?
    let totalValue: Double?
    let date: String?
    let notes: String?
}

// MARK: - Chemicals

struct ChemicalLog: Codable, Identifiable {
    let id: String
    let pondId: String
    let chemicalName: String?  // Shrimp Buddy preferred field
    let name: String?          // backward compat
    let qty: Double?           // Shrimp Buddy preferred field
    let quantity: Double?      // backward compat
    let unit: String?
    let purpose: String?
    let date: String?
    let loggedBy: String?
}

struct CreateChemicalLogRequest: Codable {
    let pondId: String
    let date: String?
    let chemicalName: String?
    let name: String?         = nil   // backward compat
    let qty: Double?
    let quantity: Double?     = nil   // backward compat
    let unit: String?
    let purpose: String?
    let notes: String?
}

// ChemicalInventoryItem maps from /chemical-masters endpoint
struct ChemicalInventoryItem: Codable, Identifiable {
    let id: String
    let name: String
    let category: String?
    let unit: String
    let ratePerUnit: Double
    let isActive: Bool?
    let lastUpdated: String?
}

// MARK: - Sampling

struct SamplingLog: Codable, Identifiable {
    let id: String
    let pondId: String
    let date: String?
    let abw: Double?
    let doc: Int?                   // day-of-culture at time of sampling
    let survivalPct: Double?        // alias (may not be sent by backend)
    let estimatedSurvival: Double?  // primary survival field from backend
    let sampleCount: Int?
    let sampleWeightG: Double?      // matches backend key "sampleWeightG"
    let biomassKg: Double?          // estimated total biomass
    let fcr: Double?                // feed conversion ratio
    let estPopulation: Double?      // BigDecimal on backend → must be Double, not Int
    let growthDiffG: Double?        // ABW delta since last sample
    let cumulFeedKg: Double?        // cumulative feed given to pond
    let prevDayFeedKg: Double?      // previous day's feed (for survival formula)
    let estFeedPerDay: Double?      // reference feed per day
    let loggedBy: String?
    let sectionId: String?
    let sectionName: String?
}

struct CreateSamplingRequest: Codable {
    let pondId: String
    let date: String?
    let sampleWeightG: Double?
    let sampleCount: Int?
    let abw: Double?
    let survivalPct: Double?   = nil
    let notes: String?
}

struct UpdateSamplingRequest: Codable {
    let date: String?
    let abw: Double?
    let survivalPct: Double?
    let sampleCount: Int?
    let doc: Int?
    let notes: String?
}

// MARK: - Water Parameters

struct WaterParameter: Codable, Identifiable {
    let id: String
    let pondId: String
    let date: String
    let ph: Double
    let dissolvedOxygen: Double
    let temperature: Double
    let salinity: Double
    let ammonia: Double
    let alkalinity: Double
    let status: String
    let loggedBy: String?
}

struct WaterParamEntry: Codable, Identifiable {
    let id: String
    let name: String
    let value: Double
    let unit: String
    let range: String?
    let status: String
}

// MARK: - Finance

struct FinanceTransaction: Codable, Identifiable {
    let id: String
    let date: String?
    let title: String?
    let description: String?   // Shrimp Buddy preferred field
    let type: String?          // Income | Expense
    let amount: Double?
    let category: String?
    let sectionCode: String?
    let reference: String?
    let note: String?
    let notes: String?
}

struct CreateTransactionRequest: Codable {
    let date: String?
    let description: String?
    let amount: Double?
    let sectionCode: String?
    let notes: String?
    // backward compat fields
    let title: String?    = nil
    let type: String?     = nil
    let category: String? = nil
    let note: String?     = nil
}

// MARK: - Harvest

struct HarvestForecast: Codable, Identifiable {
    let id: String
    let pondId: String?
    let pondLabel: String?
    let currentAbw: Double?
    let targetAbw: Double?
    let daysLeft: Int?
    let daysToHarvest: Int?   // Shrimp Buddy preferred field
    let estimatedBiomassKg: Double?
    let status: String?  // ready | soon | growing
}

// MARK: - Market Prices

struct MarketPrice: Codable, Identifiable {
    let id: String
    let size: String    // e.g. "20-30 pcs/kg"
    let pricePerKg: Double
    let trend: String   // up | down | stable
    let updatedAt: String
}

// MARK: - Reports

struct FarmReport: Codable, Identifiable {
    let id: String
    let title: String
    let type: String    // monthly | cycle | pond
    let generatedAt: String
    let downloadUrl: String?
}

// MARK: - Staff

struct StaffUser: Codable, Identifiable {
    let id: String
    let name: String
    let email: String
    let role: String
    let status: String    // STABLE | INACTIVE
    let section: String?
    let farmId: String?
    let lastActive: String?

    // Computed — not in backend response
    var initials: String {
        name.split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
    }
}

struct AuditLogEntry: Codable, Identifiable {
    let id: String
    let time: String
    let user: String
    let event: String
    let detail: String
    let risk: String    // LOW | HIGH | MEDIUM
}

// MARK: - Settings

struct AppSettings: Codable {
    var farmName: String
    var farmLocation: String
    var notificationsEnabled: Bool
    var alertThresholdAmmonia: Double
    var alertThresholdDO: Double
    var feedReminderEnabled: Bool
    var defaultFeedRounds: Int
    var currencySymbol: String
    var language: String
}

// MARK: - Price List (Feed & Chemical Master)

struct FeedMasterRecord: Codable, Identifiable {
    let id: String
    var name: String
    var ratePerKg: Double
    var unit: String
    var isActive: Bool
}

struct ChemicalMasterRecord: Codable, Identifiable {
    let id: String
    var name: String
    var ratePerUnit: Double
    var unit: String
    var category: String
    var isActive: Bool
}

struct SaveFeedMasterRequest: Codable {
    let records: [FeedMasterRecord]
}

struct SaveChemicalMasterRequest: Codable {
    let records: [ChemicalMasterRecord]
}

// MARK: - Dispatches (for Finance cost calculation)

struct FeedDispatchRecord: Codable, Identifiable {
    let id: String
    let feedType: String
    let qtyKg: Double
    let ratePerKg: Double?
    let date: String
    let sectionId: String?
    let sectionName: String?
}

struct ChemicalDispatchRecord: Codable, Identifiable {
    let id: String
    let chemicalName: String
    let qtyDispatched: Double      // API field name from backend
    let unit: String
    let ratePerUnit: Double?
    let dispatchValue: Double?
    let date: String
    let sectionId: String?
    let sectionName: String?
    let category: String?
    let issuedBy: String?
    let receivedBy: String?
}

// MARK: - Farm Expenses (other costs)

struct FarmExpense: Codable, Identifiable {
    let id: String
    let date: String
    let description: String
    let amount: Double
    let reference: String?
    let notes: String?
}

struct CreateFarmExpenseRequest: Codable {
    let date: String
    let description: String
    let amount: Double
    let reference: String?
    let notes: String?
}

// MARK: - User Management

struct CreateUserRequest: Codable {
    let name: String
    let email: String
    let password: String
    let role: String
    let section: String
}

struct UpdateUserRequest: Codable {
    let name: String?
    let role: String?
    let section: String?
    let status: String?
    let password: String?
}

// MARK: - Audit & Compliance

struct AuditPolicy: Codable, Identifiable {
    let id: String
    var title: String
    var description: String
    var owner: String
    var cadence: String
    var lastRun: String
    var nextDue: String
    var active: Bool
    var status: String
}

struct ComplianceIssue: Codable, Identifiable {
    let id: String
    let title: String
    let area: String
    let owner: String
    let due: String
    let detail: String
    let risk: String
    var status: String
    let action: String
}

// MARK: - Inventory Balance (server-calculated)

struct ChemicalBalanceItem: Codable, Identifiable {
    var id: String { chemicalName + (unit ?? "") }
    let chemicalName: String
    let unit: String?
    let category: String?
    let received: Double
    let dispatched: Double
    let used: Double
    let centralBalance: Double
    let sectionBalance: Double
}

struct FeedStockSummaryItem: Codable, Identifiable {
    var id: String { feedType }
    let feedType: String
    let unit: String?
    let received: Double
    let dispatched: Double
    let used: Double
    let centralStock: Double
    let sectionStock: Double
}

// MARK: - Generic API Response

struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let message: String?
    let error: String?
}

struct PaginatedResponse<T: Codable>: Codable {
    let success: Bool
    let data: [T]
    let total: Int
    let page: Int
    let perPage: Int
}
