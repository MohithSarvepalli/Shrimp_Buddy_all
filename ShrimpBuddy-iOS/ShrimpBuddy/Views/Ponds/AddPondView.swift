import SwiftUI

struct AddPondView: View {
    @Environment(\.dismiss) var dismiss
    let sections: [Section]
    @State private var selectedSection: Section?
    @State private var pondId = ""
    @State private var stockedDate = Date()
    @State private var seedCount = ""
    @State private var type = "Vannamei"
    @State private var isLoading = false
    @State private var error: String?

    let speciesOptions = ["Vannamei", "Black Tiger", "Monodon"]

    var body: some View {
        NavigationStack {
            ZStack { Color.sbSurface.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        SBCard {
                            VStack(spacing: 14) {
                                // Section picker
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("SECTION").font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.sbOnSurfaceVariant)
                                    Picker("Section", selection: $selectedSection) {
                                        Text("Select section").tag(Section?.none)
                                        ForEach(sections) { sec in
                                            Text(sec.name).tag(Section?.some(sec))
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .frame(height: 44)
                                    .background(Color.sbSurface)
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.sbOutline, lineWidth: 1))
                                }

                                SBTextField(label: "Pond ID / Code", text: $pondId, placeholder: "e.g. A5")

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("STOCKING DATE").font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.sbOnSurfaceVariant)
                                    DatePicker("", selection: $stockedDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                SBTextField(label: "Seed Count", text: $seedCount,
                                            placeholder: "e.g. 100000", keyboardType: .numberPad)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("SPECIES TYPE").font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.sbOnSurfaceVariant)
                                    Picker("Type", selection: $type) {
                                        ForEach(speciesOptions, id: \.self) { Text($0).tag($0) }
                                    }
                                    .pickerStyle(.segmented)
                                }
                            }
                        }

                        if let error = error {
                            Text(error).font(.system(size: 12)).foregroundColor(.sbError)
                                .padding(10).background(Color.sbErrorBg).cornerRadius(8)
                        }

                        SBPrimaryButton("Create Pond", isLoading: isLoading) {
                            Task { await createPond() }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("New Pond")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.sbSecondary)
                }
            }
        }
    }

    private func createPond() async {
        guard let sec = selectedSection, !pondId.isEmpty, let count = Int(seedCount) else {
            error = "Please fill in all fields."; return
        }
        isLoading = true; error = nil
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let req = CreatePondRequest(sectionId: sec.id, pondId: pondId,
                                    stockedDate: fmt.string(from: stockedDate),
                                    seedCount: count, type: type)
        do {
            _ = try await APIService.shared.createPond(req)
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run { self.error = error.localizedDescription; isLoading = false }
        }
    }
}
