import SwiftUI

// MARK: - Shrimp Buddy Dark Design Tokens
// Palette derived from web UI (#001142 / #0060ab) adapted for dark mobile

extension Color {
    // Backgrounds
    static let sbBg               = Color(hex: "#060e1c")   // page background
    static let sbSurface          = Color(hex: "#0c1a2f")   // card surface
    static let sbSurfaceElevated  = Color(hex: "#112238")   // raised cards
    static let sbSurfaceHigh      = Color(hex: "#162e48")   // highlighted rows
    static let sbOutline          = Color(hex: "#1e3355")   // borders
    static let sbOutlineVariant   = Color(hex: "#284470")   // softer borders

    // Brand Blues (from web: #0060ab → lightened for dark bg contrast)
    static let sbPrimary          = Color(hex: "#4487e0")   // main interactive
    static let sbPrimaryLight     = Color(hex: "#7ab0ff")   // secondary/highlight
    static let sbPrimaryDim       = Color(hex: "#1a3560")   // tinted bg areas

    // Text
    static let sbOnSurface        = Color(hex: "#dce9ff")   // primary text
    static let sbOnSurfaceVariant = Color(hex: "#6a8cb5")   // muted text
    static let sbOnSurfaceDim     = Color(hex: "#3d5a82")   // very muted

    // Semantic
    static let sbSuccess          = Color(hex: "#35c96e")
    static let sbWarning          = Color(hex: "#f0a020")
    static let sbError            = Color(hex: "#f04545")
    static let sbInfo             = Color(hex: "#7ab0ff")

    static let sbSuccessBg        = Color(hex: "#0a2d1a")
    static let sbWarningBg        = Color(hex: "#2a1e06")
    static let sbErrorBg          = Color(hex: "#2a0a0a")
    static let sbInfoBg           = Color(hex: "#0a1e38")

    // Legacy aliases (so existing code still compiles)
    static let sbSecondary        = Color(hex: "#4487e0")
    static let sbSurfaceLow       = Color(hex: "#0c1a2f")
    static let sbSurfaceContainer = Color(hex: "#112238")
    static let sbPrimaryContainer = Color(hex: "#1a3560")
    static let sbOnPrimaryContainer = Color(hex: "#7ab0ff")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a,r,g,b) = (255,(int>>8)*17,(int>>4&0xF)*17,(int&0xF)*17)
        case 6:  (a,r,g,b) = (255,int>>16,int>>8&0xFF,int&0xFF)
        case 8:  (a,r,g,b) = (int>>24,int>>16&0xFF,int>>8&0xFF,int&0xFF)
        default: (a,r,g,b) = (1,1,1,0)
        }
        self.init(.sRGB, red:Double(r)/255, green:Double(g)/255,
                  blue:Double(b)/255, opacity:Double(a)/255)
    }
}

// MARK: - Status Helpers

extension String {
    var statusColor: Color {
        switch self.uppercased() {
        case "STABLE":    return .sbSuccess
        case "ATTENTION": return .sbWarning
        case "CRITICAL":  return .sbError
        case "HIGH":      return .sbError
        case "MEDIUM":    return .sbWarning
        case "LOW":       return .sbSuccess
        default:          return .sbOnSurfaceVariant
        }
    }
    var statusBgColor: Color {
        switch self.uppercased() {
        case "STABLE":    return .sbSuccessBg
        case "ATTENTION": return .sbWarningBg
        case "CRITICAL":  return .sbErrorBg
        case "HIGH":      return .sbErrorBg
        case "MEDIUM":    return .sbWarningBg
        case "LOW":       return .sbSuccessBg
        default:          return .sbSurfaceElevated
        }
    }
}

// MARK: - Card

struct SBCard<Content: View>: View {
    let content: Content
    var elevated: Bool = false
    init(elevated: Bool = false, @ViewBuilder content: () -> Content) {
        self.elevated = elevated; self.content = content()
    }
    var body: some View {
        content
            .padding(14)
            .background(elevated ? Color.sbSurfaceElevated : Color.sbSurface)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sbOutline, lineWidth: 0.8))
    }
}

// MARK: - Buttons

struct SBPrimaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void
    init(_ title: String, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title; self.isLoading = isLoading; self.action = action
    }
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading { ProgressView().tint(.white).scaleEffect(0.85) }
                Text(isLoading ? "Please wait…" : title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(
                LinearGradient(colors: [Color(hex: "#3a7fde"), Color(hex: "#1c5cbf")],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(14)
        }
        .disabled(isLoading)
    }
}

struct SBSecondaryButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color.sbPrimaryLight)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(Color.sbPrimaryDim)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.sbOutlineVariant, lineWidth: 1))
        }
    }
}

// MARK: - Text Field

struct SBTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.sbOnSurfaceVariant)
                .kerning(0.6)
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(SBInputStyle())
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(SBInputStyle())
                    .keyboardType(keyboardType)
            }
        }
    }
}

struct SBInputStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundColor(Color.sbOnSurface)
            .accentColor(Color.sbPrimary)
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(Color.sbSurfaceElevated)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(Color.sbOutline, lineWidth: 1))
            .font(.system(size: 15))
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: String
    var body: some View {
        Text(status.capitalized)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(status.statusColor)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(status.statusBgColor)
            .cornerRadius(20)
    }
}

// MARK: - App Header (dark)

struct SBAppHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailingAction: (() -> Void)? = nil
    var trailingLabel: String? = nil

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                if let sub = subtitle {
                    Text(sub).font(.system(size: 11, weight: .medium))
                        .foregroundColor(.sbOnSurfaceVariant)
                }
                Text(title).font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.sbOnSurface)
            }
            Spacer()
            if let action = trailingAction, let label = trailingLabel {
                Button(action: action) {
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.sbPrimaryLight)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color.sbPrimaryDim)
                        .cornerRadius(10)
                }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(Color.sbSurface)
        .overlay(Divider().background(Color.sbOutline), alignment: .bottom)
    }
}

// MARK: - Section Header Pill Tabs (for Ponds & detail screens)

struct SBSectionPillTabs: View {
    let sections: [String]
    @Binding var selected: String
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(sections, id: \.self) { sec in
                    Button(action: { withAnimation(.spring(response: 0.3)) { selected = sec } }) {
                        Text(sec)
                            .font(.system(size: 13, weight: selected == sec ? .bold : .medium))
                            .foregroundColor(selected == sec ? .white : .sbOnSurfaceVariant)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(selected == sec
                                ? Color.sbPrimary
                                : Color.sbSurfaceElevated)
                            .cornerRadius(20)
                            .overlay(RoundedRectangle(cornerRadius: 20)
                                .stroke(selected == sec
                                    ? Color.clear
                                    : Color.sbOutline, lineWidth: 0.8))
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .background(Color.sbSurface)
        .overlay(Divider().background(Color.sbOutline), alignment: .bottom)
    }
}

// MARK: - Segmented Picker (pill-style, blue selected state — matches SBSectionPillTabs)
// Use instead of .pickerStyle(.segmented) because iOS 26 liquid glass makes the
// selected state transparent when using the system picker with .tint().

struct SBSegmentedPicker: View {
    let options: [String]            // each option is both value and label
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { opt in
                Button {
                    withAnimation(.spring(response: 0.3)) { selection = opt }
                } label: {
                    Text(opt)
                        .font(.system(size: 13, weight: selection == opt ? .bold : .medium))
                        .foregroundColor(selection == opt ? .white : .sbOnSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(selection == opt ? Color.sbPrimary : Color.sbSurfaceElevated)
                        .cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20)
                            .stroke(selection == opt ? Color.clear : Color.sbOutline, lineWidth: 0.8))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String; let title: String; let message: String
    var body: some View {
        VStack(spacing: 14) {
            Text(icon).font(.system(size: 44))
            Text(title).font(.system(size: 17, weight: .semibold)).foregroundColor(.sbOnSurface)
            Text(message).font(.system(size: 13)).foregroundColor(.sbOnSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .padding(36).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Metric Tile (small labeled value)

struct SBMetricTile: View {
    let value: String; let label: String; let color: Color
    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 18, weight: .bold)).foregroundColor(color)
            Text(label).font(.system(size: 10, weight: .medium))
                .foregroundColor(.sbOnSurfaceVariant).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.sbSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sbOutline, lineWidth: 0.8))
    }
}
