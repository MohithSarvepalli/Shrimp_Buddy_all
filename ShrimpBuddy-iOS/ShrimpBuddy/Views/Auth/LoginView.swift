import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authState: AuthStateObject
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showRegister = false
    @State private var showForgotPassword = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Deep navy gradient background
                LinearGradient(
                    colors: [Color(hex: "#020912"), Color(hex: "#060e1c"), Color(hex: "#091628")],
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()

                // Subtle blue glow orb top-center
                Circle()
                    .fill(Color(hex: "#4487e0").opacity(0.08))
                    .frame(width: 320, height: 320)
                    .blur(radius: 60)
                    .offset(y: -160)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {

                        // ── Logo & Brand ─────────────────────────────────────
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "#1a3560"))
                                    .frame(width: 80, height: 80)
                                    .overlay(Circle().stroke(Color(hex: "#4487e0").opacity(0.4), lineWidth: 1.5))
                                Text("🦐")
                                    .font(.system(size: 36))
                            }
                            .shadow(color: Color(hex: "#4487e0").opacity(0.4), radius: 20)

                            Text("Shrimp Buddy")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(Color.sbOnSurface)

                            Text("SMART AQUACULTURE MANAGEMENT")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color.sbOnSurfaceVariant)
                                .kerning(1.4)
                        }
                        .padding(.top, 72)
                        .padding(.bottom, 44)

                        // ── Form Card ────────────────────────────────────────
                        VStack(spacing: 18) {
                            SBTextField(label: "Farm Email", text: $email,
                                        placeholder: "you@farm.com",
                                        keyboardType: .emailAddress)

                            SBTextField(label: "Password", text: $password,
                                        placeholder: "Enter password",
                                        isSecure: true)

                            HStack {
                                Spacer()
                                Button("Forgot Password?") { showForgotPassword = true }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color.sbPrimaryLight)
                            }

                            if let error = errorMessage {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.sbError).font(.system(size: 13))
                                    Text(error)
                                        .font(.system(size: 13))
                                        .foregroundColor(.sbError)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.sbErrorBg)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.sbError.opacity(0.3), lineWidth: 1))
                            }

                            SBPrimaryButton("Sign In", isLoading: isLoading) {
                                Task { await performLogin() }
                            }

                            HStack {
                                Rectangle().fill(Color.sbOutline).frame(height: 1)
                                Text("OR").font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.sbOnSurfaceDim).padding(.horizontal, 8)
                                Rectangle().fill(Color.sbOutline).frame(height: 1)
                            }

                            SBSecondaryButton("Create Farm Workspace") {
                                showRegister = true
                            }
                        }
                        .padding(.horizontal, 24)

                        Text("By signing in you agree to our Terms & Privacy Policies.")
                            .font(.system(size: 11))
                            .foregroundColor(Color.sbOnSurfaceDim)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.top, 32)
                            .padding(.bottom, 48)
                    }
                }
            }
            .navigationBarHidden(true)
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showRegister) { RegisterView() }
            .sheet(isPresented: $showForgotPassword) { ForgotPasswordView() }
        }
    }

    private func performLogin() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your email and password."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let response = try await APIService.shared.login(email: email, password: password)
            await MainActor.run { authState.login(user: response.user) }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}
