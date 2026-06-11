import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var isLoading = false
    @State private var sent = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack { Color.sbSurface.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reset Password")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.sbOnSurface)
                        Text("We'll send reset instructions to your email.")
                            .font(.system(size: 13)).foregroundColor(.sbOnSurfaceVariant)
                    }

                    if sent {
                        VStack(spacing: 10) {
                            Text("📧").font(.system(size: 40))
                            Text("Check your inbox!").font(.system(size: 16, weight: .semibold))
                            Text("A reset link has been sent to \(email).")
                                .font(.system(size: 13)).foregroundColor(.sbOnSurfaceVariant)
                                .multilineTextAlignment(.center)
                            SBPrimaryButton("Back to Sign In") { dismiss() }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        SBTextField(label: "Farm Email", text: $email,
                                    placeholder: "you@farm.com", keyboardType: .emailAddress)
                        if let error = errorMessage {
                            Text(error).font(.system(size: 12)).foregroundColor(.sbError)
                                .padding(10).background(Color.sbErrorBg).cornerRadius(8)
                        }
                        SBPrimaryButton("Send Reset Link", isLoading: isLoading) {
                            Task { await sendLink() }
                        }
                    }
                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Forgot Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.sbSecondary)
                }
            }
        }
    }

    private func sendLink() async {
        guard !email.isEmpty else { errorMessage = "Enter your email address."; return }
        isLoading = true; errorMessage = nil
        do {
            try await APIService.shared.forgotPassword(email: email)
            await MainActor.run { sent = true; isLoading = false }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription; isLoading = false }
        }
    }
}

struct ResetPasswordView: View {
    @Environment(\.dismiss) var dismiss
    @State private var otp = ""
    @State private var newPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack { Color.sbSurface.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enter OTP Code")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.sbOnSurface)
                        Text("We sent a 4-digit code to your email.")
                            .font(.system(size: 13)).foregroundColor(.sbOnSurfaceVariant)
                    }
                    SBTextField(label: "OTP Code", text: $otp, placeholder: "4-digit code",
                                keyboardType: .numberPad)
                    SBTextField(label: "New Password", text: $newPassword,
                                placeholder: "Enter new password", isSecure: true)
                    if let error = errorMessage {
                        Text(error).font(.system(size: 12)).foregroundColor(.sbError)
                            .padding(10).background(Color.sbErrorBg).cornerRadius(8)
                    }
                    SBPrimaryButton("Update Password", isLoading: isLoading) {
                        Task { await reset() }
                    }
                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func reset() async {
        guard !otp.isEmpty, !newPassword.isEmpty else { errorMessage = "Fill in all fields."; return }
        isLoading = true; errorMessage = nil
        do {
            try await APIService.shared.resetPassword(otp: otp, newPassword: newPassword)
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription; isLoading = false }
        }
    }
}
