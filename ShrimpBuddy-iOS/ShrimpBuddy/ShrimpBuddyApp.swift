import SwiftUI

@main
struct ShrimpBuddyApp: App {
    @StateObject private var authState = AuthStateObject()

    var body: some Scene {
        WindowGroup {
            if authState.isLoggedIn {
                MainTabView()
                    .environmentObject(authState)
            } else {
                LoginView()
                    .environmentObject(authState)
            }
        }
    }
}

// MARK: - Auth State

class AuthStateObject: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: AppUser?
    @Published var currentFarm: FarmResponse?

    init() {
        isLoggedIn = TokenStore.shared.token != nil && TokenStore.shared.farmId != nil
    }

    /// Re-fetches farm data so feedManagementMode / chemManagementMode are always current.
    func refreshFarm() async {
        guard TokenStore.shared.token != nil,
              let savedFarmId = TokenStore.shared.farmId else { return }
        guard let farms = try? await APIService.shared.getMyFarms() else { return }
        let farm = farms.first(where: { $0.id == savedFarmId }) ?? farms.first
        guard let farm else { return }
        await MainActor.run { currentFarm = farm }
    }

    func login(user: AppUser) {
        currentUser = user
        isLoggedIn = true
    }

    func logout() {
        APIService.shared.logout()
        currentUser = nil
        currentFarm = nil
        isLoggedIn = false
    }
}
