import SwiftUI

struct SectionsView: View {
    @State private var sections: [Section] = []
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            SBAppHeader(title: "Farm Sections")
            if isLoading { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
            else if sections.isEmpty {
                EmptyStateView(icon: "🏞", title: "No Sections", message: "Add your first farm section.")
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(sections) { sec in
                            SBCard {
                                VStack(spacing: 8) {
                                    HStack {
                                        Text(sec.name)
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(.sbPrimary)
                                        Spacer()
                                        Text("Code: \(sec.code)")
                                            .font(.system(size: 11)).foregroundColor(.sbOnSurfaceVariant)
                                    }
                                    Divider()
                                    HStack(spacing: 20) {
                                        SectionMetric(label: "Ponds", value: "\(sec.pondCount)")
                                        SectionMetric(label: "Biomass", value: "\(sec.biomassKg, specifier: "%.0f") kg")
                                        SectionMetric(label: "Stocked", value: String(sec.stockedDate.suffix(5)))
                                    }
                                }
                            }
                        }
                    }.padding(14)
                }
            }
        }
        .background(Color.sbSurface)
        .task { if let data = try? await APIService.shared.getSections() {
            await MainActor.run { sections = data; isLoading = false }
        } else { await MainActor.run { isLoading = false }}}
    }
}

struct SectionMetric: View {
    let label: String; let value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundColor(.sbOnSurface)
            Text(label).font(.system(size: 9)).foregroundColor(.sbOnSurfaceVariant)
        }.frame(maxWidth: .infinity)
    }
}
