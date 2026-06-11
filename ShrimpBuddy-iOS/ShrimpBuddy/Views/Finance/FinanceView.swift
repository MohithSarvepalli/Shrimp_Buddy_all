import SwiftUI
import Charts

// MARK: - Finance View (simplified: chart + 3 cost breakdowns)

struct FinanceView: View {
    @State private var transactions: [FinanceTransaction] = []
    @State private var isLoading = true
    @State private var showAdd = false

    var totalExpense: Double { transactions.filter { $0.type == "Expense" }.reduce(0) { $0 + $1.amount } }
    var feedCost: Double { transactions.filter { $0.type == "Expense" && $0.category == "Feed" }.reduce(0) { $0 + $1.amount } }
    var chemCost: Double { transactions.filter { $0.type == "Expense" && $0.category == "Chemical" }.reduce(0) { $0 + $1.amount } }
    var otherCost: Double { totalExpense - feedCost - chemCost }

    // Breakdown for bar chart
    var breakdown: [(label: String, value: Double, color: Color)] {
        let cats = Dictionary(grouping: transactions.filter { $0.type == "Expense" }, by: \.category)
        return cats.map { (k, v) in
            let c: Color
            switch k {
            case "Feed": c = .sbPrimary
            case "Chemical": c = .sbWarning
            case "Labour": c = .sbSuccess
            case "Harvest": c = Color(hex: "#9b59b6")
            default: c = .sbOnSurfaceVariant
            }
            return (label: k, value: v.reduce(0) { $0 + $1.amount }, color: c)
        }.sorted { $0.value > $1.value }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SBAppHeader(title: "Finance",
                            trailingAction: { showAdd = true }, trailingLabel: "+ Entry")

                if isLoading {
                    Spacer(); ProgressView().tint(.sbPrimary); Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 14) {

                            // ── Total Expense Hero ────────────────────────────
                            SBCard(elevated: true) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("TOTAL EXPENSES")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.sbOnSurfaceVariant).kerning(0.6)
                                    Text("₹\(totalExpense, specifier: "%.0f")")
                                        .font(.system(size: 34, weight: .bold, design: .rounded))
                                        .foregroundColor(.sbOnSurface)
                                    Text("All time · \(transactions.filter { $0.type == "Expense" }.count) entries")
                                        .font(.system(size: 12))
                                        .foregroundColor(.sbOnSurfaceVariant)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            // ── Feed + Chemical Cost Cards ────────────────────
                            HStack(spacing: 10) {
                                CostCard(label: "Feed Cost",     value: feedCost,  color: .sbPrimary)
                                CostCard(label: "Chemical Cost", value: chemCost,  color: .sbWarning)
                                CostCard(label: "Other",         value: otherCost, color: .sbOnSurfaceVariant)
                            }

                            // ── Expense Breakdown Bar Chart ───────────────────
                            if !breakdown.isEmpty {
                                SBCard {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("EXPENSE BREAKDOWN")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(.sbOnSurfaceVariant).kerning(0.5)

                                        Chart(breakdown, id: \.label) { item in
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
                                                AxisValueLabel()
                                                    .font(.system(size: 9))
                                                    .foregroundStyle(Color.sbOnSurfaceVariant)
                                            }
                                        }
                                        .chartYAxis {
                                            AxisMarks(position: .leading) { _ in
                                                AxisValueLabel()
                                                    .font(.system(size: 9))
                                                    .foregroundStyle(Color.sbOnSurfaceVariant)
                                                AxisGridLine(stroke: StrokeStyle(dash: [3,4]))
                                                    .foregroundStyle(Color.sbOutline)
                                            }
                                        }
                                        .frame(height: 200)

                                        // Legend
                                        HStack(spacing: 16) {
                                            ForEach(breakdown.prefix(4), id: \.label) { item in
                                                HStack(spacing: 5) {
                                                    Circle().fill(item.color)
                                                        .frame(width: 7, height: 7)
                                                    Text(item.label)
                                                        .font(.system(size: 10))
                                                        .foregroundColor(.sbOnSurfaceVariant)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                        }
                        .padding(14)
                    }
                }
            }
            .background(Color.sbBg.ignoresSafeArea())
            .preferredColorScheme(.dark)
            .task {
                if let data = try? await APIService.shared.getFinanceTransactions() {
                    await MainActor.run { transactions = data; isLoading = false }
                } else { await MainActor.run { isLoading = false } }
            }
            .sheet(isPresented: $showAdd, onDismiss: { Task {
                if let data = try? await APIService.shared.getFinanceTransactions() {
                    await MainActor.run { transactions = data }
                }
            }}) { AddTransactionSheet() }
        }
    }
}

struct CostCard: View {
    let label: String; let value: Double; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text("₹\(Int(value / 1000))k")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.sbOnSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.sbSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sbOutline, lineWidth: 0.8))
    }
}

// MARK: - Add Transaction Sheet (dark re-styled)

struct AddTransactionSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var type = "Expense"
    @State private var amount = ""
    @State private var category = "Feed"
    @State private var note = ""
    @State private var isLoading = false

    let types      = ["Income", "Expense"]
    let categories = ["Feed", "Chemical", "Harvest", "Labour", "Utility", "Other"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.sbBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        SBTextField(label: "Title", text: $title,
                                    placeholder: "e.g. Feed Purchase — 1 Ton")
                        VStack(alignment: .leading, spacing: 5) {
                            Text("TYPE").font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.sbOnSurfaceVariant).kerning(0.6)
                            Picker("Type", selection: $type) {
                                ForEach(types, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        }
                        SBTextField(label: "Amount (₹)", text: $amount,
                                    placeholder: "e.g. 88000", keyboardType: .decimalPad)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("CATEGORY").font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.sbOnSurfaceVariant).kerning(0.6)
                            Picker("Category", selection: $category) {
                                ForEach(categories, id: \.self) { Text($0).tag($0) }
                            }.pickerStyle(.menu)
                                .tint(.sbPrimaryLight)
                        }
                        SBTextField(label: "Note (optional)", text: $note,
                                    placeholder: "Any additional notes")
                        SBPrimaryButton("Save Entry", isLoading: isLoading) {
                            Task {
                                guard !title.isEmpty, let amt = Double(amount) else { return }
                                isLoading = true
                                _ = try? await APIService.shared.createTransaction(
                                    CreateTransactionRequest(
                                        title: title, type: type, amount: amt,
                                        category: category,
                                        note: note.isEmpty ? nil : note))
                                await MainActor.run { dismiss() }
                            }
                        }
                    }.padding(20)
                }
            }
            .navigationTitle("Add Entry").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }.foregroundColor(.sbPrimaryLight)
            }}
            .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Harvest View (restyled)

struct HarvestView: View {
    @State private var forecasts: [HarvestForecast] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SBAppHeader(title: "Harvest Forecast")
                if isLoading { Spacer(); ProgressView().tint(.sbPrimary); Spacer() }
                else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(forecasts) { f in
                                SBCard {
                                    VStack(spacing: 10) {
                                        HStack {
                                            Text("Pond \(f.pondId)")
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(.sbOnSurface)
                                            Spacer()
                                            StatusBadge(status: f.status.uppercased())
                                        }
                                        HStack(spacing: 16) {
                                            MetricItem(label: "Current ABW",
                                                       value: "\(f.currentAbw, specifier: "%.1f")g")
                                            MetricItem(label: "Target ABW",
                                                       value: "\(f.targetAbw, specifier: "%.1f")g")
                                            Spacer()
                                            VStack(alignment: .trailing, spacing: 2) {
                                                Text("Days Left")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.sbOnSurfaceVariant)
                                                Text(f.daysLeft == 0 ? "READY" : "\(f.daysLeft)d")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(f.daysLeft == 0 ? .sbSuccess : .sbPrimaryLight)
                                            }
                                        }
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(Color.sbSurfaceHigh).frame(height: 6)
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(Color.sbPrimary)
                                                    .frame(width: geo.size.width * min(1, CGFloat(f.currentAbw / f.targetAbw)),
                                                           height: 6)
                                            }
                                        }.frame(height: 6)
                                    }
                                }
                            }
                        }.padding(14)
                    }
                }
            }
            .background(Color.sbBg.ignoresSafeArea())
            .task { if let data = try? await APIService.shared.getHarvestForecasts() {
                await MainActor.run { forecasts = data; isLoading = false }
            } else { await MainActor.run { isLoading = false }}}
        }
    }
}

struct MetricItem: View {
    let label: String; let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10)).foregroundColor(.sbOnSurfaceVariant)
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundColor(.sbOnSurface)
        }
    }
}

// MARK: - Market Price View (restyled)

struct MarketPriceView: View {
    @State private var prices: [MarketPrice] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SBAppHeader(title: "Market Prices")
                if isLoading { Spacer(); ProgressView().tint(.sbPrimary); Spacer() }
                else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(prices) { price in
                                SBCard {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(price.size)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.sbOnSurface)
                                            Text("Updated: \(price.updatedAt)")
                                                .font(.system(size: 11))
                                                .foregroundColor(.sbOnSurfaceVariant)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text("₹\(price.pricePerKg, specifier: "%.0f")/kg")
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(.sbOnSurface)
                                            Text(price.trend == "up" ? "↑ Rising" :
                                                 price.trend == "down" ? "↓ Falling" : "→ Stable")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(
                                                    price.trend == "up" ? .sbSuccess :
                                                    price.trend == "down" ? .sbError : .sbOnSurfaceVariant)
                                        }
                                    }
                                }
                            }
                        }.padding(14)
                    }
                }
            }
            .background(Color.sbBg.ignoresSafeArea())
            .task { if let data = try? await APIService.shared.getMarketPrices() {
                await MainActor.run { prices = data; isLoading = false }
            } else { await MainActor.run { isLoading = false }}}
        }
    }
}

// MARK: - Reports View (restyled)

struct ReportsView: View {
    @State private var reports: [FarmReport] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SBAppHeader(title: "Farm Reports")
                if isLoading { Spacer(); ProgressView().tint(.sbPrimary); Spacer() }
                else if reports.isEmpty {
                    EmptyStateView(icon: "📄", title: "No Reports",
                                   message: "Generate your first farm report.")
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(reports) { report in
                                SBCard {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(report.title)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(.sbOnSurface)
                                            Text("\(report.type.capitalized) · \(report.generatedAt)")
                                                .font(.system(size: 11))
                                                .foregroundColor(.sbOnSurfaceVariant)
                                        }
                                        Spacer()
                                        if report.downloadUrl != nil {
                                            Image(systemName: "arrow.down.circle.fill")
                                                .font(.title3)
                                                .foregroundColor(.sbPrimary)
                                        }
                                    }
                                }
                            }
                        }.padding(14)
                    }
                }
            }
            .background(Color.sbBg.ignoresSafeArea())
            .task { if let data = try? await APIService.shared.getReports() {
                await MainActor.run { reports = data; isLoading = false }
            } else { await MainActor.run { isLoading = false }}}
        }
    }
}
