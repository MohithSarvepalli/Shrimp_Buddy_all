import SwiftUI

// MARK: - Audit & Compliance View (matches web AuditScreen)

struct AuditComplianceView: View {
    @State private var activeSection = "Policies"
    let sections = ["Policies", "Event Log", "Compliance"]

    var body: some View {
        VStack(spacing: 0) {
            SBAppHeader(title: "Audit & Compliance",
                        subtitle: "Policies, logs and issue tracking")
            SBSectionPillTabs(sections: sections, selected: $activeSection)

            Group {
                switch activeSection {
                case "Policies":   AuditPoliciesView()
                case "Event Log":  AuditEventLogView()
                default:           ComplianceIssuesView()
                }
            }
        }
        .background(Color.sbBg.ignoresSafeArea())
    }
}

// MARK: - Audit Policies

struct AuditPoliciesView: View {
    @State private var policies: [AuditPolicy] = defaultPolicies
    @State private var isLoading = false
    @State private var runningId: String? = nil
    @State private var toast = ""

    var activeCount: Int { policies.filter { $0.active }.count }
    var attentionCount: Int { policies.filter { $0.status == "ATTENTION" }.count }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {

                // Metrics
                HStack(spacing: 8) {
                    SBMetricTile(value: "\(policies.count)", label: "Total Policies", color: .sbPrimary)
                    SBMetricTile(value: "\(activeCount)", label: "Active", color: .sbSuccess)
                    SBMetricTile(value: "\(attentionCount)", label: "Needs Attention", color: .sbWarning)
                }

                // Toast
                if !toast.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.sbSuccess)
                        Text(toast).font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.sbSuccess)
                    }
                    .padding(10).background(Color.sbSuccessBg).cornerRadius(8)
                }

                // Policy cards
                ForEach($policies) { $policy in
                    AuditPolicyCard(
                        policy: $policy,
                        isRunning: runningId == policy.id,
                        onRun: {
                            Task { await runPolicy(id: policy.id) }
                        }
                    )
                }
            }
            .padding(14)
        }
        .task {
            if let data = try? await APIService.shared.getAuditPolicies(), !data.isEmpty {
                await MainActor.run { policies = data }
            }
        }
    }

    private func runPolicy(id: String) async {
        await MainActor.run { runningId = id }
        try? await Task.sleep(nanoseconds: 1_500_000_000) // simulate run
        let today = todayLabel()
        await MainActor.run {
            if let i = policies.firstIndex(where: { $0.id == id }) {
                policies[i].lastRun = today
                policies[i].nextDue = "Scheduled"
            }
            runningId = nil
            toast = "Policy run completed"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { toast = "" }
        }
    }
}

struct AuditPolicyCard: View {
    @Binding var policy: AuditPolicy
    let isRunning: Bool
    let onRun: () -> Void

    var body: some View {
        SBCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(policy.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.sbOnSurface)
                            StatusBadge(status: policy.status)
                        }
                        Text(policy.description)
                            .font(.system(size: 11))
                            .foregroundColor(.sbOnSurfaceVariant)
                    }
                    Spacer()
                    Toggle("", isOn: $policy.active)
                        .tint(.sbPrimary)
                        .labelsHidden()
                }

                Divider().background(Color.sbOutline)

                HStack(spacing: 0) {
                    PolicyMeta(label: "Owner", value: policy.owner)
                    Divider().background(Color.sbOutline).frame(height: 28).padding(.horizontal, 10)
                    PolicyMeta(label: "Cadence", value: policy.cadence)
                    Divider().background(Color.sbOutline).frame(height: 28).padding(.horizontal, 10)
                    PolicyMeta(label: "Last Run", value: policy.lastRun.isEmpty ? "Never" : policy.lastRun)
                    Spacer()
                    Button(action: onRun) {
                        HStack(spacing: 5) {
                            if isRunning {
                                ProgressView().tint(.white).scaleEffect(0.7)
                                Text("Running…")
                            } else {
                                Image(systemName: "play.fill").font(.system(size: 10))
                                Text("Run")
                            }
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(isRunning ? Color.sbOnSurfaceDim : Color.sbPrimary)
                        .cornerRadius(8)
                    }
                    .disabled(isRunning)
                }
            }
        }
    }
}

struct PolicyMeta: View {
    let label: String; let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 9)).foregroundColor(.sbOnSurfaceDim)
            Text(value).font(.system(size: 11, weight: .semibold)).foregroundColor(.sbOnSurfaceVariant)
        }
    }
}

// MARK: - Event Log

struct AuditEventLogView: View {
    @State private var entries: [AuditLogEntry] = []
    @State private var isLoading = true
    @State private var riskFilter = "ALL"
    @State private var areaFilter = "ALL"
    @State private var searchText = ""

    let riskFilters = ["ALL", "LOW", "MEDIUM", "HIGH"]
    let areaFilters = ["ALL", "Feed", "Water", "Sampling", "Chemicals", "Users", "Reports"]

    var filtered: [AuditLogEntry] {
        entries.filter { entry in
            let matchRisk = riskFilter == "ALL" || entry.risk.uppercased() == riskFilter
            let matchArea = areaFilter == "ALL" || entry.event.localizedCaseInsensitiveContains(areaFilter)
            let matchSearch = searchText.isEmpty ||
                entry.event.localizedCaseInsensitiveContains(searchText) ||
                entry.user.localizedCaseInsensitiveContains(searchText) ||
                entry.detail.localizedCaseInsensitiveContains(searchText)
            return matchRisk && matchArea && matchSearch
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            VStack(spacing: 8) {
                // Search
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.sbOnSurfaceDim).font(.system(size: 13))
                    TextField("Search events, users…", text: $searchText)
                        .font(.system(size: 13)).foregroundColor(.sbOnSurface)
                        .accentColor(.sbPrimary)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.sbSurfaceElevated)
                .cornerRadius(10)
                .padding(.horizontal, 14).padding(.top, 10)

                // Risk filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(riskFilters, id: \.self) { f in
                            FilterPill(label: f, selected: riskFilter == f, color: riskPillColor(f)) {
                                riskFilter = f
                            }
                        }
                        Divider().background(Color.sbOutline).frame(height: 20)
                        ForEach(areaFilters.filter { $0 != "ALL" }, id: \.self) { f in
                            FilterPill(label: f, selected: areaFilter == f, color: .sbPrimary) {
                                areaFilter = f
                                if f != "ALL" && riskFilter != "ALL" { /* keep */ }
                            }
                        }
                        if areaFilter != "ALL" {
                            Button(action: { areaFilter = "ALL" }) {
                                Text("Clear area")
                                    .font(.system(size: 11)).foregroundColor(.sbOnSurfaceDim)
                            }
                        }
                    }
                    .padding(.horizontal, 14).padding(.bottom, 8)
                }
            }
            .background(Color.sbSurface)
            .overlay(Divider().background(Color.sbOutline), alignment: .bottom)

            if isLoading {
                Spacer(); ProgressView().tint(.sbPrimary); Spacer()
            } else if filtered.isEmpty {
                EmptyStateView(icon: "🛡️", title: "No Events",
                               message: "No audit events match the current filters.")
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(filtered) { entry in
                            SBCard {
                                HStack(alignment: .top, spacing: 10) {
                                    Circle().fill(entry.risk.statusColor)
                                        .frame(width: 8, height: 8).padding(.top, 5)
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(entry.event)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(.sbOnSurface)
                                            Spacer()
                                            StatusBadge(status: entry.risk)
                                        }
                                        Text(entry.detail)
                                            .font(.system(size: 11))
                                            .foregroundColor(.sbOnSurfaceVariant)
                                        HStack(spacing: 6) {
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 9))
                                                .foregroundColor(.sbOnSurfaceDim)
                                            Text(entry.user)
                                                .font(.system(size: 10))
                                                .foregroundColor(.sbOnSurfaceDim)
                                            Text("·")
                                            Text(entry.time)
                                                .font(.system(size: 10))
                                                .foregroundColor(.sbOnSurfaceDim)
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
        .task {
            if let data = try? await APIService.shared.getAuditLogs() {
                await MainActor.run { entries = data; isLoading = false }
            } else { await MainActor.run { isLoading = false } }
        }
    }

    func riskPillColor(_ filter: String) -> Color {
        switch filter {
        case "HIGH":   return .sbError
        case "MEDIUM": return .sbWarning
        case "LOW":    return .sbSuccess
        default:       return .sbPrimary
        }
    }
}

// MARK: - Compliance Issues

struct ComplianceIssuesView: View {
    @State private var issues: [ComplianceIssue] = defaultIssues
    @State private var isLoading = false
    @State private var filterRisk = "ALL"

    let riskFilters = ["ALL", "LOW", "MEDIUM", "HIGH"]

    var filtered: [ComplianceIssue] {
        filterRisk == "ALL" ? issues : issues.filter { $0.risk.uppercased() == filterRisk }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {

                // Summary metrics
                HStack(spacing: 8) {
                    SBMetricTile(value: "\(issues.count)", label: "Total Issues", color: .sbPrimary)
                    SBMetricTile(value: "\(issues.filter { $0.risk == "HIGH" }.count)",
                                 label: "High Risk", color: .sbError)
                    SBMetricTile(value: "\(issues.filter { $0.status == "STABLE" }.count)",
                                 label: "Resolved", color: .sbSuccess)
                }

                // Risk filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(riskFilters, id: \.self) { f in
                            FilterPill(label: f, selected: filterRisk == f,
                                       color: f == "HIGH" ? .sbError : f == "MEDIUM" ? .sbWarning : f == "LOW" ? .sbSuccess : .sbPrimary) {
                                filterRisk = f
                            }
                        }
                    }
                }

                if filtered.isEmpty {
                    EmptyStateView(icon: "✅", title: "No Issues",
                                   message: "All compliance checks are passing.")
                } else {
                    ForEach(filtered) { issue in
                        ComplianceIssueCard(issue: issue)
                    }
                }
            }
            .padding(14)
        }
        .task {
            if let data = try? await APIService.shared.getComplianceIssues(), !data.isEmpty {
                await MainActor.run { issues = data }
            }
        }
    }
}

struct ComplianceIssueCard: View {
    let issue: ComplianceIssue
    var body: some View {
        SBCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(issue.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.sbOnSurface)
                            StatusBadge(status: issue.risk)
                        }
                        Text(issue.detail)
                            .font(.system(size: 11))
                            .foregroundColor(.sbOnSurfaceVariant)
                    }
                    Spacer()
                    StatusBadge(status: issue.status)
                }

                Divider().background(Color.sbOutline)

                HStack(spacing: 0) {
                    PolicyMeta(label: "Area", value: issue.area)
                    Divider().background(Color.sbOutline).frame(height: 24).padding(.horizontal, 8)
                    PolicyMeta(label: "Owner", value: issue.owner)
                    Divider().background(Color.sbOutline).frame(height: 24).padding(.horizontal, 8)
                    PolicyMeta(label: "Due", value: issue.due)
                    Spacer()
                }

                if !issue.action.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 11)).foregroundColor(.sbPrimary)
                        Text(issue.action)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.sbPrimaryLight)
                    }
                }
            }
        }
    }
}

// MARK: - Filter Pill

struct FilterPill: View {
    let label: String
    let selected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: selected ? .bold : .medium))
                .foregroundColor(selected ? .white : .sbOnSurfaceVariant)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(selected ? color : Color.sbSurfaceElevated)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(selected ? Color.clear : Color.sbOutline, lineWidth: 0.8))
        }
    }
}

// MARK: - Default data (shown before API loads)

private let defaultPolicies: [AuditPolicy] = [
    AuditPolicy(id: "sampling", title: "Weekly sampling protocol",
                description: "Every active pond must have a weekly 1 kg count sample.",
                owner: "Farm Supervisor", cadence: "Weekly",
                lastRun: "Not run", nextDue: "Pending", active: true, status: "STABLE"),
    AuditPolicy(id: "feed-recon", title: "Feed reconciliation",
                description: "Manual feed logs are checked against expected pond feed.",
                owner: "Feed Manager", cadence: "Daily",
                lastRun: "Not run", nextDue: "Pending", active: true, status: "STABLE"),
    AuditPolicy(id: "chem-stock", title: "Chemical stock audit",
                description: "Central stock, dispatches, and pond usage must balance.",
                owner: "Inventory Lead", cadence: "Twice weekly",
                lastRun: "Not run", nextDue: "Pending", active: true, status: "ATTENTION"),
    AuditPolicy(id: "access-rev", title: "User access review",
                description: "Manager and supervisor permissions need approval.",
                owner: "Admin", cadence: "Monthly",
                lastRun: "Not run", nextDue: "Pending", active: true, status: "ATTENTION"),
]

private let defaultIssues: [ComplianceIssue] = [
    ComplianceIssue(id: "1", title: "Missing weekly samples",
                    area: "Sampling", owner: "Farm Supervisor",
                    due: "Overdue", detail: "3 ponds have not been sampled in the last 7 days.",
                    risk: "HIGH", status: "ATTENTION",
                    action: "Log sampling for all affected ponds immediately."),
    ComplianceIssue(id: "2", title: "Chemical rates not set",
                    area: "Chemicals", owner: "Inventory Lead",
                    due: "This week", detail: "2 chemical types are missing price rates, skewing finance totals.",
                    risk: "MEDIUM", status: "ATTENTION",
                    action: "Set rates in Price List & Rates → Chemicals."),
    ComplianceIssue(id: "3", title: "Feed dispatch not reconciled",
                    area: "Feed", owner: "Feed Manager",
                    due: "Yesterday", detail: "Feed dispatched yesterday has no matching feed log entries.",
                    risk: "MEDIUM", status: "ATTENTION",
                    action: "Log actual feed for all ponds in the affected section."),
]

// MARK: - Helpers

private func todayLabel() -> String {
    let f = DateFormatter(); f.dateFormat = "dd MMM yyyy"; return f.string(from: Date())
}

// MARK: - Legacy stub (keeps old references compiling)

extension AuditComplianceView {
    // The old stub AuditLogView now lives here for MainTabView compatibility
}
