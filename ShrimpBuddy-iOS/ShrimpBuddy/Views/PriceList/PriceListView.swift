import SwiftUI

// MARK: - Price List & Rates (Feed + Chemicals)

struct PriceListView: View {
    @State private var activeSection = "Feed"
    let sections = ["Feed", "Chemicals"]

    var body: some View {
        VStack(spacing: 0) {
            SBAppHeader(title: "Price List & Rates",
                        subtitle: "Set rates for cost calculation")
            SBSectionPillTabs(sections: sections, selected: $activeSection)

            if activeSection == "Feed" {
                FeedPriceListView()
            } else {
                ChemicalPriceListView()
            }
        }
        .background(Color.sbBg.ignoresSafeArea())
    }
}

// MARK: - Feed Price List

struct FeedPriceListView: View {
    @State private var feedMaster: [FeedMasterRecord] = []
    @State private var feedDispatches: [FeedDispatchRecord] = []
    @State private var editedRates: [String: String] = [:]  // id → rate string
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var savedMsg = ""
    @State private var showAddFeed = false

    // Feed types that appear in dispatches but have no master record or rate = 0
    var missingNames: Set<String> {
        let masterNames = Set(feedMaster.map { $0.name.lowercased() })
        var missing = Set<String>()
        for d in feedDispatches {
            let key = d.feedType.lowercased()
            if !masterNames.contains(key) {
                missing.insert(d.feedType)
            }
        }
        return missing
    }

    // Combine master records + auto-add missing dispatch names
    var allRows: [(id: String, name: String, ratePerKg: Double, isMissing: Bool, isAutoAdded: Bool)] {
        var rows: [(id: String, name: String, ratePerKg: Double, isMissing: Bool, isAutoAdded: Bool)] = []
        for f in feedMaster.filter({ $0.isActive }) {
            let isMissing = f.ratePerKg == 0
            rows.append((f.id, f.name, f.ratePerKg, isMissing, false))
        }
        // Auto-add dispatched feed types not in master
        let masterNames = Set(feedMaster.map { $0.name.lowercased() })
        var seen = Set<String>()
        for d in feedDispatches {
            let key = d.feedType.lowercased()
            if !masterNames.contains(key) && !seen.contains(key) {
                rows.append(("auto-\(d.feedType)", d.feedType, 0, true, true))
                seen.insert(key)
            }
        }
        return rows.sorted { $0.name < $1.name }
    }

    var missingCount: Int { allRows.filter { $0.isMissing }.count }

    var body: some View {
        if isLoading {
            Spacer(); ProgressView().tint(.sbPrimary); Spacer()
        } else {
            ScrollView {
                VStack(spacing: 12) {

                    // Missing rate warning banner
                    if missingCount > 0 {
                        MissingRateBanner(count: missingCount, type: "feed")
                    }

                    // Info
                    HStack {
                        Text("FEED RATES (₹ per kg)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.sbOnSurfaceVariant).kerning(0.6)
                        Spacer()
                        Button("+ Add Feed") { showAddFeed = true }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.sbPrimaryLight)
                    }

                    // Price rows
                    VStack(spacing: 0) {
                        ForEach(allRows, id: \.id) { row in
                            FeedPriceRow(
                                id: row.id,
                                name: row.name,
                                ratePerKg: row.ratePerKg,
                                isMissing: row.isMissing,
                                isAutoAdded: row.isAutoAdded,
                                editedRate: Binding(
                                    get: { editedRates[row.id] ?? (row.ratePerKg == 0 ? "" : String(row.ratePerKg)) },
                                    set: { editedRates[row.id] = $0 }
                                )
                            )
                            if row.id != allRows.last?.id {
                                Divider().background(Color.sbOutline).padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color.sbSurface)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sbOutline, lineWidth: 0.8))

                    // Save
                    if !savedMsg.isEmpty {
                        Text(savedMsg)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.sbSuccess)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Color.sbSuccessBg)
                            .cornerRadius(8)
                    }

                    SBPrimaryButton("Save All Rates", isLoading: isSaving) {
                        Task { await saveRates() }
                    }

                }
                .padding(16)
            }
        }
        .task { await loadData() }
        .sheet(isPresented: $showAddFeed, onDismiss: { Task { await loadData() } }) {
            AddFeedMasterSheet()
        }
    }

    private func loadData() async {
        isLoading = true
        async let fm = APIService.shared.getFeedMaster()
        async let fd = APIService.shared.getFeedDispatches()
        await MainActor.run {
            feedMaster     = (try? fm) ?? []
            feedDispatches = (try? fd) ?? []
            isLoading = false
        }
    }

    private func saveRates() async {
        isSaving = true; savedMsg = ""
        var updated = feedMaster
        for i in updated.indices {
            if let rateStr = editedRates[updated[i].id], let rate = Double(rateStr) {
                updated[i].ratePerKg = rate
            }
        }
        // Handle auto-added (create new master records for them)
        for row in allRows where row.isAutoAdded {
            if let rateStr = editedRates[row.id], let rate = Double(rateStr), rate > 0 {
                updated.append(FeedMasterRecord(
                    id: UUID().uuidString, name: row.name,
                    ratePerKg: rate, unit: "kg", isActive: true))
            }
        }
        if let saved = try? await APIService.shared.saveFeedMaster(updated) {
            await MainActor.run {
                feedMaster = saved
                editedRates = [:]
                savedMsg = "Rates saved successfully"
                isSaving = false
            }
        } else {
            await MainActor.run { isSaving = false }
        }
    }
}

struct FeedPriceRow: View {
    let id: String
    let name: String
    let ratePerKg: Double
    let isMissing: Bool
    let isAutoAdded: Bool
    @Binding var editedRate: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.sbOnSurface)
                    if isMissing {
                        Text(isAutoAdded ? "New" : "Missing rate")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.sbWarning)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.sbWarningBg)
                            .cornerRadius(6)
                    }
                }
                Text("per kg").font(.system(size: 10)).foregroundColor(.sbOnSurfaceDim)
            }
            Spacer()
            HStack(spacing: 4) {
                Text("₹").font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isMissing ? .sbWarning : .sbOnSurfaceVariant)
                TextField("0", text: $editedRate)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(isMissing ? .sbWarning : .sbOnSurface)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(isMissing ? Color.sbWarningBg.opacity(0.3) : Color.clear)
    }
}

// MARK: - Chemical Price List

struct ChemicalPriceListView: View {
    @State private var chemMaster: [ChemicalMasterRecord] = []
    @State private var chemDispatches: [ChemicalDispatchRecord] = []
    @State private var editedRates: [String: String] = [:]
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var savedMsg = ""
    @State private var showAddChem = false

    var allRows: [(id: String, name: String, unit: String, ratePerUnit: Double, category: String, isMissing: Bool, isAutoAdded: Bool)] {
        var rows: [(id: String, name: String, unit: String, ratePerUnit: Double, category: String, isMissing: Bool, isAutoAdded: Bool)] = []
        for c in chemMaster.filter({ $0.isActive }) {
            rows.append((c.id, c.name, c.unit, c.ratePerUnit, c.category, c.ratePerUnit == 0, false))
        }
        let masterNames = Set(chemMaster.map { $0.name.lowercased() })
        var seen = Set<String>()
        for d in chemDispatches {
            let key = d.chemicalName.lowercased()
            if !masterNames.contains(key) && !seen.contains(key) {
                rows.append(("auto-\(d.chemicalName)", d.chemicalName, d.unit, 0, "", true, true))
                seen.insert(key)
            }
        }
        return rows.sorted { $0.name < $1.name }
    }

    var missingCount: Int { allRows.filter { $0.isMissing }.count }

    var body: some View {
        if isLoading {
            Spacer(); ProgressView().tint(.sbPrimary); Spacer()
        } else {
            ScrollView {
                VStack(spacing: 12) {

                    if missingCount > 0 {
                        MissingRateBanner(count: missingCount, type: "chemical")
                    }

                    HStack {
                        Text("CHEMICAL RATES (₹ per unit)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.sbOnSurfaceVariant).kerning(0.6)
                        Spacer()
                        Button("+ Add Chemical") { showAddChem = true }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.sbPrimaryLight)
                    }

                    VStack(spacing: 0) {
                        ForEach(allRows, id: \.id) { row in
                            ChemicalPriceRow(
                                id: row.id,
                                name: row.name,
                                unit: row.unit,
                                ratePerUnit: row.ratePerUnit,
                                category: row.category,
                                isMissing: row.isMissing,
                                isAutoAdded: row.isAutoAdded,
                                editedRate: Binding(
                                    get: { editedRates[row.id] ?? (row.ratePerUnit == 0 ? "" : String(row.ratePerUnit)) },
                                    set: { editedRates[row.id] = $0 }
                                )
                            )
                            if row.id != allRows.last?.id {
                                Divider().background(Color.sbOutline).padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color.sbSurface)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sbOutline, lineWidth: 0.8))

                    if !savedMsg.isEmpty {
                        Text(savedMsg)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.sbSuccess)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Color.sbSuccessBg)
                            .cornerRadius(8)
                    }

                    SBPrimaryButton("Save All Rates", isLoading: isSaving) {
                        Task { await saveRates() }
                    }
                }
                .padding(16)
            }
        }
        .task { await loadData() }
        .sheet(isPresented: $showAddChem, onDismiss: { Task { await loadData() } }) {
            AddChemicalMasterSheet()
        }
    }

    private func loadData() async {
        isLoading = true
        async let cm = APIService.shared.getChemicalMaster()
        async let cd = APIService.shared.getChemicalDispatches()
        await MainActor.run {
            chemMaster     = (try? cm) ?? []
            chemDispatches = (try? cd) ?? []
            isLoading = false
        }
    }

    private func saveRates() async {
        isSaving = true; savedMsg = ""
        var updated = chemMaster
        for i in updated.indices {
            if let rateStr = editedRates[updated[i].id], let rate = Double(rateStr) {
                updated[i].ratePerUnit = rate
            }
        }
        // Create new chemicals on the backend first, then include them in the update list.
        for row in allRows where row.isAutoAdded {
            if let rateStr = editedRates[row.id], let rate = Double(rateStr), rate > 0 {
                if let created = try? await APIService.shared.createChemicalMaster(
                    name: row.name, category: "", unit: row.unit, ratePerUnit: rate) {
                    updated.append(created)
                } else {
                    // Fallback: append with a local ID so saveChemicalMaster can still try
                    updated.append(ChemicalMasterRecord(
                        id: UUID().uuidString, name: row.name,
                        ratePerUnit: rate, unit: row.unit, category: "", isActive: true))
                }
            }
        }
        if let saved = try? await APIService.shared.saveChemicalMaster(updated) {
            await MainActor.run {
                chemMaster = saved
                editedRates = [:]
                savedMsg = "Rates saved successfully"
                isSaving = false
            }
        } else {
            await MainActor.run { isSaving = false }
        }
    }
}

struct ChemicalPriceRow: View {
    let id: String; let name: String; let unit: String
    let ratePerUnit: Double; let category: String
    let isMissing: Bool; let isAutoAdded: Bool
    @Binding var editedRate: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.sbOnSurface)
                    if isMissing {
                        Text(isAutoAdded ? "New" : "Missing rate")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.sbWarning)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.sbWarningBg)
                            .cornerRadius(6)
                    }
                }
                HStack(spacing: 4) {
                    Text("per \(unit.isEmpty ? "unit" : unit)")
                        .font(.system(size: 10)).foregroundColor(.sbOnSurfaceDim)
                    if !category.isEmpty {
                        Text("· \(category)")
                            .font(.system(size: 10)).foregroundColor(.sbOnSurfaceDim)
                    }
                }
            }
            Spacer()
            HStack(spacing: 4) {
                Text("₹").font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isMissing ? .sbWarning : .sbOnSurfaceVariant)
                TextField("0", text: $editedRate)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(isMissing ? .sbWarning : .sbOnSurface)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(isMissing ? Color.sbWarningBg.opacity(0.3) : Color.clear)
    }
}

// MARK: - Missing Rate Banner

struct MissingRateBanner: View {
    let count: Int; let type: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16)).foregroundColor(.sbWarning)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count) \(type) rate\(count == 1 ? "" : "s") missing")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.sbWarning)
                Text("Finance totals won't be accurate until rates are set.")
                    .font(.system(size: 11)).foregroundColor(.sbWarning.opacity(0.8))
            }
            Spacer()
        }
        .padding(12)
        .background(Color.sbWarningBg)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sbWarning.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - Add Feed Master Sheet

struct AddFeedMasterSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var ratePerKg = ""
    @State private var unit = "kg"
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.sbBg.ignoresSafeArea()
                VStack(spacing: 16) {
                    SBTextField(label: "Feed Name", text: $name, placeholder: "e.g. Grower Max 2.4mm")
                    SBTextField(label: "Rate per kg (₹)", text: $ratePerKg,
                                placeholder: "e.g. 68.50", keyboardType: .decimalPad)
                    SBTextField(label: "Unit", text: $unit, placeholder: "kg")
                    SBPrimaryButton("Add Feed", isLoading: isLoading) {
                        Task {
                            guard !name.isEmpty else { return }
                            isLoading = true
                            let rate = Double(ratePerKg) ?? 0
                            let rec = FeedMasterRecord(id: UUID().uuidString, name: name,
                                                       ratePerKg: rate, unit: unit, isActive: true)
                            _ = try? await APIService.shared.saveFeedMaster([rec])
                            await MainActor.run { dismiss() }
                        }
                    }
                    Spacer()
                }.padding(20)
            }
            .navigationTitle("Add Feed Type").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }.foregroundColor(.sbPrimaryLight)
            }}
            .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Add Chemical Master Sheet

struct AddChemicalMasterSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var ratePerUnit = ""
    @State private var unit = "kg"
    @State private var category = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.sbBg.ignoresSafeArea()
                VStack(spacing: 16) {
                    SBTextField(label: "Chemical Name", text: $name, placeholder: "e.g. Agricultural Lime")
                    HStack(spacing: 12) {
                        SBTextField(label: "Rate per unit (₹)", text: $ratePerUnit,
                                    placeholder: "e.g. 45.00", keyboardType: .decimalPad)
                        SBTextField(label: "Unit", text: $unit, placeholder: "kg/L/g")
                    }
                    SBTextField(label: "Category", text: $category,
                                placeholder: "e.g. pH Correction, Disinfection")
                    SBPrimaryButton("Add Chemical", isLoading: isLoading) {
                        Task {
                            guard !name.isEmpty else { return }
                            isLoading = true
                            let rate = Double(ratePerUnit) ?? 0
                            let rec = ChemicalMasterRecord(id: UUID().uuidString, name: name,
                                                            ratePerUnit: rate, unit: unit,
                                                            category: category, isActive: true)
                            _ = try? await APIService.shared.saveChemicalMaster([rec])
                            await MainActor.run { dismiss() }
                        }
                    }
                    Spacer()
                }.padding(20)
            }
            .navigationTitle("Add Chemical").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }.foregroundColor(.sbPrimaryLight)
            }}
            .preferredColorScheme(.dark)
        }
    }
}
