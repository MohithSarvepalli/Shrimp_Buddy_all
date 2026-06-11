import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authState: AuthStateObject
    @State private var farmName = ""
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var agreedToTerms = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.sbSurface.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Create Farm Workspace")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.sbOnSurface)
                            Text("Set up a new smart aquaculture farm")
                                .font(.system(size: 13))
                                .foregroundColor(.sbOnSurfaceVariant)
                        }
                        .padding(.top, 10)

                        VStack(spacing: 14) {
                            SBTextField(label: "Farm Name", text: $farmName, placeholder: "Blue Ocean Aquafarm")
                            SBTextField(label: "Your Name", text: $name, placeholder: "Full name")
                            SBTextField(label: "Email Address", text: $email,
                                        placeholder: "you@farm.com", keyboardType: .emailAddress)
                            SBTextField(label: "Password", text: $password,
                                        placeholder: "Min. 8 characters", isSecure: true)
                        }

                        Toggle(isOn: $agreedToTerms) {
                            Text("I agree to the Aquaculture Biosecurity and Data Protection Policy.")
                                .font(.system(size: 12))
                                .foregroundColor(.sbOnSurfaceVariant)
                        }
                        .tint(.sbSecondary)

                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundColor(.sbError)
                                .padding(10)
                                .background(Color.sbErrorBg)
                                .cornerRadius(8)
                        }

                        SBPrimaryButton("Register Workspace", isLoading: isLoading) {
                            Task { await performRegister() }
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Sign Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.sbSecondary)
                }
            }
        }
    }

    private func performRegister() async {
        guard !farmName.isEmpty, !name.isEmpty, !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }
        guard agreedToTerms else {
            errorMessage = "You must agree to the terms to continue."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let response = try await APIService.shared.register(
                farmName: farmName, name: name, email: email, password: password)
            await MainActor.run {
                authState.login(user: response.user)
                dismiss()
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription; isLoading = false }
        }
    }
}
