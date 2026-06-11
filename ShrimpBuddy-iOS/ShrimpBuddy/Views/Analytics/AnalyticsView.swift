import SwiftUI
import Charts

// MARK: - Analytics Root View

struct AnalyticsView: View {
    var isAdmin: Bool { TokenStore.shared.isAdmin }
    var sections: [String] { isAdmin ? ["Finance", "Pond Analytics"] : ["Pond Analytics"] }
    @State private var activeSection = ""

    var body: some View {
        VStack(spacing: 0) {
            SBAppHeader(title: "Analytics", subtitle: "Expenses & pond performance")
            SBSectionPillTabs(sections: sections, selected: $activeSection)

            Group {
                if activeSection == "Finance" {
                    FinanceAnalyticsView()
                } else {
                    PondAnalyticsView()
                }
            }
        }
        .background(Color.sbBg.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            if activeSection.isEmpty || (!isAdmin && activeSection == "Finance") {
                activeSection = sections.first ?? "Pond Analytics"
            }
        }
    }
}

// MARK: - Finance Analytics

struct FinanceAnalyticsView: View {
    @State private var feedDispatches: [FeedDispatch] = []
    @State private var feedMaster: [FeedMasterRecord] = []
    @State private var chemDispatches: [ChemicalDispatchRecord] = []
    @State private var chemMaster: [ChemicalMasterRecord] = []
    @State private var farmExpenses: [FarmExpense] = []
    @State private var isLoading = true
    @State private var activeTab = "Feed"
    @State private var showAddExpense = false

    let tabs = ["Feed", "Chemical", "Other"]

    // ── rate lookup maps ──
    var feedRateMap: [String: Double] {
        var m: [String: Double] = [:]
        feedMaster.filter { $0.isActive }.forEach { m[$0.name.lowercased()] = $0.ratePerKg }
        return m
    }
    var chemRateMap: [String: Double] {
        var m: [String: Double] = [:]
        chemMaster.filter { $0.isActive }.forEach { m[$0.name.lowercased()] = $0.ratePerUnit }
        return m
    }

    // ── feed expense rows ──
    // Always prefer master rate so updating the price list immediately reflects in finance
    var feedExpenseRows: [(feedType: String, totalKg: Double, ratePerKg: Double, cost: Double)] {
        var grouped: [String: (feedType: String, totalKg: Double, ratePerKg: Double, cost: Double)] = [:]
        for d in feedDispatches {
            guard let ft = d.feedType, !ft.isEmpty else { continue }
            let qty  = d.qtyKg ?? 0
            let key  = ft.lowercased()
            // Master rate takes priority → price list changes immediately update finance
            let rate = feedRateMap[key] ?? d.ratePerKg ?? 0
            if var e = grouped[key] {
                e.totalKg += qty
                e.cost    += qty * rate
                grouped[key] = e
            } else {
                grouped[key] = (ft, qty, rate, qty * rate)
            }
        }
        // Ensure active master items appear even with no dispatches
        for f in feedMaster where f.isActive {
            let key = f.name.lowercased()
            if grouped[key] == nil {
                grouped[key] = (f.name, 0, f.ratePerKg, 0)
            }
        }
        return grouped.values.sorted { $0.feedType < $1.feedType }
    }

    var totalFeedCost: Double { feedExpenseRows.reduce(0) { $0 + $1.cost } }

    // ── chemical expense rows ──
    // Always prefer master rate so updating the price list immediately reflects in finance
    var chemExpenseRows: [(chemName: String, totalQty: Double, unit: String, ratePerUnit: Double, cost: Double)] {
        var grouped: [String: (chemName: String, totalQty: Double, unit: String, ratePerUnit: Double, cost: Double)] = [:]
        for d in chemDispatches {
            let key = d.chemicalName.lowercased()
            // Master rate takes priority → price list changes immediately update finance
            let rate = chemRateMap[key] ?? d.ratePerUnit ?? 0
            if var e = grouped[key] {
                e.totalQty += d.qtyDispatched
                e.cost += d.qtyDispatched * rate
                grouped[key] = e
            } else {
                grouped[key] = (d.chemicalName, d.qtyDispatched, d.unit, rate, d.qtyDispatched * rate)
            }
        }
        for c in chemMaster where c.isActive {
            let key = c.name.lowercased()
            if grouped[key] == nil {
                grouped[key] = (c.name, 0, c.unit, c.ratePerUnit, 0)
            }
        }
        return grouped.values.sorted { $0.chemName < $1.chemName }
    }

    var totalChemCost: Double { chemExpenseRows.reduce(0) { $0 + $1.cost } }
    var totalOtherCost: Double { farmExpenses.reduce(0) { $0 + $1.amount } }
    var grandTotal: Double { totalFeedCost + totalChemCost + totalOtherCost }

    var body: some View {
        Group {
        if isLoading {
            Spacer()
            ProgressView().tint(.sbPrimary)
            Spacer()
        } else {
            ScrollView {
                VStack(spacing: 14) {

                    // ── Grand Total Hero ──────────────────────────────────────
                    SBCard(elevated: true) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("TOTAL EXPENSES")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.sbOnSurfaceVariant).kerning(0.6)
                            Text(formatCurrency(grandTotal))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.sbOnSurface)
                            Text("Feed + Chemical + Other")
                                .font(.system(size: 12)).foregroundColor(.sbOnSurfaceVariant)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // ── 3 cost tiles ──────────────────────────────────────────
                    HStack(spacing: 8) {
                        CostTile(label: "Feed", value: totalFeedCost, color: .sbPrimary)
                        CostTile(label: "Chemical", value: totalChemCost, color: Color(hex: "#9b59b6"))
                        CostTile(label: "Other", value: totalOtherCost, color: .sbSuccess)
                    }

                    // ── Donut breakdown ───────────────────────────────────────
                    if grandTotal > 0 {
                        SBCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("EXPENSE BREAKDOWN")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.sbOnSurfaceVariant).kerning(0.5)

                                // Simple bar chart via SwiftUI Charts
                                let items: [(label: String, value: Double, color: Color)] = [
                                    ("Feed", totalFeedCost, .sbPrimary),
                                    ("Chemical", totalChemCost, Color(hex: "#9b59b6")),
                                    ("Other", totalOtherCost, .sbSuccess)
                                ].filter { $0.value > 0 }

                                Chart(items, id: \.label) { item in
                                    BarMark(
                                        x: .value("Category", item.label),
                                        y: .value("Amount", item.value)
                                    )
                                    .foregroundStyle(item.color)
                                    .cornerRadius(6)
                                    .annotation(position: .top) {
                                        Text("₹\(Int(item.value / 1000))k")
                                            .font(.system(size: 9))
                                            .foregroundColor(.sbOnSurfaceVariant)
                                    }
                                }
                                .chartXAxis {
                                    AxisMarks { _ in
                                        AxisValueLabel().font(.system(size: 9))
                                            .foregroundStyle(Color.sbOnSurfaceVariant)
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks(position: .leading) { _ in
                                        AxisValueLabel().font(.system(size: 9))
                                            .foregroundStyle(Color.sbOnSurfaceVariant)
                                        AxisGridLine(stroke: StrokeStyle(dash: [3, 4]))
                                            .foregroundStyle(Color.sbOutline)
                                    }
                                }
                                .frame(height: 160)

                                // Percentage breakdown legend
                                VStack(spacing: 6) {
                                    ForEach([
                                        ("Feed", totalFeedCost, Color.sbPrimary),
                                        ("Chemical", totalChemCost, Color(hex: "#9b59b6")),
                                        ("Other", totalOtherCost, Color.sbSuccess)
                                    ], id: \.0) { label, value, color in
                                        HStack {
                                            Circle().fill(color).frame(width: 8, height: 8)
                                            Text(label)
                                                .font(.system(size: 11)).foregroundColor(.sbOnSurfaceVariant)
                                            Spacer()
                                            Text(formatCurrency(value))
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(.sbOnSurface)
                                            Text(grandTotal > 0 ? "(\(Int((value / grandTotal) * 100))%)" : "")
                                                .font(.system(size: 10)).foregroundColor(.sbOnSurfaceDim)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Sub-tabs: Feed / Chemical / Other ─────────────────────
                    HStack(spacing: 4) {
                        ForEach(tabs, id: \.self) { tab in
                            Button(action: { withAnimation { activeTab = tab } }) {
                                Text(tab)
                                    .font(.system(size: 12, weight: activeTab == tab ? .bold : .medium))
                                    .foregroundColor(activeTab == tab ? .white : .sbOnSurfaceVariant)
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .background(activeTab == tab ? Color.sbPrimary : Color.sbSurfaceElevated)
                                    .cornerRadius(18)
                                    .overlay(RoundedRectangle(cornerRadius: 18)
                                        .stroke(activeTab == tab ? Color.clear : Color.sbOutline, lineWidth: 0.8))
                            }
                        }
                        Spacer()
                    }

                    // ── Feed Expenses table ───────────────────────────────────
                    if activeTab == "Feed" {
                        SBCard {
                            VStack(alignment: .leading, spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Feed Expenses")
                                        .font(.system(size: 15, weight: .bold)).foregroundColor(.sbOnSurface)
                                    Text("Calculated from feed dispatches × price list rates")
                                        .font(.system(size: 11)).foregroundColor(.sbOnSurfaceVariant)
                                }
                                Divider().background(Color.sbOutline)
                                if feedExpenseRows.isEmpty {
                                    EmptyStateView(icon: "🌾", title: "No Feed Data",
                                                   message: "Dispatch feed to sections to see expenses.")
                                        .frame(height: 120)
                                } else {
                                    VStack(spacing: 0) {
                                        // Header
                                        HStack {
                                            Text("Feed Type").frame(maxWidth: .infinity, alignment: .leading)
                                            Text("Qty (kg)").frame(width: 70, alignment: .trailing)
                                            Text("Rate").frame(width: 60, alignment: .trailing)
                                            Text("Cost").frame(width: 70, alignment: .trailing)
                                        }
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.sbOnSurfaceDim)
                                        .padding(.vertical, 6)

                                        ForEach(feedExpenseRows, id: \.feedType) { row in
                                            Divider().background(Color.sbOutline)
                                            HStack {
                                                Text(row.feedType)
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundColor(.sbOnSurface)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                Text(row.totalKg == 0 ? "—" : String(format: "%.1f", row.totalKg))
                                                    .font(.system(size: 12)).foregroundColor(.sbOnSurfaceVariant)
                                                    .frame(width: 70, alignment: .trailing)
                                                Text(row.ratePerKg == 0 ? "—" : "₹\(Int(row.ratePerKg))")
                                                    .font(.system(size: 11)).foregroundColor(.sbOnSurfaceVariant)
                                                    .frame(width: 60, alignment: .trailing)
                                                Text(row.cost == 0 ? "₹0" : formatCurrency(row.cost))
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(row.cost == 0 ? .sbOnSurfaceDim : .sbPrimary)
                                                    .frame(width: 70, alignment: .trailing)
                                            }
                                            .padding(.vertical, 8)
                                        }

                                        Divider().background(Color.sbOutline)
                                        HStack {
                                            Text("Total Feed Cost")
                                                .font(.system(size: 12, weight: .bold)).foregroundColor(.sbOnSurface)
                                            Spacer()
                                            Text(formatCurrency(totalFeedCost))
                                                .font(.system(size: 13, weight: .bold)).foregroundColor(.sbPrimary)
                                        }
                                        .padding(.vertical, 8)
                                        .background(Color.sbSurfaceElevated)
                                        .cornerRadius(8)
                                        .padding(.top, 2)
                                    }
                                }
                            }
                        }
                    }

                    // ── Chemical Expenses table ───────────────────────────────
                    if activeTab == "Chemical" {
                        SBCard {
                            VStack(alignment: .leading, spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Chemical Expenses")
                                        .font(.system(size: 15, weight: .bold)).foregroundColor(.sbOnSurface)
                                    Text("Calculated from chemical dispatches × price list rates")
                                        .font(.system(size: 11)).foregroundColor(.sbOnSurfaceVariant)
                                }
                                Divider().background(Color.sbOutline)
                                if chemExpenseRows.isEmpty {
                                    EmptyStateView(icon: "🧪", title: "No Chemical Data",
                                                   message: "Dispatch chemicals to sections to see expenses.")
                                        .frame(height: 120)
                                } else {
                                    VStack(spacing: 0) {
                                        HStack {
                                            Text("Chemical").frame(maxWidth: .infinity, alignment: .leading)
                                            Text("Qty").frame(width: 70, alignment: .trailing)
                                            Text("Rate").frame(width: 60, alignment: .trailing)
                                            Text("Cost").frame(width: 70, alignment: .trailing)
                                        }
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.sbOnSurfaceDim)
                                        .padding(.vertical, 6)

                                        ForEach(chemExpenseRows, id: \.chemName) { row in
                                            Divider().background(Color.sbOutline)
                                            HStack {
                                                Text(row.chemName)
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundColor(.sbOnSurface)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                Text(row.totalQty == 0 ? "—" : "\(String(format: "%.1f", row.totalQty)) \(row.unit)")
                                                    .font(.system(size: 11)).foregroundColor(.sbOnSurfaceVariant)
                                                    .frame(width: 70, alignment: .trailing)
                                                Text(row.ratePerUnit == 0 ? "—" : "₹\(Int(row.ratePerUnit))")
                                                    .font(.system(size: 11)).foregroundColor(.sbOnSurfaceVariant)
                                                    .frame(width: 60, alignment: .trailing)
                                                Text(row.cost == 0 ? "₹0" : formatCurrency(row.cost))
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(row.cost == 0 ? .sbOnSurfaceDim : Color(hex: "#9b59b6"))
                                                    .frame(width: 70, alignment: .trailing)
                                            }
                                            .padding(.vertical, 8)
                                        }

                                        Divider().background(Color.sbOutline)
                                        HStack {
                                            Text("Total Chemical Cost")
                                                .font(.system(size: 12, weight: .bold)).foregroundColor(.sbOnSurface)
                                            Spacer()
                                            Text(formatCurrency(totalChemCost))
                                                .font(.system(size: 13, weight: .bold)).foregroundColor(Color(hex: "#9b59b6"))
                                        }
                                        .padding(.vertical, 8)
                                        .background(Color.sbSurfaceElevated)
                                        .cornerRadius(8)
                                        .padding(.top, 2)
                                    }
                                }
                            }
                        }
                    }

                    // ── Other Expenses table ──────────────────────────────────
                    if activeTab == "Other" {
                        SBCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Other Expenses")
                                            .font(.system(size: 15, weight: .bold)).foregroundColor(.sbOnSurface)
                                        Text("Manually added farm expenses")
                                            .font(.system(size: 11)).foregroundColor(.sbOnSurfaceVariant)
                                    }
                                    Spacer()
                                    Button(action: { showAddExpense = true }) {
                                        Text("+ Add")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.sbPrimaryLight)
                                            .padding(.horizontal, 12).padding(.vertical, 6)
                                            .background(Color.sbPrimaryDim)
                                            .cornerRadius(8)
                                    }
                                }
                                Divider().background(Color.sbOutline)
                                if farmExpenses.isEmpty {
                                    EmptyStateView(icon: "💸", title: "No Other Expenses",
                                                   message: "Tap + Add to record a farm expense.")
                                        .frame(height: 120)
                                } else {
                                    VStack(spacing: 0) {
                                        ForEach(farmExpenses.sorted { $0.date > $1.date }) { exp in
                                            OtherExpenseRow(exp: exp, onDelete: {
                                                Task { try? await APIService.shared.deleteFarmExpense(id: exp.id); await loadData() }
                                            })
                                        }
                                        Divider().background(Color.sbOutline)
                                        HStack {
                                            Text("Total Other Expenses")
                                                .font(.system(size: 12, weight: .bold)).foregroundColor(.sbOnSurface)
                                            Spacer()
                                            Text(formatCurrency(totalOtherCost))
                                                .font(.system(size: 13, weight: .bold)).foregroundColor(.sbSuccess)
                                        }
                                        .padding(.vertical, 8)
                                        .background(Color.sbSurfaceElevated)
                                        .cornerRadius(8)
                                        .padding(.top, 2)
                                    }
                                }
                            }
                        }
                    }

                }
                .padding(14)
            }
        }
        } // end Group
        .onAppear { Task { await loadData() } }   // reload every time tab is revisited (catches price changes)
        .sheet(isPresented: $showAddExpense, onDismiss: { Task { await loadData() } }) {
            AddFarmExpenseSheet()
        }
    }

    private func loadData() async {
        isLoading = true
        async let fd = APIService.shared.getFeedDispatches()
        async let fm = APIService.shared.getFeedMaster()
        async let cd = APIService.shared.getChemicalDispatches()
        async let cm = APIService.shared.getChemicalMaster()
        async let fe = APIService.shared.getFarmExpenses()
        let feedD = try? await fd
        let feedM = try? await fm
        let chemD = try? await cd
        let chemM = try? await cm
        let farmE = try? await fe
        await MainActor.run {
            feedDispatches = feedD ?? []
            feedMaster     = feedM ?? []
            chemDispatches = chemD ?? []
            chemMaster     = chemM ?? []
            farmExpenses   = farmE ?? []
            isLoading = false
        }
    }

    private func formatCurrency(_ v: Double) -> String {
        "₹\(Int(v).formatted(.number))"
    }
}

struct CostTile: View {
    let label: String; let value: Double; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(value < 1000 ? "₹\(Int(value))" : "₹\(Int(value / 1000))k")
                .font(.system(size: 15, weight: .bold)).foregroundColor(color)
            Text(label)
                .font(.system(size: 10, weight: .medium)).foregroundColor(.sbOnSurfaceVariant)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(Color.sbSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sbOutline, lineWidth: 0.8))
    }
}

struct OtherExpenseRow: View {
    let exp: FarmExpense
    let onDelete: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exp.description.isEmpty ? "Untitled" : exp.description)
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.sbOnSurface)
                    Text("\(exp.date)\(exp.reference.map { " · \($0)" } ?? "")")
                        .font(.system(size: 10)).foregroundColor(.sbOnSurfaceVariant)
                }
                Spacer()
                Text("₹\(Int(exp.amount).formatted(.number))")
                    .font(.system(size: 12, weight: .bold)).foregroundColor(.sbSuccess)
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12)).foregroundColor(.sbError)
                        .padding(6)
                        .background(Color.sbErrorBg).cornerRadius(6)
                }
            }
            .padding(.vertical, 8)
            Divider().background(Color.sbOutline)
        }
    }
}

// MARK: - Add Farm Expense Sheet

struct AddFarmExpenseSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var date = todayIso()
    @State private var description = ""
    @State private var amount = ""
    @State private var reference = ""
    @State private var notes = ""
    @State private var isLoading = false
    @State private var errorMsg = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.sbBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        if !errorMsg.isEmpty {
                            Text(errorMsg)
                                .font(.system(size: 12)).foregroundColor(.sbError)
                                .padding(10).background(Color.sbErrorBg).cornerRadius(8)
                        }
                        SBTextField(label: "Description", text: $description,
                                    placeholder: "e.g. Electricity bill, Labour wages")
                        HStack(spacing: 12) {
                            SBTextField(label: "Date (YYYY-MM-DD)", text: $date,
                                        placeholder: "2025-01-15")
                            SBTextField(label: "Amount (₹)", text: $amount,
                                        placeholder: "e.g. 12000", keyboardType: .decimalPad)
                        }
                        HStack(spacing: 12) {
                            SBTextField(label: "Reference", text: $reference,
                                        placeholder: "Bill/receipt no.")
                            SBTextField(label: "Notes", text: $notes,
                                        placeholder: "Additional details")
                        }
                        SBPrimaryButton("Save Expense", isLoading: isLoading) {
                            Task { await save() }
                        }
                        Spacer()
                    }.padding(20)
                }
            }
            .navigationTitle("Add Expense").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }.foregroundColor(.sbPrimaryLight)
            }}
            .preferredColorScheme(.dark)
        }
    }

    private func save() async {
        guard !description.isEmpty, let amt = Double(amount), amt > 0 else {
            errorMsg = "Please enter a description and valid amount."; return
        }
        isLoading = true; errorMsg = ""
        let req = CreateFarmExpenseRequest(
            date: date.isEmpty ? todayIso() : date,
            description: description,
            amount: amt,
            reference: reference.isEmpty ? nil : reference,
            notes: notes.isEmpty ? nil : notes)
        do {
            _ = try await APIService.shared.createFarmExpense(req)
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run { errorMsg = error.localizedDescription; isLoading = false }
        }
    }
}

// MARK: - Pond Analytics

struct PondAnalyticsView: View {
    @State private var ponds: [Pond] = []
    @State private var sections: [FarmSection] = []
    @State private var samplingLogs: [SamplingLog] = []
    @State private var dashboard: DashboardStats? = nil
    @State private var isLoading = true
    @State private var selectedSection = "All"

    var sectionNames: [String] { ["All"] + sections.map(\.name) }

    var filteredPonds: [Pond] {
        if selectedSection == "All" { return ponds }
        // Match by sectionId (reliable) or fall back to sectionName
        if let sectionId = sections.first(where: { $0.name == selectedSection })?.id {
            return ponds.filter { $0.sectionId == sectionId }
        }
        return ponds.filter { ($0.sectionName ?? "") == selectedSection }
    }

    var avgABW: Double {
        let active = filteredPonds.filter { ($0.status ?? "") != "HARVESTED" }
        guard !active.isEmpty else { return 0 }
        return active.reduce(0) { $0 + ($1.abw ?? 0) } / Double(active.count)
    }

    var avgSurvival: Double {
        let active = filteredPonds.filter { ($0.status ?? "") != "HARVESTED" }
        guard !active.isEmpty else { return 0 }
        return active.reduce(0) { $0 + ($1.survivalPct ?? 0) } / Double(active.count)
    }

    var avgDOC: Double {
        let active = filteredPonds.filter { ($0.status ?? "") != "HARVESTED" }
        guard !active.isEmpty else { return 0 }
        return active.reduce(0) { $0 + Double($1.doc ?? 0) } / Double(active.count)
    }

    var totalBiomass: Double {
        filteredPonds.reduce(0) { $0 + (($1.abw ?? 0) / 1000.0) * Double($1.seedCount ?? 0) * (($1.survivalPct ?? 0) / 100.0) }
    }

    var statusCounts: (stable: Int, attention: Int, critical: Int) {
        let p = filteredPonds
        return (
            stable: p.filter { ($0.status ?? "STABLE") == "STABLE" }.count,
            attention: p.filter { $0.status == "ATTENTION" }.count,
            critical: p.filter { $0.status == "CRITICAL" }.count
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Section filter pills (liquid glass)
            if sections.count > 0 {
                SBSectionPillTabs(sections: sectionNames, selected: $selectedSection)
            }

            if isLoading {
                Spacer(); ProgressView().tint(.sbPrimary); Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 14) {

                        // ── Summary Metrics ───────────────────────────────────
                        HStack(spacing: 8) {
                            SBMetricTile(value: "\(filteredPonds.count)", label: "Active Ponds", color: .sbPrimary)
                            SBMetricTile(value: String(format: "%.1fg", avgABW), label: "Avg ABW", color: .sbPrimaryLight)
                            SBMetricTile(value: String(format: "%.0f%%", avgSurvival), label: "Avg Survival", color: .sbSuccess)
                        }

                        HStack(spacing: 8) {
                            SBMetricTile(value: String(format: "%.0fd", avgDOC), label: "Avg DOC", color: .sbWarning)
                            SBMetricTile(value: String(format: "%.0f kg", totalBiomass), label: "Biomass Est.", color: .sbInfo)
                            SBMetricTile(value: "\(statusCounts.critical)🔴", label: "Critical Ponds", color: .sbError)
                        }

                        // ── Status distribution ───────────────────────────────
                        SBCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("POND STATUS DISTRIBUTION")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.sbOnSurfaceVariant).kerning(0.5)

                                HStack(spacing: 8) {
                                    StatusDistBar(label: "Stable", count: statusCounts.stable,
                                                  total: filteredPonds.count, color: .sbSuccess)
                                    StatusDistBar(label: "Attention", count: statusCounts.attention,
                                                  total: filteredPonds.count, color: .sbWarning)
                                    StatusDistBar(label: "Critical", count: statusCounts.critical,
                                                  total: filteredPonds.count, color: .sbError)
                                }
                            }
                        }

                        // ── Section Health cards ──────────────────────────────
                        if let dash = dashboard, !dash.sectionHealth.isEmpty {
                            SBCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("SECTION HEALTH")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.sbOnSurfaceVariant).kerning(0.5)

                                    ForEach(dash.sectionHealth) { sec in
                                        HStack {
                                            Circle().fill(sec.status.statusColor).frame(width: 8, height: 8)
                                            Text(sec.name)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(.sbOnSurface)
                                            Spacer()
                                            StatusBadge(status: sec.status)
                                        }
                                        if sec.id != dash.sectionHealth.last?.id {
                                            Divider().background(Color.sbOutline)
                                        }
                                    }
                                }
                            }
                        }

                        // ── Per-pond ABW sorted cards ─────────────────────────
                        SBCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("POND ABW RANKING")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.sbOnSurfaceVariant).kerning(0.5)

                                let sorted = filteredPonds.sorted { ($0.abw ?? 0) > ($1.abw ?? 0) }
                                ForEach(sorted.prefix(10)) { pond in
                                    HStack(spacing: 8) {
                                        Text(pond.name)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.sbOnSurface)
                                            .frame(width: 70, alignment: .leading)
                                        Text(pond.sectionName ?? "—")
                                            .font(.system(size: 10))
                                            .foregroundColor(.sbOnSurfaceVariant)
                                        Spacer()
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(Color.sbSurfaceHigh).frame(height: 6)
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(Color.sbPrimary)
                                                    .frame(width: geo.size.width * CGFloat((pond.abw ?? 0) / max(sorted.first?.abw ?? 1, 1)),
                                                           height: 6)
                                            }
                                        }
                                        .frame(width: 80, height: 6)
                                        Text(String(format: "%.1fg", pond.abw ?? 0))
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.sbPrimaryLight)
                                            .frame(width: 45, alignment: .trailing)
                                    }
                                }
                            }
                        }

                        // ── FCR & Feed from dashboard ─────────────────────────
                        if let dash = dashboard {
                            HStack(spacing: 8) {
                                SBMetricTile(value: String(format: "%.2f", dash.fcr), label: "FCR", color: .sbWarning)
                                SBMetricTile(value: String(format: "%.0f kg", dash.feedLoggedToday),
                                             label: "Feed Today", color: .sbPrimary)
                                SBMetricTile(value: "\(dash.activePonds)", label: "Total Ponds", color: .sbInfo)
                            }
                        }

                    }
                    .padding(14)
                }
            }
        }
        .task { await loadData() }
    }

    private func loadData() async {
        isLoading = true
        async let p = APIService.shared.getPonds()
        async let s = APIService.shared.getSections()
        async let d = APIService.shared.getDashboard()
        let pondsData    = try? await p
        let sectionsData = try? await s
        let dashData     = try? await d
        await MainActor.run {
            ponds     = pondsData ?? []
            sections  = sectionsData ?? []
            dashboard = dashData
            isLoading = false
        }
    }
}

struct StatusDistBar: View {
    let label: String; let count: Int; let total: Int; let color: Color
    var pct: Double { total > 0 ? Double(count) / Double(total) : 0 }
    var body: some View {
        VStack(spacing: 6) {
            Text("\(count)")
                .font(.system(size: 18, weight: .bold)).foregroundColor(color)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.sbSurfaceHigh).frame(height: 8)
                    RoundedRectangle(cornerRadius: 4).fill(color)
                        .frame(width: geo.size.width * CGFloat(pct), height: 8)
                }
            }.frame(height: 8)
            Text(label)
                .font(.system(size: 10)).foregroundColor(.sbOnSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Helpers

private func todayIso() -> String {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
}
