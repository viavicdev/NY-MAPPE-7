import SwiftUI
import AppKit

// Helper to create colors that adapt to light/dark mode automatically
private func adaptive(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
    Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let c = isDark ? dark : light
        return NSColor(red: c.0, green: c.1, blue: c.2, alpha: 1.0)
    }))
}

private func adaptiveOpacity(light: (CGFloat, CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat, CGFloat)) -> Color {
    Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let c = isDark ? dark : light
        return NSColor(red: c.0, green: c.1, blue: c.2, alpha: c.3)
    }))
}

enum Design {
    // MARK: - Adaptive Colors

    // Deep dark background - deeper black with blue undertone
    static let panelBackground = adaptive(
        light: (0.97, 0.97, 0.96),
        dark: (0.04, 0.04, 0.06)
    )
    static let paperBackground = panelBackground

    // Card surface: darker cards for more contrast with color washes
    static let cardBackground = adaptive(
        light: (1.0, 1.0, 1.0),
        dark: (0.09, 0.09, 0.12)
    )
    static let cardHoverBackground = adaptive(
        light: (0.96, 0.96, 0.98),
        dark: (0.12, 0.12, 0.16)
    )

    // Subtler frosted border
    static let borderColor = adaptiveOpacity(
        light: (0.0, 0.0, 0.0, 0.06),
        dark: (1.0, 1.0, 1.0, 0.08)
    )

    // Text - brighter white in dark mode for high contrast
    static let subtleText = adaptive(
        light: (0.50, 0.48, 0.52),
        dark: (0.48, 0.48, 0.55)
    )
    static let primaryText = adaptive(
        light: (0.06, 0.04, 0.10),
        dark: (0.96, 0.96, 0.98)
    )

    // Accent: red
    static let accent = adaptive(
        light: (0.85, 0.18, 0.22),
        dark: (0.95, 0.30, 0.32)
    )

    static let accentLight = adaptive(
        light: (0.85, 0.18, 0.22),
        dark: (0.95, 0.30, 0.32)
    ).opacity(0.12)

    // Status
    static let dangerColor = adaptive(
        light: (0.80, 0.25, 0.30),
        dark: (0.90, 0.35, 0.40)
    )
    static let successColor = adaptive(
        light: (0.18, 0.60, 0.40),
        dark: (0.25, 0.78, 0.52)
    )
    static let errorBannerBg = adaptive(
        light: (0.95, 0.90, 0.88),
        dark: (0.20, 0.10, 0.10)
    )

    // MARK: - Color Wash (gradient backgrounds per type, inspired by status cards)
    static let blueWash = adaptiveOpacity(
        light: (0.30, 0.50, 0.90, 0.10),
        dark: (0.30, 0.50, 0.90, 0.16)
    )
    static let tealWash = adaptiveOpacity(
        light: (0.15, 0.75, 0.55, 0.10),
        dark: (0.15, 0.75, 0.55, 0.16)
    )
    static let pinkWash = adaptiveOpacity(
        light: (0.85, 0.30, 0.45, 0.10),
        dark: (0.85, 0.30, 0.45, 0.16)
    )
    static let amberWash = adaptiveOpacity(
        light: (0.85, 0.65, 0.20, 0.10),
        dark: (0.85, 0.65, 0.20, 0.16)
    )
    static let purpleWash = adaptiveOpacity(
        light: (0.55, 0.35, 0.85, 0.10),
        dark: (0.55, 0.35, 0.85, 0.16)
    )

    // Notification badge red (like inspo 3)
    static let badgeRed = adaptive(
        light: (0.90, 0.20, 0.20),
        dark: (0.95, 0.30, 0.30)
    )

    // Progress bar color
    static let progressBlue = adaptive(
        light: (0.30, 0.45, 0.90),
        dark: (0.40, 0.55, 1.0)
    )

    static func cardWashColor(for category: TypeCategory) -> Color {
        switch category {
        case .image: return blueWash
        case .video: return pinkWash
        case .audio: return purpleWash
        case .document: return tealWash
        case .archive: return amberWash
        case .other: return adaptiveOpacity(light: (0.5, 0.5, 0.5, 0.04), dark: (0.5, 0.5, 0.5, 0.06))
        }
    }

    static func cardWashGradient(for category: TypeCategory) -> LinearGradient {
        let washColor = cardWashColor(for: category)
        return LinearGradient(
            colors: [washColor, Color.clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Glass
    static let glassBackground = adaptiveOpacity(
        light: (0.0, 0.0, 0.0, 0.02),
        dark: (1.0, 1.0, 1.0, 0.04)
    )
    static let glassBorder = adaptiveOpacity(
        light: (0.0, 0.0, 0.0, 0.06),
        dark: (1.0, 1.0, 1.0, 0.12)
    )

    // Buttons
    static let buttonTint = adaptiveOpacity(
        light: (0.0, 0.0, 0.0, 0.05),
        dark: (1.0, 1.0, 1.0, 0.07)
    )
    static let buttonTintPressed = adaptiveOpacity(
        light: (0.0, 0.0, 0.0, 0.10),
        dark: (1.0, 1.0, 1.0, 0.14)
    )
    static let buttonBorder = adaptiveOpacity(
        light: (0.0, 0.0, 0.0, 0.08),
        dark: (1.0, 1.0, 1.0, 0.10)
    )

    // Header/tab surface
    static let headerSurface = adaptiveOpacity(
        light: (1.0, 1.0, 1.0, 0.6),
        dark: (1.0, 1.0, 1.0, 0.03)
    )
    static let dividerColor = adaptiveOpacity(
        light: (0.0, 0.0, 0.0, 0.08),
        dark: (1.0, 1.0, 1.0, 0.08)
    )

    // MARK: - Typography (bigger, bolder)
    static let headingFont = Font.system(size: 18, weight: .bold, design: .rounded)
    static let titleFont = Font.system(size: 16, weight: .bold, design: .rounded)
    static let cardTitleFont = Font.system(size: 13, weight: .bold, design: .rounded)
    static let bodyFont = Font.system(size: 13, weight: .regular, design: .rounded)
    static let captionFont = Font.system(size: 11, weight: .regular, design: .rounded)
    static let badgeFont = Font.system(size: 10, weight: .semibold, design: .rounded)
    static let tabFont = Font.system(size: 12, weight: .medium, design: .rounded)
    static let tabActiveFont = Font.system(size: 12, weight: .bold, design: .rounded)

    // MARK: - Layout (bigger radii, more breathing room)
    static let cornerRadius: CGFloat = 20
    static let cardCornerRadius: CGFloat = 18
    static let cardPadding: CGFloat = 16
    static let gridSpacing: CGFloat = 12
    static let sectionSpacing: CGFloat = 14
    static let tabUnderlineHeight: CGFloat = 3
    static let badgeSize: CGFloat = 18

    // MARK: - Shadows
    static let cardShadow = ShadowStyle.drop(color: .black.opacity(0.35), radius: 10, x: 0, y: 4)

    // MARK: - Pill Button Style (bigger, more substantial, with solid variant)
    struct PillButtonStyle: ButtonStyle {
        var isAccent: Bool = false
        var isDanger: Bool = false
        var isSolid: Bool = false

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(
                    Group {
                        if isSolid {
                            isDanger ? Design.dangerColor :
                            isAccent ? Design.accent :
                            Design.buttonTint
                        } else if isDanger {
                            Design.dangerColor.opacity(configuration.isPressed ? 0.25 : 0.12)
                        } else if isAccent {
                            Design.accent.opacity(configuration.isPressed ? 0.25 : 0.12)
                        } else {
                            configuration.isPressed ? Design.buttonTintPressed : Design.buttonTint
                        }
                    }
                )
                .foregroundColor(
                    isSolid ? .white :
                    isDanger ? Design.dangerColor :
                    isAccent ? Design.accent :
                    Design.primaryText
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isSolid ? Color.clear :
                            isDanger ? Design.dangerColor.opacity(0.25) :
                            isAccent ? Design.accent.opacity(0.25) :
                            Design.buttonBorder,
                            lineWidth: 1
                        )
                )
                .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        }
    }

    // MARK: - Icon Button Style (slightly larger, rounder)
    struct IconButtonStyle: ButtonStyle {
        var isAccent: Bool = false

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 14))
                .frame(width: 36, height: 32)
                .background(
                    isAccent ?
                        Design.accent.opacity(configuration.isPressed ? 0.25 : 0.12) :
                        (configuration.isPressed ? Design.buttonTintPressed : Design.buttonTint)
                )
                .foregroundColor(
                    isAccent ? Design.accent : Design.primaryText
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isAccent ? Design.accent.opacity(0.25) : Design.buttonBorder,
                            lineWidth: 1
                        )
                )
                .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        }
    }

    // MARK: - Close Button Style (circular, like inspo X buttons)
    struct CloseButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Design.subtleText.opacity(configuration.isPressed ? 1.0 : 0.7))
                .frame(width: 28, height: 28)
                .background(Design.buttonTint.opacity(configuration.isPressed ? 1.5 : 1.0))
                .clipShape(Circle())
                .overlay(Circle().stroke(Design.buttonBorder, lineWidth: 0.5))
                .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
                .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
        }
    }

    // MARK: - Inline Action Style (for hover action buttons on cards)
    struct InlineActionStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 11))
                .foregroundColor(Design.subtleText)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(configuration.isPressed ? Design.buttonTintPressed : Design.buttonTint)
                )
                .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
                .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
        }
    }

    // MARK: - Type Badge Colors (more vibrant)
    static func badgeColor(for category: TypeCategory) -> Color {
        switch category {
        case .image: return adaptive(light: (0.25, 0.55, 0.85), dark: (0.45, 0.75, 1.0))
        case .video: return adaptive(light: (0.80, 0.30, 0.50), dark: (0.95, 0.50, 0.70))
        case .audio: return adaptive(light: (0.55, 0.40, 0.80), dark: (0.75, 0.60, 1.0))
        case .document: return adaptive(light: (0.20, 0.65, 0.40), dark: (0.35, 0.85, 0.55))
        case .archive: return adaptive(light: (0.70, 0.55, 0.25), dark: (0.90, 0.75, 0.40))
        case .other: return adaptive(light: (0.45, 0.45, 0.50), dark: (0.60, 0.60, 0.65))
        }
    }

    static func stripeColor(for category: TypeCategory) -> Color {
        badgeColor(for: category)
    }
}
