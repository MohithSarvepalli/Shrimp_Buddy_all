import SwiftUI

struct PondDetailView: View {
    let pond: Pond
    @State private var activeTab = "Feed"
    let tabs = ["Feed", "Chemical", "Sampling", "Water"]

    var body: some View {
        VStack(spacing: 0) {
            // Header info strip
            VStack(spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pond.type).font(.system(size: 10)).foregroundColor(.sbOnSurfaceVariant)
                        Text("Section: \(pond.sectionName)")
                            .font(.system(size: 10)).foregroundColor(.sbOnSurfaceVariant)
                    }
                    Spacer()
                    StatusBadge(status: pond.status)
                }
                HStack(spacing: 20) {
                    MetricPill(label: "DOC", value: "\(pond.doc)d")
                    MetricPill(label: "ABW", value: "\(pond.abw, specifier: "%.1f")g")
                    MetricPill(label: "Survival", value: "\(pond.survivalPct, specifier: "%.0f")%")
                    MetricPill(label: "Feed", value: "\(pond.feedTodayKg, specifier: "%.0f")kg")
                }
            }
            .padding(14)
            .background(Color.sbPrimaryContainer)
            .overlay(Divider(), alignment: .bottom)

            // Sub-tabs
            HStack(spacing: 0) {
                ForEach(tabs, id: \.self) { tab in
                    Button(action: { activeTab = tab }) {
                        VStack(spacing: 4) {
                            Text(tab).font(.system(size: 11, weight: activeTab == tab ? .semibold : .medium))
                                .foregroundColor(activeTab == tab ? .sbSecondary : .sbOnSurfaceVariant)
                            Rectangle().fill(activeTab == tab ? Color.sbSecondary : Color.clear).frame(height: 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .background(Color.white)
            .overlay(Divider(), alignment: .bottom)

            // Tab content
            Group {
                switch activeTab {
                case "Feed":     PondFeedTab(pondId: pond.id)
                case "Chemical": PondChemicalTab(pondId: pond.id)
                case "Sampling": PondSamplingTab(pondId: pond.id)
                case "Water":    PondWaterTab(pondId: pond.id)
                default:         EmptyView()
                }
            }
        }
        .background(Color.sbSurface)
        .navigationTitle("Pond \(pond.pondId)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Feed subtab

struct PondFeedTab: View {
    let pondId: String
    @State private var logs: [FeedLog] = []
    @State private var isLoading = true
    @State private var showLog = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(logs.filter { $0.status == "Fed" }.reduce(0) { $0 + $1.totalKg }, specifier: "%.1f") kg fed today")
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(.sbPrimary)
                Spacer()
                Button("+ Log Feed") { showLog = true }
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(.sbSecondary)
            }
            .padding(12)
            .background(Color.sbPrimaryContainer)

            if isLoading { ProgressView().padding() }
            else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(logs) { log in
                            SBCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(log.feedName).font(.system(size: 12, weight: .medium))
                                        Text(log.time).font(.system(size: 10)).foregroundColor(.sbOnSurfaceVariant)
                                    }
                                    Spacer()
                                    if log.status == "Fed" {
                                        Text("\(log.totalKg, specifier: "%.1f") kg ✓")
                                            .font(.system(size: 12, weight: .semibold)).foregroundColor(.sbSuccess)
                                    } else {
                                        Text("Pending").font(.system(size: 12)).foregroundColor(.sbOnSurfaceVariant)
                                    }
                                }
                            }
                        }
                    }.padding(12)
                }
            }
        }
        .task { await load() }
        .sheet(isPresented: $showLog, onDismiss: { Task { await load() }}) {
            LogFeedSheet(pondId: pondId)
        }
    }

    private func load() async {
        isLoading = true
        if let data = try? await APIService.shared.getFeedLogs(pondId: pondId) {
            await MainActor.run { logs = data; isLoading = false }
        } else { await MainActor.run { isLoading = false } }
    }
}

struct LogFeedSheet: View {
    @Environment(\.dismiss) var dismiss
    let pondId: String
    @State private var feedName = "Grower Max 2.4mm"
    @State private var quantity = ""
    @State private var time = "06:00"
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack { Color.sbSurface.ignoresSafeArea()
                VStack(spacing: 16) {
                    SBTextField(label: "Feed Name", text: $feedName, placeholder: "Feed variety")
                    SBTextField(label: "Quantity (kg)", text: $quantity, placeholder: "e.g. 15", keyboardType: .decimalPad)
                    SBTextField(label: "Time", text: $time, placeholder: "HH:MM")
                    SBPrimaryButton("Log Feed", isLoading: isLoading) {
                        Task {
                            guard let kg = Double(quantity) else { return }
                            isLoading = true
                            _ = try? await APIService.shared.logFeed(CreateFeedLogRequest(
                                pondId: pondId, feedName: feedName, totalKg: kg, time: time))
                            await MainActor.run { dismiss() }
                        }
                    }
                    Spacer()
                }.padding(20)
            }
            .navigationTitle("Log Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }.foregroundColor(.sbSecondary)
            }}
        }
    }
}

// MARK: - Chemical subtab

struct PondChemicalTab: View {
    let pondId: String
    @State private var logs: [ChemicalLog] = []
    @State private var isLoading = true
    @State private var showLog = false

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button("+ Log Chemical") { showLog = true }
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(.sbSecondary)
            }.padding(12).background(Color.white)
            if isLoading { ProgressView().padding() }
            else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(logs) { log in
                            SBCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(log.name).font(.system(size: 12, weight: .medium))
                                        Text(log.purpose).font(.system(size: 10)).foregroundColor(.sbOnSurfaceVariant)
                                    }
                                    Spacer()
                                    Text("\(log.quantity, specifier: "%.1f") \(log.unit)")
                                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.sbPrimary)
                                }
                            }
                        }
                    }.padding(12)
                }
            }
        }
        .task { if let data = try? await APIService.shared.getChemicalLogs(pondId: pondId) {
            await MainActor.run { logs = data; isLoading = false }
        } else { await MainActor.run { isLoading = false } }}
        .sheet(isPresented: $showLog, onDismiss: { Task {
            if let data = try? await APIService.shared.getChemicalLogs(pondId: pondId) {
                await MainActor.run { logs = data }
            }
        }}) { LogChemicalSheet(pondId: pondId) }
    }
}

struct LogChemicalSheet: View {
    @Environment(\.dismiss) var dismiss
    let pondId: String
    @State private var name = ""; @State private var qty = ""; @State private var unit = "kg"
    @State private var purpose = ""; @State private var isLoading = false
    var body: some View {
        NavigationStack {
            ZStack { Color.sbSurface.ignoresSafeArea()
                VStack(spacing: 14) {
                    SBTextField(label: "Chemical Name", text: $name, placeholder: "e.g. Agricultural Lime")
                    SBTextField(label: "Quantity", text: $qty, placeholder: "e.g. 5", keyboardType: .decimalPad)
                    SBTextField(label: "Unit (kg/g/L)", text: $unit, placeholder: "kg")
                    SBTextField(label: "Purpose", text: $purpose, placeholder: "e.g. pH Correction")
                    SBPrimaryButton("Log Chemical", isLoading: isLoading) {
                        Task {
                            guard let q = Double(qty) else { return }
                            isLoading = true
                            _ = try? await APIService.shared.logChemical(CreateChemicalLogRequest(
                                pondId: pondId, name: name, quantity: q, unit: unit, purpose: purpose))
                            await MainActor.run { dismiss() }
                        }
                    }
                    Spacer()
                }.padding(20)
            }
            .navigationTitle("Log Chemical").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }.foregroundColor(.sbSecondary)
            }}
        }
    }
}

// MARK: - Sampling subtab

struct PondSamplingTab: View {
    let pondId: String
    @State private var logs: [SamplingLog] = []
    @State private var isLoading = true
    @State private var showLog = false
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button("+ Log Sample") { showLog = true }
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(.sbSecondary)
            }.padding(12).background(Color.white)
            if isLoading { ProgressView().padding() }
            else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(logs) { log in
                            SBCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(log.date).font(.system(size: 12, weight: .medium))
                                        Text("Sample count: \(log.sampleCount)")
                                            .font(.system(size: 10)).foregroundColor(.sbOnSurfaceVariant)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(log.abw, specifier: "%.1f")g ABW")
                                            .font(.system(size: 12, weight: .semibold)).foregroundColor(.sbPrimary)
                                        Text("\(log.survivalPct, specifier: "%.0f")% survival")
                                            .font(.system(size: 10)).foregroundColor(.sbSuccess)
                                    }
                                }
                            }
                        }
                    }.padding(12)
                }
            }
        }
        .task { if let data = try? await APIService.shared.getSamplingLogs(pondId: pondId) {
            await MainActor.run { logs = data; isLoading = false }
        } else { await MainActor.run { isLoading = false }}}
        .sheet(isPresented: $showLog, onDismiss: { Task {
            if let data = try? await APIService.shared.getSamplingLogs(pondId: pondId) {
                await MainActor.run { logs = data }
            }
        }}) { LogSamplingSheet(pondId: pondId) }
    }
}

struct LogSamplingSheet: View {
    @Environment(\.dismiss) var dismiss
    let pondId: String
    @State private var abw = ""; @State private var survival = ""; @State private var count = ""
    @State private var isLoading = false
    var body: some View {
        NavigationStack {
            ZStack { Color.sbSurface.ignoresSafeArea()
                VStack(spacing: 14) {
                    SBTextField(label: "Avg Body Weight (g)", text: $abw, placeholder: "e.g. 18.5", keyboardType: .decimalPad)
                    SBTextField(label: "Survival (%)", text: $survival, placeholder: "e.g. 82", keyboardType: .decimalPad)
                    SBTextField(label: "Sample Count", text: $count, placeholder: "e.g. 50", keyboardType: .numberPad)
                    SBPrimaryButton("Submit Sample", isLoading: isLoading) {
                        Task {
                            guard let a = Double(abw), let s = Double(survival), let c = Int(count) else { return }
                            isLoading = true
                            _ = try? await APIService.shared.logSampling(
                                CreateSamplingRequest(pondId: pondId, abw: a, survivalPct: s, sampleCount: c))
                            await MainActor.run { dismiss() }
                        }
                    }
                    Spacer()
                }.padding(20)
            }
            .navigationTitle("Log Sampling").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }.foregroundColor(.sbSecondary)
            }}
        }
    }
}

// MARK: - Water subtab

struct PondWaterTab: View {
    let pondId: String
    @State private var params: [WaterParamEntry] = []
    @State private var isLoading = true
    var body: some View {
        Group {
            if isLoading { ProgressView().padding() }
            else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(params) { param in
                            SBCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(param.name).font(.system(size: 12, weight: .semibold))
                                        Text("Range: \(param.range)").font(.system(size: 10))
                                            .foregroundColor(.sbOnSurfaceVariant)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("\(param.value, specifier: "%.2f") \(param.unit)")
                                            .font(.system(size: 13, weight: .bold)).foregroundColor(.sbPrimary)
                                        StatusBadge(status: param.status)
                                    }
                                }
                            }
                        }
                    }.padding(12)
                }
            }
        }
        .task { if let data = try? await APIService.shared.getWaterParameters(pondId: pondId) {
            await MainActor.run { params = data; isLoading = false }
        } else { await MainActor.run { isLoading = false }}}
    }
}

// MARK: - Helper

struct MetricPill: View {
    let label: String; let value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 13, weight: .bold)).foregroundColor(.sbPrimary)
            Text(label).font(.system(size: 9)).foregroundColor(.sbOnSurfaceVariant)
        }
    }
}
