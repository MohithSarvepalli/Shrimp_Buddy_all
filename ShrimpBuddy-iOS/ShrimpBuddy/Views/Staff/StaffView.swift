import SwiftUI

// MARK: - User Management (matches web UsersScreen)

struct UserManagementView: View {
    @State private var users: [StaffUser] = []
    @State private var isLoading = true
    @State private var showAddUser = false
    @State private var editingUser: StaffUser? = nil
    @State private var searchText = ""

    let roleOrder = ["Admin", "Supervisor", "Worker"]

    var filteredUsers: [StaffUser] {
        if searchText.isEmpty { return users }
        return users.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.email.localizedCaseInsensitiveContains(searchText) ||
            $0.role.localizedCaseInsensitiveContains(searchText)
        }
    }

    // Group by role
    var grouped: [(role: String, users: [StaffUser])] {
        let sorted = filteredUsers.sorted { a, b in
            (roleOrder.firstIndex(of: normalizeRole(a.role)) ?? 99) <
            (roleOrder.firstIndex(of: normalizeRole(b.role)) ?? 99)
        }
        var result: [(role: String, users: [StaffUser])] = []
        for role in roleOrder {
            let group = sorted.filter { normalizeRole($0.role) == role }
            if !group.isEmpty { result.append((role, group)) }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            SBAppHeader(title: "User Management",
                        trailingAction: { showAddUser = true },
                        trailingLabel: "+ Add User")

            // Metrics row
            if !users.isEmpty {
                HStack(spacing: 8) {
                    UserStatTile(label: "Total", value: "\(users.count)", color: .sbPrimary)
                    UserStatTile(label: "Admins",
                                 value: "\(users.filter { normalizeRole($0.role) == "Admin" }.count)",
                                 color: Color(hex: "#9b59b6"))
                    UserStatTile(label: "Active",
                                 value: "\(users.filter { $0.status.uppercased() != "INACTIVE" }.count)",
                                 color: .sbSuccess)
                    UserStatTile(label: "Inactive",
                                 value: "\(users.filter { $0.status.uppercased() == "INACTIVE" }.count)",
                                 color: .sbOnSurfaceDim)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.sbSurface)
                .overlay(Divider().background(Color.sbOutline), alignment: .bottom)
            }

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.sbOnSurfaceDim).font(.system(size: 14))
                TextField("Search by name, email or role…", text: $searchText)
                    .font(.system(size: 14)).foregroundColor(.sbOnSurface)
                    .accentColor(.sbPrimary)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.sbOnSurfaceDim)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color.sbSurfaceElevated)
            .overlay(Divider().background(Color.sbOutline), alignment: .bottom)

            if isLoading {
                Spacer(); ProgressView().tint(.sbPrimary); Spacer()
            } else if users.isEmpty {
                EmptyStateView(icon: "👥", title: "No Users",
                               message: "Add your first team member.")
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(grouped, id: \.role) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(group.role.uppercased())
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.sbOnSurfaceDim).kerning(0.8)
                                    Text("· \(group.users.count)")
                                        .font(.system(size: 10)).foregroundColor(.sbOnSurfaceDim)
                                }
                                .padding(.horizontal, 4)

                                VStack(spacing: 0) {
                                    ForEach(group.users) { user in
                                        UserRow(user: user, onEdit: { editingUser = user })
                                        if user.id != group.users.last?.id {
                                            Divider().background(Color.sbOutline).padding(.leading, 68)
                                        }
                                    }
                                }
                                .background(Color.sbSurface)
                                .cornerRadius(14)
                                .overlay(RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.sbOutline, lineWidth: 0.8))
                            }
                        }
                    }
                    .padding(14)
                }
            }
        }
        .background(Color.sbBg.ignoresSafeArea())
        .task {
            if let data = try? await APIService.shared.getUsers() {
                await MainActor.run { users = data; isLoading = false }
            } else { await MainActor.run { isLoading = false } }
        }
        .sheet(isPresented: $showAddUser, onDismiss: { Task { await reload() } }) {
            AddUserSheet()
        }
        .sheet(item: $editingUser, onDismiss: { Task { await reload() } }) { user in
            EditUserSheet(user: user)
        }
    }

    private func reload() async {
        if let data = try? await APIService.shared.getUsers() {
            await MainActor.run { users = data }
        }
    }
}

// MARK: - User Row

struct UserRow: View {
    let user: StaffUser
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(roleGradient(user.role))
                    .frame(width: 42, height: 42)
                Text(user.initials)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(user.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.sbOnSurface)
                    RoleBadge(role: user.role)
                }
                Text(user.email)
                    .font(.system(size: 11)).foregroundColor(.sbOnSurfaceVariant)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(status: user.status)
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.sbOnSurfaceDim)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}

struct RoleBadge: View {
    let role: String
    var color: Color {
        switch normalizeRole(role) {
        case "Admin":      return Color(hex: "#9b59b6")
        case "Supervisor": return .sbWarning
        default:           return .sbOnSurfaceVariant
        }
    }
    var body: some View {
        Text(role)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }
}

struct UserStatTile: View {
    let label: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 18, weight: .bold)).foregroundColor(color)
            Text(label).font(.system(size: 9)).foregroundColor(.sbOnSurfaceVariant)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .background(Color.sbBg).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.sbOutline, lineWidth: 0.8))
    }
}

// MARK: - Add User Sheet

struct AddUserSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var role = "Worker"
    @State private var section = "All Sections"
    @State private var availableSections: [FarmSection] = []
    @State private var isLoading = false
    @State private var errorMsg = ""
    @State private var showPassword = false

    let roles = ["Admin", "Supervisor", "Worker"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.sbBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        if !errorMsg.isEmpty {
                            Text(errorMsg)
                                .font(.system(size: 12)).foregroundColor(.sbError)
                                .padding(10).background(Color.sbErrorBg).cornerRadius(8)
                        }

                        SBTextField(label: "Full Name", text: $name, placeholder: "e.g. Ravi Kumar")
                        SBTextField(label: "Email", text: $email, placeholder: "ravi@farm.com")

                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text("PASSWORD").font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.sbOnSurfaceVariant).kerning(0.6)
                                Spacer()
                                Button(action: {
                                    password = generateTempPassword()
                                }) {
                                    Text("Generate")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.sbPrimaryLight)
                                }
                            }
                            HStack {
                                if showPassword {
                                    TextField("Temporary password", text: $password)
                                        .textFieldStyle(SBInputStyle())
                                } else {
                                    SecureField("Temporary password", text: $password)
                                        .textFieldStyle(SBInputStyle())
                                }
                                Button(action: { showPassword.toggle() }) {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.sbOnSurfaceDim)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("ROLE").font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.sbOnSurfaceVariant).kerning(0.6)
                            SBSegmentedPicker(options: roles, selection: $role)
                            Text(roleDesc(role))
                                .font(.system(size: 11)).foregroundColor(.sbOnSurfaceVariant)
                                .padding(.top, 2)
                        }

                        // Section access dropdown
                        VStack(alignment: .leading, spacing: 6) {
                            Text("SECTION ACCESS").font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.sbOnSurfaceVariant).kerning(0.6)
                            Menu {
                                Button("All Sections") { section = "All Sections" }
                                if !availableSections.isEmpty { Divider() }
                                ForEach(availableSections) { sec in
                                    Button(sec.name) { section = sec.name }
                                }
                            } label: {
                                HStack {
                                    Text(section)
                                        .font(.system(size: 14)).foregroundColor(.sbOnSurface)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 12)).foregroundColor(.sbOnSurfaceDim)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 11)
                                .background(Color.sbSurface)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.sbOutline, lineWidth: 0.8))
                            }
                        }

                        // Permissions preview
                        PermissionsPreview(role: role)

                        SBPrimaryButton("Create User", isLoading: isLoading) {
                            Task { await createUser() }
                        }
                        Spacer()
                    }.padding(20)
                }
            }
            .navigationTitle("Add User").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }.foregroundColor(.sbPrimaryLight)
            }}
            .preferredColorScheme(.dark)
            .onAppear { password = generateTempPassword() }
            .task { availableSections = (try? await APIService.shared.getSections()) ?? [] }
        }
    }

    private func createUser() async {
        guard !name.isEmpty, !email.isEmpty, !password.isEmpty else {
            errorMsg = "Name, email and password are required."; return
        }
        isLoading = true; errorMsg = ""
        let req = CreateUserRequest(name: name, email: email, password: password,
                                    role: role, section: section)
        do {
            _ = try await APIService.shared.createUser(req)
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run { errorMsg = error.localizedDescription; isLoading = false }
        }
    }
}

// MARK: - Edit User Sheet

struct EditUserSheet: View {
    @Environment(\.dismiss) var dismiss
    let user: StaffUser
    @State private var name: String
    @State private var role: String
    @State private var section: String
    @State private var status: String
    @State private var availableSections: [FarmSection] = []
    @State private var newPassword = ""
    @State private var isLoading = false
    @State private var errorMsg = ""

    let roles = ["Admin", "Supervisor", "Worker"]

    init(user: StaffUser) {
        self.user = user
        _name    = State(initialValue: user.name)
        _role    = State(initialValue: normalizeRole(user.role))
        _section = State(initialValue: user.section ?? "All Sections")
        _status  = State(initialValue: user.status.uppercased() == "INACTIVE" ? "INACTIVE" : "STABLE")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.sbBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        if !errorMsg.isEmpty {
                            Text(errorMsg)
                                .font(.system(size: 12)).foregroundColor(.sbError)
                                .padding(10).background(Color.sbErrorBg).cornerRadius(8)
                        }

                        // User avatar header
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(roleGradient(user.role)).frame(width: 52, height: 52)
                                Text(user.initials)
                                    .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(user.name)
                                    .font(.system(size: 15, weight: .bold)).foregroundColor(.sbOnSurface)
                                Text(user.email)
                                    .font(.system(size: 12)).foregroundColor(.sbOnSurfaceVariant)
                            }
                            Spacer()
                        }
                        .padding(14).background(Color.sbSurface).cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sbOutline, lineWidth: 0.8))

                        SBTextField(label: "Full Name", text: $name, placeholder: user.name)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("ROLE").font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.sbOnSurfaceVariant).kerning(0.6)
                            SBSegmentedPicker(options: roles, selection: $role)
                            Text(roleDesc(role))
                                .font(.system(size: 11)).foregroundColor(.sbOnSurfaceVariant)
                                .padding(.top, 2)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("STATUS").font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.sbOnSurfaceVariant).kerning(0.6)
                            SBSegmentedPicker(options: ["Active", "Inactive"],
                                             selection: Binding(
                                                get: { status == "STABLE" ? "Active" : "Inactive" },
                                                set: { status = $0 == "Active" ? "STABLE" : "INACTIVE" }
                                             ))
                        }

                        // Section access dropdown
                        VStack(alignment: .leading, spacing: 6) {
                            Text("SECTION ACCESS").font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.sbOnSurfaceVariant).kerning(0.6)
                            Menu {
                                Button("All Sections") { section = "All Sections" }
                                if !availableSections.isEmpty { Divider() }
                                ForEach(availableSections) { sec in
                                    Button(sec.name) { section = sec.name }
                                }
                            } label: {
                                HStack {
                                    Text(section.isEmpty ? "All Sections" : section)
                                        .font(.system(size: 14)).foregroundColor(.sbOnSurface)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 12)).foregroundColor(.sbOnSurfaceDim)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 11)
                                .background(Color.sbSurface)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.sbOutline, lineWidth: 0.8))
                            }
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text("NEW PASSWORD (optional)").font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.sbOnSurfaceVariant).kerning(0.6)
                            SecureField("Leave blank to keep current", text: $newPassword)
                                .textFieldStyle(SBInputStyle())
                        }

                        SBPrimaryButton("Save Changes", isLoading: isLoading) {
                            Task { await saveUser() }
                        }

                        Spacer()
                    }.padding(20)
                }
            }
            .navigationTitle("Edit User").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }.foregroundColor(.sbPrimaryLight)
            }}
            .preferredColorScheme(.dark)
            .task { availableSections = (try? await APIService.shared.getSections()) ?? [] }
        }
    }

    private func saveUser() async {
        isLoading = true; errorMsg = ""
        let req = UpdateUserRequest(
            name: name.isEmpty ? nil : name,
            role: role,
            section: section.isEmpty ? nil : section,
            status: status,
            password: newPassword.isEmpty ? nil : newPassword)
        do {
            _ = try await APIService.shared.updateUser(id: user.id, req)
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run { errorMsg = error.localizedDescription; isLoading = false }
        }
    }
}

// MARK: - Permissions Preview

struct PermissionsPreview: View {
    let role: String

    var permissions: [(String, Bool)] {
        switch normalizeRole(role) {
        case "Admin": return [
            ("Ponds", true), ("Feed", true), ("Sampling", true),
            ("Chemicals", true), ("Reports", true),
            ("Finance", true), ("Users", true), ("Settings", true)
        ]
        case "Supervisor": return [
            ("Ponds", true), ("Feed", true), ("Sampling", true),
            ("Chemicals", true), ("Reports", true),
            ("Finance", false), ("Users", false), ("Settings", false)
        ]
        default: return [
            ("Ponds", true), ("Feed", true), ("Sampling", false),
            ("Chemicals", false), ("Reports", false),
            ("Finance", false), ("Users", false), ("Settings", false)
        ]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PERMISSIONS").font(.system(size: 10, weight: .semibold))
                .foregroundColor(.sbOnSurfaceVariant).kerning(0.6)

            let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()),
                        GridItem(.flexible())]
            LazyVGrid(columns: cols, spacing: 6) {
                ForEach(permissions, id: \.0) { name, allowed in
                    HStack(spacing: 5) {
                        Image(systemName: allowed ? "checkmark.circle.fill" : "xmark.circle")
                            .font(.system(size: 11))
                            .foregroundColor(allowed ? .sbSuccess : .sbOnSurfaceDim)
                        Text(name)
                            .font(.system(size: 10))
                            .foregroundColor(allowed ? .sbOnSurface : .sbOnSurfaceDim)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(12)
        .background(Color.sbSurfaceElevated)
        .cornerRadius(10)
    }
}

// MARK: - Helpers

func normalizeRole(_ raw: String) -> String {
    switch raw.lowercased() {
    case "admin", "farm manager": return "Admin"
    case "supervisor", "section supervisor": return "Supervisor"
    default: return "Worker"
    }
}

func roleDesc(_ role: String) -> String {
    switch role {
    case "Admin": return "Full access: ponds, feed, sampling, chemicals, finance, users & settings."
    case "Supervisor": return "Section access: ponds, feed, sampling, chemicals & reports. No finance or user management."
    default: return "Basic access: ponds and feed logging only."
    }
}

func roleGradient(_ role: String) -> LinearGradient {
    switch normalizeRole(role) {
    case "Admin":
        return LinearGradient(colors: [Color(hex: "#6a11cb"), Color(hex: "#2575fc")],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    case "Supervisor":
        return LinearGradient(colors: [Color(hex: "#f0a020"), Color(hex: "#e06010")],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    default:
        return LinearGradient(colors: [Color(hex: "#1a3a6a"), Color(hex: "#0d2248")],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

func generateTempPassword() -> String {
    let chars = "abcdefghjkmnpqrstuvwxyz23456789"
    let suffix = (0..<8).map { _ in String(chars.randomElement()!) }.joined()
    return "shrimpbuddy-\(suffix)"
}

// MARK: - Legacy Stubs (kept for backwards compatibility)

struct StaffView: View {
    var body: some View { UserManagementView() }
}

struct StaffDirectoryView: View {
    var body: some View { UserManagementView() }
}
