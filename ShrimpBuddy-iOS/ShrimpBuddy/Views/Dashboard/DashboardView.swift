import SwiftUI
import Charts

// MARK: - Dashboard View

struct DashboardView: View {
    @EnvironmentObject var authState: AuthStateObject
    @State private var stats: DashboardStats?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Dark Header ──────────────────────────────────────────────
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("BLUE OCEAN AQUAFARM")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.sbOnSurfaceVariant)
                            .kerning(1.2)
                        Text("Dashboard")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.sbOnSurface)
                    }
                    Spacer()
                    Button(action: {}) {
                        ZStack {
                            Circle().fill(Color.sbSurfaceElevated).frame(width: 40, height: 40)
                            Image(systemName: "bell.fill")
                                .font(.system(size: 15))
                                .foregroundColor(.sbPrimaryLight)
                        }
                    }
                }
                .padding(.horizontal, 18).padding(.vertical, 14)
                .background(Color.sbSurface)
                .overlay(Divider().background(Color.sbOutline), alignment: .bottom)

                if isLoading {
                    Spacer()
                    ProgressView().tint(.sbPrimary).scaleEffect(1.3)
                    Spacer()
                } else if let error = error {
                    EmptyStateView(icon: "⚠️", title: "Load Failed", message: error)
                } else if let stats = stats {
                    ScrollView {
                        VStack(spacing: 14) {

                            // ── Alert Banners ─────────────────────────────────
                            ForEach(stats.alerts) { alert in
                                HStack(spacing: 10) {
                                    Text(alert.severity == "critical" ? "🚨" : "⚠️")
                                        .font(.system(size: 14))
                                    Text(alert.message)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(alert.severity.statusColor)
                                    Spacer()
                                    Text(alert.severity.uppercased())
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(alert.severity.statusColor)
                                        .padding(.horizontal, 7).padding(.vertical, 3)
                                        .background(alert.severity.statusBgColor)
                                        .cornerRadius(20)
                                }
                                .padding(12)
                                .background(alert.severity.statusBgColor)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .stroke(alert.severity.statusColor.opacity(0.25), lineWidth: 1))
                            }

                            // ── 4 Stat Cards ──────────────────────────────────
                            HStack(spacing: 10) {
                                SBMetricTile(value: "\(stats.stablePonds)",
                                             label: "Stable", color: .sbSuccess)
                                SBMetricTile(value: "\(stats.attentionPonds)",
                                             label: "Attention", color: .sbWarning)
                                SBMetricTile(value: "\(stats.criticalPonds)",
                                             label: "Critical", color: .sbError)
                                LatestFeedTile(kg: stats.feedLoggedToday)
                            }

                            // ── Feed Trend Chart ──────────────────────────────
                            SBCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text("DAILY FEED TREND")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(.sbOnSurfaceVariant).kerning(0.5)
                                        Spacer()
                                        Text("Last 7 days")
                                            .font(.system(size: 10))
                                            .foregroundColor(.sbOnSurfaceDim)
                                    }
                                    if !stats.feedTrend.isEmpty {
                                        Chart(stats.feedTrend) { point in
                                            LineMark(
                                                x: .value("Day", point.label),
                                                y: .value("Feed (kg)", point.value)
                                            )
                                            .foregroundStyle(Color.sbPrimary)
                                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                                            AreaMark(
                                                x: .value("Day", point.label),
                                                y: .value("Feed (kg)", point.value)
                                            )
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [Color.sbPrimary.opacity(0.3), Color.clear],
                                                    startPoint: .top, endPoint: .bottom)
                                            )
                                            PointMark(
                                                x: .value("Day", point.label),
                                                y: .value("Feed (kg)", point.value)
                                            )
                                            .foregroundStyle(Color.sbPrimaryLight)
                                            .symbolSize(30)
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
                                                AxisGridLine(stroke: StrokeStyle(dash:[3,4]))
                                                    .foregroundStyle(Color.sbOutline)
                                            }
                                        }
                                        .frame(height: 160)
                                    } else {
                                        Text("No feed data yet")
                                            .font(.system(size: 12))
                                            .foregroundColor(.sbOnSurfaceVariant)
                                            .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
                                    }
                                }
                            }

                            // ── Section Feed Logs ─────────────────────────────
                            SBCard {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("LATEST FEED — BY SECTION")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.sbOnSurfaceVariant).kerning(0.5)
                                        .padding(.bottom, 12)

                                    ForEach(Array(stats.sectionFeedLogs.enumerated()), id: \.1.id) { idx, log in
                                        HStack(spacing: 12) {
                                            ZStack {
                                                Circle().fill(Color.sbPrimaryDim)
                                                    .frame(width: 34, height: 34)
                                                Text(String(log.sectionName.prefix(1)))
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundColor(.sbPrimaryLight)
                                            }
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(log.sectionName)
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(.sbOnSurface)
                                                Text(log.time)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.sbOnSurfaceVariant)
                                            }
                                            Spacer()
                                            VStack(alignment: .trailing, spacing: 2) {
                                                Text("\(log.feedKg, specifier: "%.1f") kg")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(.sbPrimaryLight)
                                                StatusBadge(status: log.status)
                                            }
                                        }
                                        .padding(.vertical, 8)
                                        if idx < stats.sectionFeedLogs.count - 1 {
                                            Divider().background(Color.sbOutline)
                                        }
                                    }

                                    if stats.sectionFeedLogs.isEmpty {
                                        Text("No feed logged today")
                                            .font(.system(size: 12))
                                            .foregroundColor(.sbOnSurfaceVariant)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .padding(.top, 8)
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
            .task { await loadDashboard() }
        }
    }

    private func loadDashboard() async {
        isLoading = true
        do {
            let data = try await APIService.shared.getDashboard()
            await MainActor.run { stats = data; isLoading = false }
        } catch {
            await MainActor.run { self.error = error.localizedDescription; isLoading = false }
        }
    }
}

// MARK: - Latest Feed Tile (4th stat card)

struct LatestFeedTile: View {
    let kg: Double
    var body: some View {
        VStack(spacing: 3) {
            Text("\(kg, specifier: "%.0f")")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.sbPrimary)
            Text("kg")
                .font(.system(size: 10))
                .foregroundColor(.sbPrimaryLight)
            Text("Today's Feed")
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
