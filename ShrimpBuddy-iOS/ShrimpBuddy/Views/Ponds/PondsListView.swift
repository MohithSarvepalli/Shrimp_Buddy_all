import SwiftUI

struct PondsListView: View {
    @State private var ponds: [Pond] = []
    @State private var sections: [Section] = []
    @State private var isLoading = true
    @State private var selectedSection = "All"
    @State private var showAddPond = false

    var sectionNames: [String] { ["All"] + sections.map(\.name) }

    var filtered: [Pond] {
        if selectedSection == "All" { return ponds }
        return ponds.filter { $0.sectionName == selectedSection }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Header ───────────────────────────────────────────────────
                SBAppHeader(title: "Ponds",
                            trailingAction: { showAddPond = true },
                            trailingLabel: "+ Add Pond")

                // ── Section Slider Tabs ───────────────────────────────────────
                SBSectionPillTabs(sections: sectionNames, selected: $selectedSection)

                // ── Content ───────────────────────────────────────────────────
                if isLoading {
                    Spacer()
                    ProgressView().tint(.sbPrimary).scaleEffect(1.2)
                    Spacer()
                } else if filtered.isEmpty {
                    EmptyStateView(icon: "🌊", title: "No Ponds",
                                   message: "Add your first pond to start tracking.")
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(filtered) { pond in
                                NavigationLink(destination: PondDetailView(pond: pond)) {
                                    PondCard(pond: pond)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(14)
                    }
                }
            }
            .background(Color.sbBg.ignoresSafeArea())
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showAddPond,
                   onDismiss: { Task { await loadAll() } }) {
                AddPondView(sections: sections)
            }
            .task { await loadAll() }
        }
    }

    private func loadAll() async {
        isLoading = true
        async let p = APIService.shared.getPonds()
        async let s = APIService.shared.getSections()
        let ponds_ = (try? await p) ?? []
        let secs_  = (try? await s) ?? []
        await MainActor.run {
            ponds = ponds_; sections = secs_; isLoading = false
        }
    }
}

// MARK: - Pond Card

struct PondCard: View {
    let pond: Pond
    var body: some View {
        SBCard {
            VStack(spacing: 0) {
                // Title row
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(pond.pondId)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.sbOnSurface)
                        HStack(spacing: 6) {
                            Text(pond.sectionName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.sbPrimaryLight)
                            Text("·").foregroundColor(.sbOnSurfaceDim)
                            Text(pond.type)
                                .font(.system(size: 11))
                                .foregroundColor(.sbOnSurfaceVariant)
                        }
                    }
                    Spacer()
                    StatusBadge(status: pond.status)
                }
                .padding(.bottom, 12)

                Divider().background(Color.sbOutline)

                // Metrics row
                HStack(spacing: 0) {
                    PondMetricCell(
                        value: formatDate(pond.stockedDate),
                        label: "Stocked",
                        icon: "calendar")
                    metricDivider
                    PondMetricCell(
                        value: "DOC \(pond.doc)d",
                        label: "Day of Culture",
                        icon: "clock")
                    metricDivider
                    PondMetricCell(
                        value: "\(pond.feedTodayKg, specifier: "%.0f") kg",
                        label: "Latest Feed",
                        icon: "basket")
                    metricDivider
                    PondMetricCell(
                        value: "\(pond.survivalPct, specifier: "%.0f")%",
                        label: "Survival",
                        icon: "heart")
                }
                .padding(.top, 12)
            }
        }
    }

    var metricDivider: some View {
        Rectangle().fill(Color.sbOutline).frame(width: 0.8).padding(.vertical, 6)
    }

    func formatDate(_ iso: String?) -> String {
        guard let iso else { return "—" }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        if let d = f.date(from: iso) {
            let df = DateFormatter()
            df.dateFormat = "d MMM"
            return df.string(from: d)
        }
        return iso
    }
}

struct PondMetricCell: View {
    let value: String; let label: String; let icon: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.sbOnSurface)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.sbOnSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
