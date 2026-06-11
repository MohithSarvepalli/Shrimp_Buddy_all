import SwiftUI

struct FeedScheduleView: View {
    @State private var logs: [FeedLog] = []
    @State private var isLoading = true
    @State private var showLogSheet = false

    var totalFedKg: Double { logs.reduce(0) { $0 + ($1.totalKg ?? 0) } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SBAppHeader(title: "Daily Feed Schedule",
                            trailingAction: { showLogSheet = true }, trailingLabel: "+ Log")

                // Summary strip
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TOTAL FEED LOGGED").font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.sbOnSurfaceVariant)
                        Text(String(format: "%.1f kg", totalFedKg))
                            .font(.system(size: 20, weight: .bold)).foregroundColor(.sbPrimary)
                    }
                    Spacer()
                    Text("\(logs.count) entries")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.sbSecondary)
                }
                .padding(14)
                .background(Color.sbPrimaryContainer)
                .overlay(Divider(), alignment: .bottom)

                if isLoading { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
                else if logs.isEmpty {
                    EmptyStateView(icon: "🍤", title: "No Feed Logs",
                                   message: "Log the first feed entry for a pond.")
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            SBCard {
                                VStack(spacing: 0) {
                                    HStack {
                                        Text("FEED LOG HISTORY").font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(.sbOnSurfaceVariant)
                                        Spacer()
                                    }.padding(.bottom, 8)
                                    ForEach(logs) { log in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("\(log.pondLabel ?? log.pondId ?? "Pond") · \(log.feedType ?? "Feed")")
                                                    .font(.system(size: 12, weight: .medium))
                                                Text(log.date ?? "")
                                                    .font(.system(size: 10)).foregroundColor(.sbOnSurfaceVariant)
                                            }
                                            Spacer()
                                            Text(String(format: "%.1f kg", log.totalKg ?? 0))
                                                .font(.system(size: 12, weight: .semibold)).foregroundColor(.sbSuccess)
                                        }
                                        .padding(.vertical, 8)
                                        Divider()
                                    }
                                }
                            }
                        }.padding(14)
                    }
                }
            }
            .background(Color.sbSurface)
            .task { await load() }
            .sheet(isPresented: $showLogSheet, onDismiss: { Task { await load() }}) {
                LogFeedSheet(pondId: "")
            }
        }
    }

    private func load() async {
        isLoading = true
        if let data = try? await APIService.shared.getFeedLogs() {
            await MainActor.run { logs = data; isLoading = false }
        } else { await MainActor.run { isLoading = false } }
    }
}

// Per-section balance computed from dispatches minus feed-log usage
struct SectionFeedBalance: Identifiable {
    let id: String           // sectionId
    let sectionName: String
    let latestFeedType: String   // feedType from the most recent dispatch
    let totalDispatched: Double
    let totalUsed: Double
    var balance: Double { totalDispatched - totalUsed }
}

struct FeedInventoryView: View {
    @State private var balances: [SectionFeedBalance] = []
    @State private var sections: [FarmSection] = []
    @State private var feedMasters: [FeedInventoryItem] = []
    @State private var isLoading = true
    @State private var showDispatch = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SBAppHeader(title: "Feed Stock",
                            trailingAction: { showDispatch = true }, trailingLabel: "Dispatch →")
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if balances.isEmpty {
                    EmptyStateView(icon: "🌾", title: "No Dispatch Data",
                                   message: "Import feed dispatch data to see stock balances.")
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(balances) { bal in
                                SBCard {
                                    VStack(alignment: .leading, spacing: 10) {
                                        // Header: section name + feed type
                                        HStack {
                                            Text(bal.sectionName)
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.sbOnSurface)
                                            Spacer()
                                            if !bal.latestFeedType.isEmpty {
                                                Text(bal.latestFeedType)
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundColor(.sbPrimary)
                                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                                    .background(Color.sbPrimary.opacity(0.12))
                                                    .cornerRadius(8)
                                            }
                                        }
                                        // Stats row
                                        HStack(spacing: 0) {
                                            StatCell(label: "Dispatched",
                                                     value: String(format: "%.0f kg", bal.totalDispatched),
                                                     color: .sbPrimary)
                                            Divider().frame(height: 30).background(Color.sbOutline)
                                            StatCell(label: "Used",
                                                     value: String(format: "%.0f kg", bal.totalUsed),
                                                     color: .sbOnSurfaceVariant)
                                            Divider().frame(height: 30).background(Color.sbOutline)
                                            StatCell(label: "Balance",
                                                     value: String(format: "%.0f kg", bal.balance),
                                                     color: bal.balance >= 0 ? Color(hex: "#22c55e") : Color(hex: "#ef4444"))
                                        }
                                    }
                                }
                            }
                        }.padding(14)
                    }
                }
            }
            .background(Color.sbSurface)
            .task { await loadData() }
            .refreshable { await loadData() }
            .sheet(isPresented: $showDispatch) {
                FeedDispatchView(sections: sections, feedMasters: feedMasters)
                    .onDisappear { Task { await loadData() } }
            }
        }
    }

    private func loadData() async {
        isLoading = true
        async let sectionsTask  = APIService.shared.getSections()
        async let dispatchTask  = APIService.shared.getFeedDispatches()
        async let logsTask      = APIService.shared.getFeedLogs()
        async let mastersTask   = APIService.shared.getFeedMasters()

        let sl  = (try? await sectionsTask)  ?? []
        let dl  = (try? await dispatchTask)  ?? []
        let ll  = (try? await logsTask)      ?? []
        let ml  = (try? await mastersTask)   ?? []

        // Build section name lookup
        let sectionNames = Dictionary(uniqueKeysWithValues: sl.map { ($0.id, $0.name) })

        // Group dispatches by sectionId
        var dispatched: [String: Double] = [:]      // sectionId → total kg
        var latestDate:  [String: String] = [:]     // sectionId → latest dispatch date
        var latestType:  [String: String] = [:]     // sectionId → feedType of latest dispatch

        for d in dl {
            let sid = d.sectionId ?? d.toSectionId ?? ""
            guard !sid.isEmpty else { continue }
            let qty = d.qtyKg ?? d.quantityKg ?? 0
            dispatched[sid, default: 0] += qty

            let dt = d.date ?? ""
            if dt > (latestDate[sid] ?? "") {
                latestDate[sid] = dt
                latestType[sid] = d.feedType ?? d.feedVariety ?? ""
            }
        }

        // Group feed-log usage by sectionId
        var used: [String: Double] = [:]
        for l in ll {
            let sid = l.sectionId ?? ""
            guard !sid.isEmpty else { continue }
            used[sid, default: 0] += l.totalKg ?? 0
        }

        // Build balance rows for any section that has dispatches and non-zero balance
        let result = dispatched.keys.sorted().compactMap { sid -> SectionFeedBalance? in
            let totalDisp = dispatched[sid] ?? 0
            let totalUsed = used[sid] ?? 0
            guard totalDisp > 0 && (totalDisp - totalUsed) > 0.001 else { return nil }
            return SectionFeedBalance(
                id: sid,
                sectionName: sectionNames[sid] ?? sid,
                latestFeedType: latestType[sid] ?? "",
                totalDispatched: totalDisp,
                totalUsed: totalUsed
            )
        }.sorted { $0.sectionName < $1.sectionName }

        await MainActor.run {
            sections = sl
            feedMasters = ml
            balances = result
            isLoading = false
        }
    }
}

private struct StatCell: View {
    let label: String
    let value: String
    let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 10)).foregroundColor(.sbOnSurfaceVariant)
            Text(value).font(.system(size: 13, weight: .bold)).foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

struct FeedDispatchView: View {
    @Environment(\.dismiss) var dismiss
    let sections: [FarmSection]
    let feedMasters: [FeedInventoryItem]

    @State private var selectedSectionId = ""
    @State private var feedType = ""
    @State private var qtyKg = ""
    @State private var bags = ""
    @State private var ratePerKg = ""
    @State private var receivedBy = ""
    @State private var notes = ""
    @State private var date: Date = Date()
    @State private var isLoading = false
    @State private var errorMsg: String?

    var selectedSectionName: String {
        sections.first { $0.id == selectedSectionId }?.name ?? "Select Section"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.sbSurface.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {

                        SBCard {
                            VStack(spacing: 14) {

                                // Section picker
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("SECTION").font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.sbOnSurfaceVariant)
                                    if sections.isEmpty {
                                        Text("No sections available").font(.system(size: 13))
                                            .foregroundColor(.sbOnSurfaceVariant)
                                    } else {
                                        Picker("Section", selection: $selectedSectionId) {
                                            Text("Select Section").tag("")
                                            ForEach(sections) { s in
                                                Text(s.name).tag(s.id)
                                            }
                                        }
                                        .tint(.sbPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }

                                Divider().background(Color.sbOutline)

                                // Feed type picker (from feed masters)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("FEED TYPE").font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.sbOnSurfaceVariant)
                                    if feedMasters.isEmpty {
                                        SBTextField(label: "", text: $feedType, placeholder: "e.g. Starter, Grower")
                                    } else {
                                        Picker("Feed Type", selection: $feedType) {
                                            Text("Select Feed Type").tag("")
                                            ForEach(feedMasters) { m in
                                                Text(m.name).tag(m.name)
                                            }
                                        }
                                        .tint(.sbPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }

                                Divider().background(Color.sbOutline)

                                // Qty + Bags row
                                HStack(spacing: 12) {
                                    SBTextField(label: "Qty (kg)", text: $qtyKg,
                                                placeholder: "100", keyboardType: .decimalPad)
                                    SBTextField(label: "Bags (optional)", text: $bags,
                                                placeholder: "5", keyboardType: .numberPad)
                                }

                                SBTextField(label: "Rate/kg (optional)", text: $ratePerKg,
                                            placeholder: "₹ per kg", keyboardType: .decimalPad)
                                SBTextField(label: "Received By (optional)", text: $receivedBy,
                                            placeholder: "Staff name")
                                SBTextField(label: "Notes (optional)", text: $notes,
                                            placeholder: "Any notes")

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("DATE").font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.sbOnSurfaceVariant)
                                    DatePicker("", selection: $date, in: ...Date(),
                                               displayedComponents: .date)
                                        .labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
                                        .tint(.sbPrimary)
                                }
                            }
                        }

                        if let err = errorMsg {
                            Text(err).font(.system(size: 12)).foregroundColor(.sbError)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4)
                        }

                        SBPrimaryButton("Confirm Dispatch", isLoading: isLoading) {
                            guard !selectedSectionId.isEmpty else {
                                errorMsg = "Please select a section."; return
                            }
                            guard !feedType.isEmpty else {
                                errorMsg = "Please select a feed type."; return
                            }
                            guard let q = Double(qtyKg), q > 0 else {
                                errorMsg = "Enter a valid quantity."; return
                            }
                            errorMsg = nil
                            Task {
                                isLoading = true
                                let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
                                try? await APIService.shared.dispatchFeed(FeedDispatchRequest(
                                    sectionId: selectedSectionId,
                                    date: fmt.string(from: date),
                                    feedType: feedType,
                                    qtyKg: q,
                                    bags: Int(bags),
                                    ratePerKg: Double(ratePerKg),
                                    receivedBy: receivedBy.isEmpty ? nil : receivedBy,
                                    notes: notes.isEmpty ? nil : notes))
                                await MainActor.run { dismiss() }
                            }
                        }

                        Spacer(minLength: 30)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Feed Dispatch").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }.foregroundColor(.sbSecondary)
            }}
            .onAppear {
                if selectedSectionId.isEmpty, let first = sections.first {
                    selectedSectionId = first.id
                }
                if feedType.isEmpty, let first = feedMasters.first {
                    feedType = first.name
                }
            }
        }
    }
}

// MARK: - Feed Management (Ops → Feed Management)
// Master: Feed Log | Inventory | Dispatches
// Section picker includes "Central" when feedManagementMode == CENTRAL
// Pond dropdown shown for Feed Log + Dispatches only

struct SectionOption: Identifiable {
    let id: String
    let name: String
}

enum DateRange: String, CaseIterable {
    case week    = "7D"
    case month   = "30D"
    case quarter = "90D"
    case all     = "All"

    var cutoff: String? {
        let days: Int
        switch self {
        case .week:    days = 7
        case .month:   days = 30
        case .quarter: days = 90
        case .all:     return nil
        }
        let d = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: d)
    }
}

enum FeedMasterTab: String, CaseIterable {
    case central    = "Central"    // only shown when isCentral
    case inventory  = "Inventory"
    case dispatches = "Dispatches"
    case feedLog    = "Feed Log"
}

struct FeedLogView: View {   // kept as FeedLogView so OpsMenuView reference compiles
    @EnvironmentObject var authState: AuthStateObject

    @State private var masterTab:         FeedMasterTab          = .inventory
    @State private var sections:          [FarmSection]          = []
    @State private var ponds:             [Pond]                 = []
    @State private var feedLogs:          [FeedLog]              = []
    @State private var feedInventory:     [FeedInventoryItem]    = []
    @State private var dispatches:        [FeedDispatch]         = []
    @State private var centralReceipts:   [CentralReceipt]       = []
    @State private var feedStockSummary:  [FeedStockSummaryItem] = []
    @State private var selectedSectionId: String              = ""
    @State private var selectedPondId:    String?             = nil
    @State private var filterDate:        Date?               = nil
    @State private var isLoading          = true
    @State private var loadError: String? = nil
    @State private var showLog            = false
    @State private var showDispatch       = false
    @State private var showAddReceipt     = false
    @State private var editingFeedMaster: FeedInventoryItem? = nil

    var filterDay: Date? { filterDate.map { Calendar.current.startOfDay(for: $0) } }

    var isCentral: Bool {
        authState.currentFarm?.feedManagementMode == "central_store"
    }

    // Tabs visible depend on management mode
    var visibleTabs: [FeedMasterTab] {
        isCentral
            ? [.central, .inventory, .dispatches, .feedLog]
            : [.inventory, .dispatches, .feedLog]
    }

    // Section picker — "All Sections" sentinel (id="") + each real section
    var pickerSections: [SectionOption] {
        [SectionOption(id: "", name: "All")] + sections.map { SectionOption(id: $0.id, name: $0.name) }
    }

    var pondsInSection: [Pond] {
        ponds.filter { $0.sectionId == selectedSectionId }
    }

    // Section filter shown only on tabs where per-section view makes sense
    var showSectionFilter: Bool {
        masterTab != .central && sections.count > 0
    }

    // Pond + date row shown only on log/dispatch tabs
    var showFiltersRow: Bool {
        masterTab == .feedLog || masterTab == .dispatches
    }

    var showPondDropdown: Bool { showFiltersRow }

    var filteredFeedLogs: [FeedLog] {
        var r = feedLogs
        if !selectedSectionId.isEmpty { r = r.filter { $0.sectionId == selectedSectionId } }
        if let pid = selectedPondId    { r = r.filter { $0.pondId == pid } }
        if let fd = filterDay { r = r.filter { (parseRecordDate($0.date) ?? .distantPast) >= fd } }
        return r.sorted { ($0.date ?? "") > ($1.date ?? "") }
    }

    // Feed masters — farm-level reference data (name + rate)
    var filteredInventory: [FeedInventoryItem] { feedInventory }

    // Section-only filtered data for the inventory tab (no pond/date filter)
    var inventoryDispatches: [FeedDispatch] {
        selectedSectionId.isEmpty ? dispatches
            : dispatches.filter { $0.sectionId == selectedSectionId }
    }
    var inventoryFeedLogs: [FeedLog] {
        selectedSectionId.isEmpty ? feedLogs
            : feedLogs.filter { $0.sectionId == selectedSectionId }
    }

    var filteredDispatches: [FeedDispatch] {
        var r = dispatches
        if !selectedSectionId.isEmpty { r = r.filter { $0.sectionId == selectedSectionId } }
        if let fd = filterDay { r = r.filter { (parseRecordDate($0.date) ?? .distantPast) >= fd } }
        return r.sorted { ($0.date ?? "") > ($1.date ?? "") }
    }

    var activeCount: Int {
        switch masterTab {
        case .central:    return centralReceipts.count
        case .inventory:  return filteredInventory.count
        case .dispatches: return filteredDispatches.count
        case .feedLog:    return filteredFeedLogs.count
        }
    }

    var selectedPondName: String {
        guard let pid = selectedPondId else { return "All Ponds" }
        return pondsInSection.first { $0.id == pid }?.name ?? "All Ponds"
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
        VStack(spacing: 0) {

            SBAppHeader(title: "Feed Management")

            // ── Master tab ───────────────────────────────────────────────────
            Picker("", selection: $masterTab) {
                ForEach(visibleTabs, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .overlay(Divider().background(Color.sbOutline), alignment: .bottom)
            .onAppear { applySegmentedAppearance() }

            // ── Section filter (log / dispatch / section-inventory tabs) ─────
            if showSectionFilter {
                SBSectionPillTabs(
                    sections: pickerSections.map(\.name),
                    selected: Binding(
                        get: { pickerSections.first { $0.id == selectedSectionId }?.name ?? "All" },
                        set: { name in selectedSectionId = pickerSections.first { $0.name == name }?.id ?? "" }
                    )
                )
                .overlay(Divider().background(Color.sbOutline), alignment: .bottom)
            }

            // ── Pond dropdown + date picker (log/dispatch tabs only) ──────────
            if showFiltersRow {
            HStack(spacing: 10) {
                if showPondDropdown {
                    Menu {
                        Button { selectedPondId = nil } label: {
                            HStack {
                                Text("All Ponds")
                                if selectedPondId == nil { Spacer(); Image(systemName: "checkmark") }
                            }
                        }
                        if !pondsInSection.isEmpty {
                            Divider()
                            ForEach(pondsInSection) { pond in
                                Button { selectedPondId = pond.id } label: {
                                    HStack {
                                        Text(pond.name)
                                        if selectedPondId == pond.id {
                                            Spacer(); Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "water.waves").font(.system(size: 11))
                                .foregroundColor(.sbPrimary)
                            Text(selectedPondName)
                                .font(.system(size: 12, weight: .medium)).foregroundColor(.sbOnSurface)
                            Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.sbOnSurfaceVariant)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color.sbSurface).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sbOutline, lineWidth: 1))
                    }
                }
                Spacer()
                // Date pill — tap calendar icon to pick a date; × clears it
                HStack(spacing: 4) {
                    Image(systemName: "calendar").font(.system(size: 11)).foregroundColor(.sbPrimary)
                    if let fd = filterDate {
                        DatePicker("", selection: Binding(get: { fd }, set: { filterDate = $0 }),
                                   in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact).labelsHidden().tint(.sbPrimary).fixedSize()
                        Button { filterDate = nil } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13)).foregroundColor(.sbOnSurfaceVariant)
                        }
                    } else {
                        Button { filterDate = Date() } label: {
                            Text("All dates").font(.system(size: 12)).foregroundColor(.sbOnSurface)
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(filterDate != nil ? Color.sbPrimary.opacity(0.08) : Color.sbSurface).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                    filterDate != nil ? Color.sbPrimary : Color.sbOutline, lineWidth: 1))
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Color.sbBg)
            .overlay(Divider().background(Color.sbOutline), alignment: .bottom)
            } // if showFiltersRow

            // ── Content ──────────────────────────────────────────────────────
            if isLoading {
                Spacer(); ProgressView().tint(.sbPrimary); Spacer()
            } else {
                switch masterTab {
                case .central:
                    CentralReceiptListSection(
                        receipts: centralReceipts,
                        itemType: "FEED",
                        isAdmin: TokenStore.shared.isAdmin,
                        onRefresh: { Task { await loadAll() } }
                    )
                case .inventory:
                    ScrollView {
                        FeedStockSection(
                            dispatches: inventoryDispatches,
                            feedLogs: inventoryFeedLogs,
                            centralReceipts: centralReceipts,
                            isCentral: isCentral,
                            feedMasters: feedInventory,
                            isAdmin: TokenStore.shared.isAdmin,
                            onRefresh: { Task { await loadAll() } }
                        )
                    }
                case .dispatches:
                    FeedDispatchListSection(
                        dispatches: filteredDispatches,
                        sections: sections,
                        isAdmin: TokenStore.shared.isAdmin,
                        onRefresh: { Task { await loadAll() } }
                    )
                case .feedLog:
                    if let err = loadError {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.sbError).font(.system(size: 28))
                            Text(err)
                                .font(.system(size: 12))
                                .foregroundColor(.sbOnSurfaceVariant)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        FeedLogListSection(
                            logs: filteredFeedLogs,
                            isAdmin: TokenStore.shared.isAdmin,
                            onRefresh: { Task { await loadAll() } }
                        )
                    }
                }
            }
        }
        .background(Color.sbBg.ignoresSafeArea())
        .navigationBarHidden(true)

        // ── Floating Action Button ─────────────────────────────────────────
        if masterTab == .feedLog || masterTab == .dispatches || masterTab == .central {
            SBFab(
                icon: "plus",
                label: masterTab == .feedLog ? "Log Feed" :
                       masterTab == .dispatches ? "Dispatch" : "Add Receipt"
            ) {
                switch masterTab {
                case .feedLog:    showLog = true
                case .dispatches: showDispatch = true
                case .central:    showAddReceipt = true
                default:          break
                }
            }
            .padding(.trailing, 20).padding(.bottom, 28)
        }

        } // ZStack
        .task { await loadAll() }
        .sheet(isPresented: $showLog) {
            LogFeedSheet(pondId: selectedPondId ?? "", ponds: pondsInSection.isEmpty ? ponds : pondsInSection)
        }
        .sheet(isPresented: $showDispatch, onDismiss: { Task { await loadAll() } }) {
            FeedDispatchView(sections: sections, feedMasters: feedInventory)
        }
        .sheet(isPresented: $showAddReceipt, onDismiss: { Task { await loadAll() } }) {
            AddCentralReceiptSheet(itemType: "FEED", itemNames: feedInventory.map { $0.name })
        }
        .sheet(item: $editingFeedMaster, onDismiss: { Task { await loadAll() } }) { master in
            EditFeedMasterSheet(master: master)
        }
        .onChange(of: masterTab)          { _ in selectedPondId = nil }
        .onChange(of: selectedSectionId)  { _ in selectedPondId = nil }
        // When currentFarm loads after app restart, re-derive the correct default tab
        .onChange(of: authState.currentFarm?.feedManagementMode) { _ in
            masterTab = isCentral ? .central : .inventory
        }
    }

    private func loadAll() async {
        // Always refresh farm so feedManagementMode is current before isCentral is evaluated
        await authState.refreshFarm()
        await MainActor.run { isLoading = true; loadError = nil }

        var logsError: String? = nil
        let sl  = (try? await APIService.shared.getSections())  ?? []
        let pl  = (try? await APIService.shared.getPonds())     ?? []
        let fll: [FeedLog]
        do {
            fll = try await APIService.shared.getFeedLogs()
        } catch {
            fll = []
            logsError = "Feed logs error: \(error.localizedDescription)"
        }
        let fil = (try? await APIService.shared.getFeedInventory())                   ?? []
        let fdl = (try? await APIService.shared.getFeedDispatches())                  ?? []
        let crl = (try? await APIService.shared.getCentralReceipts(itemType: "FEED")) ?? []
        let fsl = (try? await APIService.shared.getFeedStockSummary())                ?? []
        await MainActor.run {
            sections         = sl
            ponds            = pl
            feedLogs         = fll
            feedInventory    = fil
            dispatches       = fdl
            centralReceipts  = crl
            feedStockSummary = fsl
            loadError        = logsError
            selectedSectionId = ""   // default to "All" so all feed logs are visible
            masterTab     = isCentral ? .central : .inventory
            isLoading     = false
        }
    }
}

// MARK: - Shared helpers

/// Parse any "YYYY-MM-DD…" or "YYYY-M-D…" date string to midnight Date.
func parseRecordDate(_ s: String?) -> Date? {
    guard let s, !s.isEmpty else { return nil }
    let fmt = DateFormatter()
    fmt.locale = Locale(identifier: "en_US_POSIX")
    for format in ["yyyy-MM-dd", "yyyy-M-d"] {
        fmt.dateFormat = format
        if let d = fmt.date(from: String(s.prefix(10))) { return d }
    }
    return nil
}

func applySegmentedAppearance() {
    UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(Color(hex: "#0060ab"))
    UISegmentedControl.appearance().setTitleTextAttributes(
        [.foregroundColor: UIColor.white,
         .font: UIFont.systemFont(ofSize: 13, weight: .semibold)],
        for: .selected)
    UISegmentedControl.appearance().setTitleTextAttributes(
        [.foregroundColor: UIColor(Color(hex: "#001142")),
         .font: UIFont.systemFont(ofSize: 13, weight: .regular)],
        for: .normal)
}

// MARK: - Floating Action Button

struct SBFab: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.sbPrimary)
            .clipShape(Capsule())
            .shadow(color: Color(hex: "#0060ab").opacity(0.35), radius: 14, x: 0, y: 6)
        }
    }
}

// MARK: - Feed Log list

private struct FeedLogListSection: View {
    let logs: [FeedLog]
    var isAdmin: Bool = false
    var onRefresh: (() -> Void)? = nil
    var body: some View {
        if logs.isEmpty {
            EmptyStateView(icon: "🌾", title: "No Feed Logs",
                           message: "No logs found for the selected filters.")
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(logs) { FeedLogCard(log: $0, isAdmin: isAdmin, onRefresh: onRefresh) }
                }.padding(14)
            }
        }
    }
}

// MARK: - Feed Inventory list

private struct FeedInventorySection: View {
    let items: [FeedInventoryItem]
    var heading: String = "Inventory"
    var body: some View {
        if items.isEmpty {
            EmptyStateView(icon: "📦", title: "No \(heading)",
                           message: "Feed inventory items will appear here.")
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        SBCard {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle().fill(Color.sbPrimaryDim).frame(width: 38, height: 38)
                                    Image(systemName: "archivebox")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.sbPrimary)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.sbOnSurface)
                                    Text(item.isActive == true ? "Active" : "Inactive")
                                        .font(.system(size: 11))
                                        .foregroundColor(item.isActive == true ? .sbSuccess : .sbOnSurfaceVariant)
                                }
                                Spacer()
                                if let rate = item.ratePerKg {
                                    Text(String(format: "₹%.0f/kg", rate))
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.sbPrimary)
                                }
                            }
                        }
                    }
                }.padding(14)
            }
        }
    }
}

// MARK: - Feed Inventory Edit Section (feed masters with edit / delete)

private struct FeedInventoryEditSection: View {
    let items: [FeedInventoryItem]
    let onEdit: (FeedInventoryItem) -> Void
    let onDelete: (FeedInventoryItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Feed Types")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.sbOnSurfaceVariant)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 8)

            if items.isEmpty {
                Text("No feed types configured.")
                    .font(.system(size: 13))
                    .foregroundColor(.sbOnSurfaceVariant)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            } else {
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        SBCard {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle().fill(Color.sbPrimaryDim).frame(width: 38, height: 38)
                                    Image(systemName: "leaf")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.sbPrimary)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.sbOnSurface)
                                    Text(item.isActive == true ? "Active" : "Inactive")
                                        .font(.system(size: 11))
                                        .foregroundColor(item.isActive == true ? .sbSuccess : .sbOnSurfaceVariant)
                                }
                                Spacer()
                                if let rate = item.ratePerKg {
                                    Text(String(format: "₹%.0f/kg", rate))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.sbPrimary)
                                }
                                Menu {
                                    Button { onEdit(item) } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) { onDelete(item) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.sbOnSurfaceVariant)
                                        .frame(width: 32, height: 32)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
    }
}

struct EditFeedMasterSheet: View {
    @Environment(\.dismiss) var dismiss
    let master: FeedInventoryItem

    @State private var name: String = ""
    @State private var rate: String = ""
    @State private var isSaving = false
    @State private var error: String? = nil

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Feed Type")) {
                    TextField("Name", text: $name)
                    TextField("Rate per kg (₹)", text: $rate)
                        .keyboardType(.decimalPad)
                }
                if let err = error {
                    Section {
                        Text(err).foregroundColor(.sbError).font(.system(size: 13))
                    }
                }
            }
            .navigationTitle("Edit Feed Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            name = master.name
            rate = master.ratePerKg.map { String(format: "%.2f", $0) } ?? ""
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let kg = Double(rate) ?? 0
        guard !trimmed.isEmpty else { error = "Name is required."; return }
        isSaving = true
        Task {
            do {
                try await APIService.shared.updateFeedMaster(id: master.id, name: trimmed, ratePerKg: kg)
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Feed Stock (client-side, section-filtered)

private struct FeedStockSection: View {
    // Always receives pre-filtered data from parent
    var dispatches: [FeedDispatch] = []        // section-filtered dispatches
    var feedLogs: [FeedLog] = []               // section-filtered logs
    var centralReceipts: [CentralReceipt] = [] // farm-wide (central mode only)
    var isCentral: Bool = true
    var feedMasters: [FeedInventoryItem] = []
    var isAdmin: Bool = false
    var onRefresh: (() -> Void)? = nil

    var displayItems: [FeedStockSummaryItem] {
        if isCentral {
            // Central: receipts − dispatches per feed type (farm-wide)
            var received: [String: Double] = [:]
            var dispName: [String: String]  = [:]
            for r in centralReceipts {
                guard let name = r.itemName, !name.isEmpty else { continue }
                let key = name.lowercased()
                received[key, default: 0] += r.qty ?? 0
                dispName[key] = dispName[key] ?? name
            }
            var dispatched: [String: Double] = [:]
            for d in dispatches {
                guard let ft = d.feedType, !ft.isEmpty else { continue }
                let key = ft.lowercased()
                dispatched[key, default: 0] += d.qtyKg ?? 0
                dispName[key] = dispName[key] ?? ft
            }
            let allKeys = Set(received.keys).union(Set(dispatched.keys))
            return allKeys.sorted().compactMap { key in
                let rec = received[key] ?? 0
                let dis = dispatched[key] ?? 0
                guard rec > 0 || dis > 0 else { return nil }
                return FeedStockSummaryItem(
                    feedType: dispName[key] ?? key, unit: "kg",
                    received: rec, dispatched: dis, used: 0,
                    centralStock: max(0, rec - dis), sectionStock: 0)
            }
        } else {
            // Non-central: dispatched − used per feed type within the filtered section
            var dispByType: [String: Double] = [:]
            var typeName:   [String: String]  = [:]
            for d in dispatches {
                guard let ft = d.feedType, !ft.isEmpty else { continue }
                let key = ft.lowercased()
                dispByType[key, default: 0] += d.qtyKg ?? 0
                typeName[key] = typeName[key] ?? ft
            }
            var usedByType: [String: Double] = [:]
            for l in feedLogs {
                guard let ft = l.feedType ?? l.feedName, !ft.isEmpty else { continue }
                usedByType[ft.lowercased(), default: 0] += l.totalKg ?? 0
            }
            return dispByType.keys.sorted().compactMap { key in
                let dis = dispByType[key] ?? 0
                guard dis > 0 else { return nil }
                let use = usedByType[key] ?? 0
                return FeedStockSummaryItem(
                    feedType: typeName[key] ?? key, unit: "kg",
                    received: 0, dispatched: dis, used: use,
                    centralStock: 0, sectionStock: max(0, dis - use))
            }
        }
    }

    var body: some View {
        if displayItems.isEmpty {
            EmptyStateView(
                icon: "📦",
                title: "No Stock Data",
                message: isCentral
                    ? "Add central receipts via the Central tab to track stock levels."
                    : "Import feed dispatch data via the web app to see stock balances.")
        } else {
            VStack(spacing: 8) {
                ForEach(displayItems) { item in
                    FeedStockCard(
                        item: item,
                        isCentral: isCentral,
                        master: feedMasters.first(where: {
                            $0.name.lowercased() == item.feedType.lowercased()
                        }),
                        allMasters: feedMasters,
                        isAdmin: isAdmin,
                        onRefresh: onRefresh
                    )
                }
            }.padding(14)
        }
    }
}

private struct FeedStockCard: View {
    let item: FeedStockSummaryItem
    var isCentral: Bool = true
    let master: FeedInventoryItem?
    var allMasters: [FeedInventoryItem] = []
    var isAdmin: Bool = false
    var onRefresh: (() -> Void)? = nil
    @State private var showEdit = false

    var stockKg: Double { isCentral ? item.centralStock : item.sectionStock }

    // Best master match: exact, then contains
    var resolvedMaster: FeedInventoryItem? {
        master ?? allMasters.first(where: {
            $0.name.lowercased().contains(item.feedType.lowercased()) ||
            item.feedType.lowercased().contains($0.name.lowercased())
        })
    }

    var body: some View {
        SBCard {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(stockKg > 0 ? Color.sbPrimaryDim : Color.sbError.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: stockKg > 0 ? "archivebox.fill" : "archivebox")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(stockKg > 0 ? .sbPrimary : .sbError)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.feedType)
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.sbOnSurface)
                    HStack(spacing: 8) {
                        Text(stockKg >= 0 ? "In Stock" : "Over-dispatched")
                            .font(.system(size: 11))
                            .foregroundColor(stockKg >= 0 ? .sbSuccess : .sbError)
                        if isCentral {
                            Text("·").font(.system(size: 11)).foregroundColor(.sbOnSurfaceDim)
                            Text(String(format: "%.1f dispatched", item.dispatched))
                                .font(.system(size: 11)).foregroundColor(.sbOnSurfaceVariant)
                        } else {
                            Text("·").font(.system(size: 11)).foregroundColor(.sbOnSurfaceDim)
                            Text(String(format: "%.1f used", item.used))
                                .font(.system(size: 11)).foregroundColor(.sbOnSurfaceVariant)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(String(format: "%.1f kg", stockKg))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(stockKg >= 0 ? .sbPrimary : .sbError)
                    if let rate = resolvedMaster?.ratePerKg {
                        Text(String(format: "₹%.0f/kg", rate))
                            .font(.system(size: 10)).foregroundColor(.sbOnSurfaceDim)
                    }
                }
                if isAdmin {
                    Button { showEdit = true } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 22)).foregroundColor(.sbPrimary.opacity(0.7))
                    }
                    .buttonStyle(.plain).padding(.leading, 4)
                }
            }
        }
        .sheet(isPresented: $showEdit, onDismiss: { onRefresh?() }) {
            if let m = resolvedMaster {
                EditFeedMasterSheet(master: m)
            } else {
                NavigationView {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle").font(.system(size: 40)).foregroundColor(.sbOnSurfaceVariant)
                        Text("No feed master record found for \"\(item.feedType)\".")
                            .multilineTextAlignment(.center).foregroundColor(.sbOnSurface)
                        Text("Add this feed type via Price List first.")
                            .font(.system(size: 13)).foregroundColor(.sbOnSurfaceVariant)
                    }
                    .padding()
                    .navigationTitle("Edit Feed")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { showEdit = false } } }
                }
            }
        }
    }
}

// MARK: - Central Receipt List

struct CentralReceiptListSection: View {
    let receipts: [CentralReceipt]
    let itemType: String   // "FEED" or "CHEMICAL"
    var isAdmin: Bool = false
    var onRefresh: (() -> Void)? = nil
    var body: some View {
        if receipts.isEmpty {
            EmptyStateView(icon: "🏪", title: "No Central Receipts",
                           message: "Central \(itemType == "FEED" ? "feed" : "chemical") purchases will appear here.")
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(receipts) { CentralReceiptCard(receipt: $0, isAdmin: isAdmin, onRefresh: onRefresh) }
                }.padding(14)
            }
        }
    }
}

struct CentralReceiptCard: View {
    let receipt: CentralReceipt
    var isAdmin: Bool = false
    var onRefresh: (() -> Void)? = nil
    @State private var showEdit = false

    private func shortDate(_ s: String?) -> String {
        guard let s else { return "—" }
        let raw = String(s.prefix(10))
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let out = DateFormatter(); out.dateFormat = "d MMM"
        return fmt.date(from: raw).map { out.string(from: $0) } ?? raw
    }
    var body: some View {
        SBCard {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.sbPrimaryDim).frame(width: 38, height: 38)
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 15, weight: .medium)).foregroundColor(.sbPrimary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(receipt.itemName ?? "—")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.sbOnSurface)
                    HStack(spacing: 6) {
                        if let cat = receipt.category {
                            Text(cat).font(.system(size: 11)).foregroundColor(.sbOnSurfaceVariant)
                        }
                        if let supplier = receipt.supplier {
                            Text("· \(supplier)").font(.system(size: 11)).foregroundColor(.sbOnSurfaceDim)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    if let qty = receipt.qty, let unit = receipt.unit {
                        Text(String(format: "%.1f %@", qty, unit))
                            .font(.system(size: 14, weight: .bold)).foregroundColor(.sbPrimary)
                    }
                    if let total = receipt.totalValue {
                        Text(String(format: "₹%.0f", total))
                            .font(.system(size: 11, weight: .medium)).foregroundColor(.sbSuccess)
                    }
                    Text(shortDate(receipt.date))
                        .font(.system(size: 10)).foregroundColor(.sbOnSurfaceDim)
                }
                if isAdmin {
                    Button { showEdit = true } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 22)).foregroundColor(.sbPrimary.opacity(0.7))
                    }
                    .buttonStyle(.plain).padding(.leading, 4)
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            EditCentralReceiptSheet(receipt: receipt, onSaved: { showEdit = false; onRefresh?() })
        }
    }
}

private struct EditCentralReceiptSheet: View {
    let receipt: CentralReceipt
    var onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var itemName: String
    @State private var qty: String
    @State private var unit: String
    @State private var ratePerUnit: String
    @State private var supplier: String
    @State private var invoiceNo: String
    @State private var notes: String
    @State private var isSaving = false
    @State private var errorMsg: String?

    init(receipt: CentralReceipt, onSaved: @escaping () -> Void) {
        self.receipt = receipt
        self.onSaved = onSaved
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let d = receipt.date.flatMap { df.date(from: String($0.prefix(10))) } ?? Date()
        _date        = State(initialValue: d)
        _itemName    = State(initialValue: receipt.itemName ?? "")
        _qty         = State(initialValue: receipt.qty.map { String(format: "%.1f", $0) } ?? "")
        _unit        = State(initialValue: receipt.unit ?? "")
        _ratePerUnit = State(initialValue: receipt.ratePerUnit.map { String(format: "%.2f", $0) } ?? "")
        _supplier    = State(initialValue: receipt.supplier ?? "")
        _invoiceNo   = State(initialValue: receipt.invoiceNo ?? "")
        _notes       = State(initialValue: receipt.notes ?? "")
    }
    var body: some View {
        NavigationView {
            Form {
                Section("Receipt") {
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                    TextField("Item Name", text: $itemName)
                    TextField("Qty", text: $qty).keyboardType(.decimalPad)
                    TextField("Unit", text: $unit)
                    TextField("Rate/Unit", text: $ratePerUnit).keyboardType(.decimalPad)
                }
                Section("Details") {
                    TextField("Supplier", text: $supplier)
                    TextField("Invoice No.", text: $invoiceNo)
                    TextField("Notes", text: $notes)
                }
                if let err = errorMsg {
                    Section { Text(err).foregroundColor(.red).font(.system(size: 12)) }
                }
            }
            .navigationTitle("Edit Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(isSaving)
                }
            }
            .overlay { if isSaving { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.black.opacity(0.15)) } }
        }
    }
    private func save() async {
        isSaving = true; defer { isSaving = false }
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let body = UpdateCentralReceiptRequest(
            date: df.string(from: date),
            itemName: itemName.isEmpty ? nil : itemName,
            qty: Double(qty),
            unit: unit.isEmpty ? nil : unit,
            ratePerUnit: Double(ratePerUnit),
            supplier: supplier.isEmpty ? nil : supplier,
            invoiceNo: invoiceNo.isEmpty ? nil : invoiceNo,
            notes: notes.isEmpty ? nil : notes
        )
        do {
            _ = try await APIService.shared.updateCentralReceipt(id: receipt.id, body)
            onSaved()
        } catch { errorMsg = "Save failed: \(error.localizedDescription)" }
    }
}

// MARK: - Add Central Receipt Sheet

struct AddCentralReceiptSheet: View {
    @Environment(\.dismiss) var dismiss
    let itemType: String         // "FEED" or "CHEMICAL"
    let itemNames: [String]      // suggestions from masters

    @State private var selectedName = ""
    @State private var qty = ""
    @State private var unit = "kg"
    @State private var ratePerUnit = ""
    @State private var supplier = ""
    @State private var invoiceNo = ""
    @State private var notes = ""
    @State private var date: Date = Date()
    @State private var isLoading = false
    @State private var errorMsg: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.sbSurface.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        SBCard {
                            VStack(spacing: 14) {

                                // Item name picker / text
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("ITEM NAME").font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.sbOnSurfaceVariant)
                                    if itemNames.isEmpty {
                                        SBTextField(label: "", text: $selectedName,
                                                    placeholder: "e.g. Starter Feed")
                                    } else {
                                        Picker("Item", selection: $selectedName) {
                                            Text("Select Item").tag("")
                                            ForEach(itemNames, id: \.self) { n in
                                                Text(n).tag(n)
                                            }
                                        }
                                        .tint(.sbPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }

                                Divider().background(Color.sbOutline)

                                HStack(spacing: 12) {
                                    SBTextField(label: "Quantity", text: $qty,
                                                placeholder: "100", keyboardType: .decimalPad)
                                    SBTextField(label: "Unit", text: $unit, placeholder: "kg")
                                }
                                SBTextField(label: "Rate per Unit (optional)", text: $ratePerUnit,
                                            placeholder: "₹ per unit", keyboardType: .decimalPad)
                                SBTextField(label: "Supplier (optional)", text: $supplier,
                                            placeholder: "Supplier name")
                                SBTextField(label: "Invoice No (optional)", text: $invoiceNo,
                                            placeholder: "INV-001")
                                SBTextField(label: "Notes (optional)", text: $notes,
                                            placeholder: "Any notes")

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("DATE").font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.sbOnSurfaceVariant)
                                    DatePicker("", selection: $date, in: ...Date(),
                                               displayedComponents: .date)
                                        .labelsHidden()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .tint(.sbPrimary)
                                }
                            }
                        }

                        if let err = errorMsg {
                            Text(err).font(.system(size: 12)).foregroundColor(.sbError)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4)
                        }

                        SBPrimaryButton("Add to Central Store", isLoading: isLoading) {
                            guard !selectedName.isEmpty else {
                                errorMsg = "Please enter item name."; return
                            }
                            guard let q = Double(qty), q > 0 else {
                                errorMsg = "Enter a valid quantity."; return
                            }
                            guard !unit.trimmingCharacters(in: .whitespaces).isEmpty else {
                                errorMsg = "Enter a unit (e.g. kg, L)."; return
                            }
                            errorMsg = nil
                            Task {
                                isLoading = true
                                let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
                                let rate = Double(ratePerUnit)
                                let total = rate.map { $0 * q }
                                try? await APIService.shared.createCentralReceipt(CentralReceiptRequest(
                                    itemType: itemType,
                                    itemName: selectedName,
                                    qty: q,
                                    unit: unit,
                                    date: fmt.string(from: date),
                                    category: nil,
                                    ratePerUnit: rate,
                                    supplier: supplier.isEmpty ? nil : supplier,
                                    invoiceNo: invoiceNo.isEmpty ? nil : invoiceNo,
                                    notes: notes.isEmpty ? nil : notes))
                                _ = total  // suppress unused warning
                                await MainActor.run { dismiss() }
                            }
                        }

                        Spacer(minLength: 30)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Add Central Receipt").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }.foregroundColor(.sbSecondary)
            }}
            .onAppear {
                if selectedName.isEmpty, let first = itemNames.first {
                    selectedName = first
                }
            }
        }
    }
}

struct FeedLogCard: View {
    let log: FeedLog
    var isAdmin: Bool = false
    var onRefresh: (() -> Void)? = nil
    @State private var showEdit = false

    var body: some View {
        SBCard {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.sbPrimaryDim).frame(width: 38, height: 38)
                    Image(systemName: "fork.knife")
                        .font(.system(size: 15, weight: .medium)).foregroundColor(.sbPrimary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(log.pondLabel ?? log.pondId ?? "—")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.sbOnSurface)
                    Text(log.feedType ?? "Feed")
                        .font(.system(size: 11)).foregroundColor(.sbOnSurfaceVariant)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    if let kg = log.totalKg {
                        Text(String(format: "%.1f kg", kg))
                            .font(.system(size: 14, weight: .bold)).foregroundColor(.sbPrimary)
                    }
                    Text(shortDate(log.date))
                        .font(.system(size: 10)).foregroundColor(.sbOnSurfaceDim)
                }
                if isAdmin {
                    Button { showEdit = true } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.sbPrimary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            EditFeedLogSheet(log: log, onSaved: { showEdit = false; onRefresh?() })
        }
    }
    private func shortDate(_ s: String?) -> String {
        guard let s else { return "—" }
        let raw = String(s.prefix(10))
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let out = DateFormatter(); out.dateFormat = "d MMM"
        return fmt.date(from: raw).map { out.string(from: $0) } ?? raw
    }
}

struct EditFeedLogSheet: View {
    let log: FeedLog
    var onSaved: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var date: String
    @State private var feedType: String
    @State private var totalKg: String
    @State private var notes: String
    @State private var isSaving = false
    @State private var errorMsg: String? = nil

    init(log: FeedLog, onSaved: @escaping () -> Void) {
        self.log = log
        self.onSaved = onSaved
        _date     = State(initialValue: String((log.date ?? "").prefix(10)))
        _feedType = State(initialValue: log.feedType ?? "")
        _totalKg  = State(initialValue: log.totalKg.map { String(format: "%.1f", $0) } ?? "")
        _notes    = State(initialValue: "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Feed Log Details") {
                    HStack {
                        Text("Pond").foregroundColor(.sbOnSurfaceVariant)
                        Spacer()
                        Text(log.pondLabel ?? log.pondId ?? "—").foregroundColor(.sbOnSurface)
                    }
                    HStack {
                        Text("Date")
                        Spacer()
                        TextField("yyyy-MM-dd", text: $date)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numbersAndPunctuation)
                    }
                    HStack {
                        Text("Feed Type")
                        Spacer()
                        TextField("e.g. Titan 3SP", text: $feedType)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Total (kg)")
                        Spacer()
                        TextField("0.0", text: $totalKg)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    TextField("Notes (optional)", text: $notes)
                }
                if let err = errorMsg {
                    Section { Text(err).foregroundColor(.red).font(.system(size: 13)) }
                }
            }
            .navigationTitle("Edit Feed Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.sbPrimaryLight)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { Task { await save() } }
                        .fontWeight(.semibold)
                        .foregroundColor(.sbPrimary)
                        .disabled(isSaving)
                }
            }
        }
    }

    private func save() async {
        guard let kg = Double(totalKg), kg > 0 else { errorMsg = "Enter a valid quantity."; return }
        isSaving = true
        let body = UpdateFeedLogRequest(date: date.isEmpty ? nil : date,
                                        feedType: feedType.isEmpty ? nil : feedType,
                                        totalKg: kg,
                                        feed1Kg: kg,
                                        notes: notes.isEmpty ? nil : notes)
        if (try? await APIService.shared.updateFeedLog(id: log.id, body)) != nil {
            await MainActor.run { onSaved() }
        } else {
            await MainActor.run { errorMsg = "Failed to save. Please try again."; isSaving = false }
        }
    }
}

private struct FeedDispatchListSection: View {
    let dispatches: [FeedDispatch]; let sections: [FarmSection]
    var isAdmin: Bool = false
    var onRefresh: (() -> Void)? = nil
    var body: some View {
        if dispatches.isEmpty {
            EmptyStateView(icon: "📦", title: "No Dispatches",
                           message: "No dispatches found for the selected filters.")
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(dispatches) { FeedDispatchCard(dispatch: $0, sections: sections, isAdmin: isAdmin, onRefresh: onRefresh) }
                }.padding(14)
            }
        }
    }
}

struct FeedDispatchCard: View {
    let dispatch: FeedDispatch; let sections: [FarmSection]
    var isAdmin: Bool = false
    var onRefresh: (() -> Void)? = nil
    @State private var showEdit = false

    var sectionDisplay: String {
        dispatch.sectionName ?? dispatch.sectionCode
            ?? sections.first { $0.id == dispatch.sectionId }?.name
            ?? dispatch.sectionId ?? "—"
    }
    private func shortDate(_ s: String?) -> String {
        guard let s else { return "—" }
        let raw = String(s.prefix(10))
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let out = DateFormatter(); out.dateFormat = "d MMM"
        return fmt.date(from: raw).map { out.string(from: $0) } ?? raw
    }
    var body: some View {
        SBCard {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.sbPrimaryDim).frame(width: 38, height: 38)
                    Image(systemName: "archivebox")
                        .font(.system(size: 15, weight: .medium)).foregroundColor(.sbPrimary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(sectionDisplay)
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.sbOnSurface)
                    HStack(spacing: 6) {
                        if let ft = dispatch.feedType {
                            Text(ft).font(.system(size: 11)).foregroundColor(.sbOnSurfaceVariant)
                        }
                        if let b = dispatch.bags {
                            Text("· \(b) bags").font(.system(size: 11)).foregroundColor(.sbOnSurfaceDim)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    if let kg = dispatch.qtyKg {
                        Text(String(format: "%.1f kg", kg))
                            .font(.system(size: 14, weight: .bold)).foregroundColor(.sbPrimary)
                    }
                    Text(shortDate(dispatch.date))
                        .font(.system(size: 10)).foregroundColor(.sbOnSurfaceDim)
                }
                if isAdmin {
                    Button { showEdit = true } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 22)).foregroundColor(.sbPrimary.opacity(0.7))
                    }
                    .buttonStyle(.plain).padding(.leading, 4)
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            EditFeedDispatchSheet(dispatch: dispatch, onSaved: { showEdit = false; onRefresh?() })
        }
    }
}

private struct EditFeedDispatchSheet: View {
    let dispatch: FeedDispatch
    var onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var feedType: String
    @State private var qtyKg: String
    @State private var bags: String
    @State private var ratePerKg: String
    @State private var receivedBy: String
    @State private var notes: String
    @State private var isSaving = false
    @State private var errorMsg: String?

    init(dispatch: FeedDispatch, onSaved: @escaping () -> Void) {
        self.dispatch = dispatch
        self.onSaved = onSaved
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let d = dispatch.date.flatMap { df.date(from: String($0.prefix(10))) } ?? Date()
        _date = State(initialValue: d)
        _feedType    = State(initialValue: dispatch.feedType ?? "")
        _qtyKg       = State(initialValue: dispatch.qtyKg.map { String(format: "%.1f", $0) } ?? "")
        _bags        = State(initialValue: dispatch.bags.map { String($0) } ?? "")
        _ratePerKg   = State(initialValue: dispatch.ratePerKg.map { String(format: "%.2f", $0) } ?? "")
        _receivedBy  = State(initialValue: dispatch.receivedBy ?? "")
        _notes       = State(initialValue: dispatch.notes ?? "")
    }
    var body: some View {
        NavigationView {
            Form {
                Section("Dispatch") {
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                    TextField("Feed Type", text: $feedType)
                    TextField("Qty (kg)", text: $qtyKg).keyboardType(.decimalPad)
                    TextField("Bags", text: $bags).keyboardType(.numberPad)
                    TextField("Rate/kg", text: $ratePerKg).keyboardType(.decimalPad)
                }
                Section("Details") {
                    TextField("Received By", text: $receivedBy)
                    TextField("Notes", text: $notes)
                }
                if let err = errorMsg {
                    Section { Text(err).foregroundColor(.red).font(.system(size: 12)) }
                }
            }
            .navigationTitle("Edit Dispatch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(isSaving)
                }
            }
            .overlay { if isSaving { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.black.opacity(0.15)) } }
        }
    }
    private func save() async {
        isSaving = true; defer { isSaving = false }
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let body = UpdateFeedDispatchRequest(
            date: df.string(from: date),
            feedType: feedType.isEmpty ? nil : feedType,
            qtyKg: Double(qtyKg),
            bags: Int(bags),
            ratePerKg: Double(ratePerKg),
            receivedBy: receivedBy.isEmpty ? nil : receivedBy,
            notes: notes.isEmpty ? nil : notes
        )
        do {
            _ = try await APIService.shared.updateFeedDispatch(id: dispatch.id, body)
            onSaved()
        } catch { errorMsg = "Save failed: \(error.localizedDescription)" }
    }
}
