import AppKit
import SwiftUI

/// Centralized SwiftUI equivalents of the normative tokens in DESIGN.md.
///
/// Player-facing surfaces use square, bronze-framed controls. Library and
/// diagnostic surfaces may use the native card radius while sharing this
/// color and typography hierarchy.
enum EmperorTheme {
    private static let regularFontName = "SarasaTermSCNerd-Regular"
    private static let semiboldFontName = "SarasaTermSCNerd-SemiBold"
    private static let boldFontName = "SarasaTermSCNerd-Bold"

    // MARK: Colors

    static let backgroundApp = Color(red: 14 / 255, green: 17 / 255, blue: 14 / 255)
    static let surface = Color(red: 56 / 255, green: 31 / 255, blue: 17 / 255)
    static let surfaceDeep = Color(red: 27 / 255, green: 17 / 255, blue: 9 / 255)
    static let surfaceRaised = Color(red: 74 / 255, green: 38 / 255, blue: 17 / 255)
    static let surfaceControl = Color(red: 77 / 255, green: 46 / 255, blue: 24 / 255)
    static let primary = Color(red: 240 / 255, green: 186 / 255, blue: 64 / 255)
    static let onPrimary = Color(red: 38 / 255, green: 20 / 255, blue: 9 / 255)
    static let secondary = Color(red: 166 / 255, green: 99 / 255, blue: 41 / 255)
    static let tertiary = Color(red: 199 / 255, green: 46 / 255, blue: 26 / 255)
    static let onSurface = Color(red: 255 / 255, green: 248 / 255, blue: 232 / 255)
    static let onSurfaceMuted = Color(red: 200 / 255, green: 185 / 255, blue: 163 / 255)
    static let success = Color(red: 111 / 255, green: 175 / 255, blue: 104 / 255)
    static let warning = Color(red: 229 / 255, green: 139 / 255, blue: 42 / 255)
    static let error = Color(red: 199 / 255, green: 46 / 255, blue: 26 / 255)
    static let overlayScrim = Color.black.opacity(0.62)

    // Compatibility names used by the classic city shell.
    static let gold = primary
    static let ink = onPrimary
    static let red = error
    static let warmBrown = surfaceRaised
    static let panelBrown = surface
    static let panelHeader = surfaceDeep
    static let deepBrown = surfaceDeep
    static let tileBrown = surfaceControl
    static let border = secondary.opacity(0.72)

    // MARK: Layout

    /// The original city screen renders into a 1024 × 768 logical canvas.
    /// Keeping these dimensions centralized makes screenshot comparison
    /// deterministic and prevents the map / HUD split from drifting.
    static let classicViewportSize = CGSize(width: 1_024, height: 768)
    static let cityMapColumnWidth: CGFloat = 800
    static let hudHeight: CGFloat = 40
    static let panelWidth: CGFloat = 224
    static let panelHeaderHeight: CGFloat = 34
    static let categoryRailWidth: CGFloat = 54
    static let commandRowHeight: CGFloat = 36
    static let populationAdvisorHeight: CGFloat = 210
    static let cityNavigationHeight: CGFloat = 40
    static let minimapSize = CGSize(width: 112, height: 112)
    static let nativeCardRadius: CGFloat = 12
    static let nativeModalRadius: CGFloat = 22

    static func classicIntegerScale(fitting size: CGSize) -> CGFloat {
        max(
            1,
            floor(
                min(
                    size.width / classicViewportSize.width,
                    size.height / classicViewportSize.height
                )
            )
        )
    }

    // MARK: Typography

    static let display = bold(size: 28)
    static let headlineLarge = bold(size: 20)
    static let headlineMedium = bold(size: 17)
    static let headlineSmall = semibold(size: 14)
    static let bodyMedium = regular(size: 13)
    static let bodySmall = regular(size: 12)
    static let labelMedium = semibold(size: 11)
    static let labelSmall = semibold(size: 10)
    static let caption = regular(size: 9)
    static let metric = bold(size: 12)

    static func regular(size: CGFloat) -> Font {
        appFont(named: regularFontName, size: size, fallbackWeight: .regular)
    }

    static func semibold(size: CGFloat) -> Font {
        appFont(named: semiboldFontName, size: size, fallbackWeight: .semibold)
    }

    static func bold(size: CGFloat) -> Font {
        appFont(named: boldFontName, size: size, fallbackWeight: .bold)
    }

    private static func appFont(
        named postScriptName: String,
        size: CGFloat,
        fallbackWeight: Font.Weight
    ) -> Font {
        guard NSFont(name: postScriptName, size: size) != nil else {
            return .system(size: size, weight: fallbackWeight)
        }
        return .custom(postScriptName, fixedSize: size)
    }
}

enum EmperorClassicButtonKind {
    case primary
    case secondary
    case danger
}

struct EmperorClassicButtonStyle: ButtonStyle {
    let kind: EmperorClassicButtonKind
    @Environment(\.isEnabled) private var isEnabled

    init(_ kind: EmperorClassicButtonKind = .secondary) {
        self.kind = kind
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(EmperorTheme.labelMedium)
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 28)
            .background(background(configuration: configuration))
            .overlay(Rectangle().strokeBorder(borderColor, lineWidth: 1))
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.48)
    }

    private var foreground: Color {
        switch kind {
        case .primary:
            EmperorTheme.onPrimary
        case .secondary, .danger:
            EmperorTheme.onSurface
        }
    }

    private func background(configuration: Configuration) -> Color {
        let base: Color
        switch kind {
        case .primary:
            base = EmperorTheme.primary
        case .secondary, .danger:
            base = EmperorTheme.surfaceControl
        }
        return configuration.isPressed ? base.opacity(0.78) : base
    }

    private var borderColor: Color {
        switch kind {
        case .danger:
            EmperorTheme.error
        case .primary, .secondary:
            EmperorTheme.border
        }
    }
}

struct EmperorNativeCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                EmperorTheme.surface.opacity(0.94),
                in: RoundedRectangle(cornerRadius: EmperorTheme.nativeCardRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: EmperorTheme.nativeCardRadius)
                    .strokeBorder(EmperorTheme.border, lineWidth: 1)
            )
    }
}

extension View {
    func emperorNativeCard() -> some View {
        modifier(EmperorNativeCardModifier())
    }
}
