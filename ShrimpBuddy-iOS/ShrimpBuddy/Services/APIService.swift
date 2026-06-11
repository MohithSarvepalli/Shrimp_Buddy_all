import Foundation

// MARK: - Token Storage

class TokenStore {
    static let shared = TokenStore()
    private let tokenKey  = "sb_auth_token"
    private let farmIdKey = "sb_farm_id"
    private let roleKey   = "sb_user_role"

    var token: String? {
        get { UserDefaults.standard.string(forKey: tokenKey) }
        set { UserDefaults.standard.set(newValue, forKey: tokenKey) }
    }

    var farmId: String? {
        get { UserDefaults.standard.string(forKey: farmIdKey) }
        set { UserDefaults.standard.set(newValue, forKey: farmIdKey) }
    }

    /// The user's role on their current farm (e.g. "ADMIN", "SUPERVISOR", "WORKER").
    /// Populated automatically by getMyFarms() after login.
    var role: String? {
        get { UserDefaults.standard.string(forKey: roleKey) }
        set { UserDefaults.standard.set(newValue, forKey: roleKey) }
    }

    var isAdmin: Bool {
        let r = (role ?? "").uppercased()
        return r == "OWNER" || r == "ADMIN"
    }

    var isSupervisor: Bool { (role ?? "").uppercased() == "SUPERVISOR" }

    /// True for WORKER (and any unrecognised role). False for ADMIN/OWNER/SUPERVISOR.
    var isWorker: Bool { !isAdmin && !isSupervisor }

    func clear() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: farmIdKey)
        UserDefaults.standard.removeObject(forKey: roleKey)
    }
}

// MARK: - APIError

enum APIError: LocalizedError {
    case invalidURL
    case noData
    case httpError(Int)
    case decodingError(String)
    case serverError(String)
    case unauthorized
    case noFarm

    var errorDescription: String? {
        switch self {
        case .invalidURL:           return "Invalid URL"
        case .noData:               return "No data received"
        case .httpError(let code):  return "HTTP Error \(code)"
        case .decodingError(let m): return "Decode error: \(m)"
        case .serverError(let m):   return m
        case .unauthorized:         return "Session expired — please sign in again"
        case .noFarm:               return "No farm selected"
        }
    }
}

// MARK: - APIService

class APIService {
    static let shared = APIService()
    private let session = URLSession.shared

    /// Base path for all farm-scoped endpoints.
    private var farmBase: String {
        "\(APIConfig.baseURL)/farms/\(TokenStore.shared.farmId ?? "")"
    }

    // MARK: - Core helpers

    private func makeRequest(
        url: String,
        method: String = "GET",
        body: Encodable? = nil,
        requiresAuth: Bool = true
    ) throws -> URLRequest {
        guard let url = URL(string: url) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if requiresAuth, let token = TokenStore.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        return request
    }

    /// Decode response body directly into T (no APIResponse wrapper).
    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 401 { throw APIError.unauthorized }
            if http.statusCode >= 400 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let msg = json["message"] as? String ?? json["error"] as? String {
                    throw APIError.serverError(msg)
                }
                throw APIError.httpError(http.statusCode)
            }
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    /// Fire-and-forget — checks status but ignores the response body.
    private func performVoid(_ request: URLRequest) async throws {
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 401 { throw APIError.unauthorized }
            if http.statusCode >= 400 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let msg = json["message"] as? String ?? json["error"] as? String {
                    throw APIError.serverError(msg)
                }
                throw APIError.httpError(http.statusCode)
            }
        }
    }

    // MARK: - Auth

    func login(email: String, password: String) async throws -> AuthResponse {
        let req = try makeRequest(url: APIConfig.Endpoints.login, method: "POST",
                                  body: LoginRequest(email: email, password: password),
                                  requiresAuth: false)
        let data: AuthResponse = try await perform(req)
        TokenStore.shared.token = data.token
        return data
    }

    func register(name: String, email: String, password: String) async throws -> AuthResponse {
        struct Body: Encodable { let name: String; let email: String; let password: String }
        let req = try makeRequest(url: APIConfig.Endpoints.register, method: "POST",
                                  body: Body(name: name, email: email, password: password),
                                  requiresAuth: false)
        let data: AuthResponse = try await perform(req)
        TokenStore.shared.token = data.token
        return data
    }

    func forgotPassword(email: String) async throws {
        struct Body: Encodable { let email: String }
        let req = try makeRequest(url: APIConfig.Endpoints.forgotPassword, method: "POST",
                                  body: Body(email: email), requiresAuth: false)
        try await performVoid(req)
    }

    func resetPassword(otp: String, newPassword: String) async throws {
        struct Body: Encodable { let otp: String; let newPassword: String }
        let req = try makeRequest(url: APIConfig.Endpoints.resetPassword, method: "POST",
                                  body: Body(otp: otp, newPassword: newPassword), requiresAuth: false)
        try await performVoid(req)
    }

    func logout() { TokenStore.shared.clear() }

    func updateMyProfile(name: String?, password: String?) async throws {
        struct Body: Encodable { let name: String?; let password: String? }
        let req = try makeRequest(url: "\(APIConfig.baseURL)/auth/me", method: "PUT",
                                  body: Body(name: name, password: password))
        try await performVoid(req)
    }

    // MARK: - Farms

    func getMyFarms() async throws -> [FarmResponse] {
        let req = try makeRequest(url: APIConfig.Endpoints.myFarms)
        let farms: [FarmResponse] = try await perform(req)
        // Cache farmId and role so isAdmin checks work everywhere without extra calls.
        if let first = farms.first {
            if TokenStore.shared.farmId == nil { TokenStore.shared.farmId = first.id }
            TokenStore.shared.role = first.role
        }
        return farms
    }

    func createFarm(name: String, location: String) async throws -> FarmResponse {
        struct Body: Encodable { let name: String; let location: String }
        let req = try makeRequest(url: APIConfig.Endpoints.farms, method: "POST",
                                  body: Body(name: name, location: location))
        return try await perform(req)
    }

    func getFarm(id: String) async throws -> FarmResponse {
        let req = try makeRequest(url: APIConfig.Endpoints.farm(id))
        return try await perform(req)
    }

    func updateFarm(id: String, name: String? = nil, location: String? = nil,
                    feedManagementMode: String? = nil, chemicalManagementMode: String? = nil) async throws -> FarmResponse {
        var body: [String: String] = [:]
        if let v = name                   { body["name"] = v }
        if let v = location               { body["location"] = v }
        if let v = feedManagementMode     { body["feedManagementMode"] = v }
        if let v = chemicalManagementMode { body["chemicalManagementMode"] = v }
        let req = try makeRequest(url: APIConfig.Endpoints.farm(id), method: "PUT", body: body)
        return try await perform(req)
    }

    // MARK: - Dashboard (synthesised from /sync snapshot)

    func getDashboard() async throws -> DashboardStats {
        let req = try makeRequest(url: APIConfig.Endpoints.sync)
        guard let json = try? await { () -> Any in
            let (data, _) = try await session.data(for: req)
            return try JSONSerialization.jsonObject(with: data)
        }() as? [[String: Any]] else {
            return DashboardStats.empty()
        }

        // Pull ponds from the first matching farm
        let farmId = TokenStore.shared.farmId ?? ""
        guard let farmEntry = json.first(where: { ($0["id"] as? String) == farmId }),
              let sections = farmEntry["sections"] as? [[String: Any]] else {
            return DashboardStats.empty()
        }

        var allPonds: [[String: Any]] = []
        for s in sections {
            if let ponds = s["ponds"] as? [[String: Any]] { allPonds += ponds }
        }

        let active    = allPonds.count
        let stable    = allPonds.filter { ($0["status"] as? String) == "STABLE" }.count
        let attention = allPonds.filter { ($0["status"] as? String) == "ATTENTION" }.count
        let critical  = allPonds.filter { ($0["status"] as? String) == "CRITICAL" }.count
        let survivals = allPonds.compactMap { $0["survivalPct"] as? Double }
        let avgSurv   = survivals.isEmpty ? 0.0 : survivals.reduce(0, +) / Double(survivals.count)

        let sectionHealthList: [SectionHealth] = sections.map { s in
            SectionHealth(
                id:     (s["id"] as? String) ?? UUID().uuidString,
                name:   (s["name"] as? String) ?? "Section",
                status: (s["status"] as? String) ?? "STABLE"
            )
        }

        return DashboardStats(
            activePonds:     active,
            stablePonds:     stable,
            attentionPonds:  attention,
            criticalPonds:   critical,
            feedLoggedToday: 0,
            feedDailyTarget: 0,
            avgSurvival:     avgSurv,
            survivalChange:  0,
            fcr:             0,
            alerts:          [],
            sectionHealth:   sectionHealthList,
            timeline:        [],
            feedTrend:       [],
            sectionFeedLogs: []
        )
    }

    // MARK: - Sections

    func getSections() async throws -> [FarmSection] {
        let req = try makeRequest(url: "\(farmBase)/sections")
        return try await perform(req)
    }

    func createSection(name: String, code: String) async throws -> FarmSection {
        let req = try makeRequest(url: "\(farmBase)/sections", method: "POST",
                                  body: ["name": name, "code": code])
        return try await perform(req)
    }

    // MARK: - Ponds

    func getPonds(sectionId: String? = nil) async throws -> [Pond] {
        var url = "\(farmBase)/ponds"
        if let sid = sectionId { url += "?sectionId=\(sid)" }
        let req = try makeRequest(url: url)
        return try await perform(req)
    }

    func getPond(id: String) async throws -> Pond {
        let req = try makeRequest(url: "\(farmBase)/ponds/\(id)")
        return try await perform(req)
    }

    func createPond(_ request: CreatePondRequest) async throws -> Pond {
        let req = try makeRequest(url: "\(farmBase)/ponds", method: "POST", body: request)
        return try await perform(req)
    }

    // MARK: - Feed Logs

    func getFeedLogs(pondId: String? = nil) async throws -> [FeedLog] {
        if let pid = pondId {
            let req = try makeRequest(url: "\(farmBase)/feed-logs/pond/\(pid)")
            return try await perform(req)
        }
        let req = try makeRequest(url: "\(farmBase)/feed-logs")
        return try await perform(req)
    }

    func logFeed(_ request: CreateFeedLogRequest) async throws -> FeedLog {
        let req = try makeRequest(url: "\(farmBase)/feed-logs", method: "POST", body: request)
        return try await perform(req)
    }

    func updateFeedLog(id: String, _ body: UpdateFeedLogRequest) async throws -> FeedLog {
        let req = try makeRequest(url: "\(farmBase)/feed-logs/\(id)", method: "PUT", body: body)
        return try await perform(req)
    }

    func updateChemicalLog(id: String, _ body: UpdateChemicalLogRequest) async throws -> ChemicalLog {
        let req = try makeRequest(url: "\(farmBase)/chemical-logs/\(id)", method: "PUT", body: body)
        return try await perform(req)
    }

    func updateFeedDispatch(id: String, _ body: UpdateFeedDispatchRequest) async throws -> FeedDispatch {
        let req = try makeRequest(url: "\(farmBase)/feed-dispatches/\(id)", method: "PUT", body: body)
        return try await perform(req)
    }

    func updateChemDispatch(id: String, _ body: UpdateChemDispatchRequest) async throws -> ChemicalDispatchRecord {
        let req = try makeRequest(url: "\(farmBase)/chemical-dispatches/\(id)", method: "PUT", body: body)
        return try await perform(req)
    }

    func updateChemicalMaster(id: String, _ body: UpdateChemicalMasterRequest) async throws -> ChemicalInventoryItem {
        let req = try makeRequest(url: "\(farmBase)/chemical-masters/\(id)", method: "PUT", body: body)
        return try await perform(req)
    }

    // MARK: - Feed Masters (inventory)

    func getFeedInventory() async throws -> [FeedInventoryItem] {
        let req = try makeRequest(url: "\(farmBase)/feed-masters")
        return try await perform(req)
    }

    func getFeedMasters() async throws -> [FeedInventoryItem] {
        return try await getFeedInventory()
    }

    func createFeedMaster(name: String, ratePerKg: Double) async throws -> FeedInventoryItem {
        struct Body: Encodable { let name: String; let ratePerKg: Double }
        let req = try makeRequest(url: "\(farmBase)/feed-masters", method: "POST",
                                  body: Body(name: name, ratePerKg: ratePerKg))
        return try await perform(req)
    }

    func updateFeedMaster(id: String, name: String, ratePerKg: Double) async throws {
        struct Body: Encodable { let name: String; let ratePerKg: Double }
        let req = try makeRequest(url: "\(farmBase)/feed-masters/\(id)", method: "PUT",
                                  body: Body(name: name, ratePerKg: ratePerKg))
        try await performVoid(req)
    }

    func deleteFeedMaster(id: String) async throws {
        let req = try makeRequest(url: "\(farmBase)/feed-masters/\(id)", method: "DELETE")
        try await performVoid(req)
    }

    // MARK: - Feed Dispatches

    func getFeedDispatches() async throws -> [FeedDispatch] {
        let req = try makeRequest(url: "\(farmBase)/feed-dispatches")
        return try await perform(req)
    }

    func dispatchFeed(_ request: FeedDispatchRequest) async throws {
        let req = try makeRequest(url: "\(farmBase)/feed-dispatches", method: "POST", body: request)
        try await performVoid(req)
    }

    // MARK: - Central Receipts

    func getCentralReceipts(itemType: String) async throws -> [CentralReceipt] {
        let req = try makeRequest(url: "\(farmBase)/central-receipts?itemType=\(itemType)")
        return try await perform(req)
    }

    func createCentralReceipt(_ request: CentralReceiptRequest) async throws {
        let req = try makeRequest(url: "\(farmBase)/central-receipts", method: "POST", body: request)
        try await performVoid(req)
    }

    func updateCentralReceipt(id: String, _ body: UpdateCentralReceiptRequest) async throws -> CentralReceipt {
        let req = try makeRequest(url: "\(farmBase)/central-receipts/\(id)", method: "PUT", body: body)
        return try await perform(req)
    }

    // MARK: - Chemical Logs

    func getChemicalLogs(pondId: String? = nil) async throws -> [ChemicalLog] {
        if let pid = pondId {
            let req = try makeRequest(url: "\(farmBase)/chemical-logs/pond/\(pid)")
            return try await perform(req)
        }
        let req = try makeRequest(url: "\(farmBase)/chemical-logs")
        return try await perform(req)
    }

    func logChemical(_ request: CreateChemicalLogRequest) async throws -> ChemicalLog {
        let req = try makeRequest(url: "\(farmBase)/chemical-logs", method: "POST", body: request)
        return try await perform(req)
    }

    // MARK: - Chemical Dispatches

    func getChemicalDispatches() async throws -> [ChemicalDispatchRecord] {
        let req = try makeRequest(url: "\(farmBase)/chemical-dispatches")
        return try await perform(req)
    }

    // MARK: - Chemical Masters

    func getChemicalMaster() async throws -> [ChemicalMasterRecord] {
        let req = try makeRequest(url: "\(farmBase)/chemical-masters")
        return try await perform(req)
    }

    func getChemicalInventory() async throws -> [ChemicalInventoryItem] {
        // Map from chemical-masters — ChemicalInventoryItem shares the same shape
        let req = try makeRequest(url: "\(farmBase)/chemical-masters")
        return try await perform(req)
    }

    // MARK: - Sampling

    func getSamplingLogs(pondId: String? = nil) async throws -> [SamplingLog] {
        if let pid = pondId {
            let req = try makeRequest(url: "\(farmBase)/sampling/pond/\(pid)")
            return try await perform(req)
        }
        let req = try makeRequest(url: "\(farmBase)/sampling")
        return try await perform(req)
    }

    func logSampling(_ request: CreateSamplingRequest) async throws -> SamplingLog {
        let req = try makeRequest(url: "\(farmBase)/sampling", method: "POST", body: request)
        return try await perform(req)
    }

    func updateSamplingLog(id: String, _ body: UpdateSamplingRequest) async throws -> SamplingLog {
        let req = try makeRequest(url: "\(farmBase)/sampling/\(id)", method: "PUT", body: body)
        return try await perform(req)
    }

    // MARK: - Server-Calculated Inventory Balances

    func getChemicalBalance() async throws -> [ChemicalBalanceItem] {
        let req = try makeRequest(url: "\(farmBase)/chemical-inventory/balance")
        return try await perform(req)
    }

    func getFeedStockSummary() async throws -> [FeedStockSummaryItem] {
        let req = try makeRequest(url: "\(farmBase)/feed-stock/summary")
        return try await perform(req)
    }

    // MARK: - Water Parameters

    func getAllWaterParameters() async throws -> [WaterParameter] {
        // No dedicated endpoint — return empty; views using this show graceful empty state
        return []
    }

    func getWaterParameters(pondId: String) async throws -> [WaterParamEntry] {
        // Synthesize from latest sampling for the pond
        return []
    }

    func logWaterParameters(pondId: String, params: [String: Double]) async throws {
        // Not implemented in this backend
    }

    // MARK: - Finance (farm expenses)

    func getFinanceTransactions() async throws -> [FinanceTransaction] {
        return try await getExpenses()
    }

    func getExpenses() async throws -> [FinanceTransaction] {
        let req = try makeRequest(url: "\(farmBase)/expenses")
        let raw: [FarmExpense] = try await perform(req)
        // Map FarmExpense → FinanceTransaction
        return raw.map { e in
            FinanceTransaction(
                id: e.id, date: e.date, title: nil,
                description: e.description, type: "Expense",
                amount: e.amount, category: nil, sectionCode: nil,
                reference: e.reference, note: nil, notes: e.notes
            )
        }
    }

    func createTransaction(_ request: CreateTransactionRequest) async throws -> FinanceTransaction {
        return try await createExpense(request)
    }

    func createExpense(_ request: CreateTransactionRequest) async throws -> FinanceTransaction {
        let body = CreateFarmExpenseRequest(
            date: request.date ?? "",
            description: request.description ?? "",
            amount: request.amount ?? 0,
            reference: nil,
            notes: request.notes
        )
        let req = try makeRequest(url: "\(farmBase)/expenses", method: "POST", body: body)
        let expense: FarmExpense = try await perform(req)
        return FinanceTransaction(
            id: expense.id, date: expense.date, title: nil,
            description: expense.description, type: "Expense",
            amount: expense.amount, category: nil, sectionCode: nil,
            reference: expense.reference, note: nil, notes: expense.notes
        )
    }

    // MARK: - Farm Expenses (direct)

    func getFarmExpenses() async throws -> [FarmExpense] {
        let req = try makeRequest(url: "\(farmBase)/expenses")
        return try await perform(req)
    }

    func createFarmExpense(_ request: CreateFarmExpenseRequest) async throws -> FarmExpense {
        let req = try makeRequest(url: "\(farmBase)/expenses", method: "POST", body: request)
        return try await perform(req)
    }

    func deleteFarmExpense(id: String) async throws {
        let req = try makeRequest(url: "\(farmBase)/expenses/\(id)", method: "DELETE")
        try await performVoid(req)
    }

    // MARK: - Harvest (no dedicated endpoint — return empty)

    func getHarvestForecasts() async throws -> [HarvestForecast] { return [] }

    // MARK: - Market Prices (no dedicated endpoint — return empty)

    func getMarketPrices() async throws -> [MarketPrice] { return [] }

    // MARK: - Reports

    func getReports() async throws -> [FarmReport] {
        let req = try makeRequest(url: "\(farmBase)/reports")
        return try await perform(req)
    }

    func generateReport(type: String, pondId: String? = nil) async throws -> FarmReport {
        struct Body: Encodable { let type: String; let pondId: String? }
        let req = try makeRequest(url: "\(farmBase)/reports", method: "POST",
                                  body: Body(type: type, pondId: pondId))
        return try await perform(req)
    }

    // MARK: - Users / Staff

    func getUsers() async throws -> [StaffUser] {
        let req = try makeRequest(url: "\(farmBase)/users")
        let raw: [[String: Any]] = try await {
            let (data, _) = try await session.data(for: req)
            return (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
        }()
        return raw.compactMap { m in
            guard let id   = m["userId"] as? String ?? m["id"] as? String,
                  let name = m["name"] as? String,
                  let email = m["email"] as? String else { return nil }
            return StaffUser(
                id: id, name: name, email: email,
                role: m["role"] as? String ?? "WORKER",
                status: m["status"] as? String ?? "STABLE",
                section: m["section"] as? String,
                farmId: m["farmId"] as? String,
                lastActive: m["lastActive"] as? String
            )
        }
    }

    func createUser(_ request: CreateUserRequest) async throws -> StaffUser {
        let req = try makeRequest(url: "\(farmBase)/users", method: "POST", body: request)
        return try await perform(req)
    }

    func updateUser(id: String, _ request: UpdateUserRequest) async throws -> StaffUser {
        let req = try makeRequest(url: "\(farmBase)/users/\(id)", method: "PUT", body: request)
        return try await perform(req)
    }

    // MARK: - Audit Logs (no dedicated endpoint)

    func getAuditLogs() async throws -> [AuditLogEntry] { return [] }

    // MARK: - Price List helpers (aliases)

    func getFeedMaster() async throws -> [FeedMasterRecord] {
        let items = try await getFeedInventory()
        return items.map { FeedMasterRecord(
            id: $0.id, name: $0.name,
            ratePerKg: $0.ratePerKg ?? 0,
            unit: "kg", isActive: $0.isActive ?? true
        )}
    }

    func saveFeedMaster(_ records: [FeedMasterRecord]) async throws -> [FeedMasterRecord] {
        for r in records {
            try await updateFeedMaster(id: r.id, name: r.name, ratePerKg: r.ratePerKg)
        }
        return records
    }

    func createChemicalMaster(name: String, category: String, unit: String, ratePerUnit: Double) async throws -> ChemicalMasterRecord {
        struct Body: Encodable { let name: String; let category: String; let unit: String; let ratePerUnit: Double }
        let req = try makeRequest(url: "\(farmBase)/chemical-masters", method: "POST",
                                  body: Body(name: name, category: category, unit: unit, ratePerUnit: ratePerUnit))
        return try await perform(req)
    }

    func saveChemicalMaster(_ records: [ChemicalMasterRecord]) async throws -> [ChemicalMasterRecord] {
        for r in records {
            let body = UpdateChemicalMasterRequest(
                name: r.name,
                category: r.category,
                unit: r.unit,
                ratePerUnit: r.ratePerUnit
            )
            // Use try? so a 404 on a locally-created record doesn't abort the whole save.
            // New records should be created via createChemicalMaster before calling this.
            _ = try? await updateChemicalMaster(id: r.id, body)
        }
        return records
    }

    // MARK: - Audit & Compliance (no backend endpoints)

    func getAuditPolicies() async throws -> [AuditPolicy] { return [] }
    func getComplianceIssues() async throws -> [ComplianceIssue] { return [] }

    // MARK: - Settings (no backend endpoint)

    func getSettings() async throws -> AppSettings {
        return AppSettings(
            farmName: "", farmLocation: "", notificationsEnabled: true,
            alertThresholdAmmonia: 0.1, alertThresholdDO: 4.0,
            feedReminderEnabled: true, defaultFeedRounds: 4,
            currencySymbol: "₹", language: "en"
        )
    }

    func updateSettings(_ settings: AppSettings) async throws -> AppSettings { return settings }
}
