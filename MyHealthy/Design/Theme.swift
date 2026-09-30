import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    /// A color that switches between a light-mode and a dark-mode hex value.
    static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

/// The app's colors. Blue always means systolic (top number) and orange always
/// means diastolic (bottom number), on every screen and chart.
enum Palette {
    static let systolic = Color.adaptive(0x1E5BD6, 0x4C8DFF)
    static let diastolic = Color.adaptive(0xE07A1F, 0xF29A4A)
    /// Darker orange that meets text contrast on white.
    static let diastolicText = Color.adaptive(0xA8520C, 0xF5A25A)

    static let tint = systolic
    /// Fill behind white text (darker than `tint` in dark mode for contrast).
    static let fill = Color.adaptive(0x1E5BD6, 0x2D6BDF)
    static let tintSoft = Color.adaptive(0xE4ECFB, 0x1B2B4A)
    static let tintSoftText = Color.adaptive(0x1747A8, 0x8AB6FF)

    static let good = Color.adaptive(0x0B6B53, 0x5FD3AE)
    static let goodSoft = Color.adaptive(0xE3F1EC, 0x12352B)
    static let warn = Color.adaptive(0x9A4A07, 0xF5A25A)
    static let warnSoft = Color.adaptive(0xFCEBD9, 0x3A2410)
    static let warnFill = Color.adaptive(0xF6C8A0, 0x5A3414)

    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let fieldBackground = Color(uiColor: .tertiarySystemFill)
    static let chipBackground = Color(uiColor: .secondarySystemFill)
    static let separator = Color(uiColor: .separator)
    static let slash = Color(uiColor: .tertiaryLabel)
    static let chevron = Color(uiColor: .tertiaryLabel)

    struct AvatarColors {
        let background: Color
        let foreground: Color
    }

    static let avatars: [AvatarColors] = [
        AvatarColors(background: .adaptive(0xDCE7FB, 0x1E3358), foreground: .adaptive(0x1E5BD6, 0x8AB6FF)),
        AvatarColors(background: .adaptive(0xFBE6D3, 0x3D2715), foreground: .adaptive(0xA8520C, 0xF5A25A)),
        AvatarColors(background: .adaptive(0xD6EFE8, 0x143A30), foreground: .adaptive(0x0B6B53, 0x5FD3AE)),
        AvatarColors(background: .adaptive(0xEDE7F8, 0x2A2242), foreground: .adaptive(0x5B3FA8, 0xB7A3F0)),
        AvatarColors(background: .adaptive(0xF8E1E7, 0x3F1E28), foreground: .adaptive(0xA3284D, 0xF29BB5))
    ]

    static func avatar(_ index: Int) -> AvatarColors {
        avatars[((index % avatars.count) + avatars.count) % avatars.count]
    }

    /// Icon tile colors for a medication, by purpose.
    static func medicationTile(purpose: String) -> AvatarColors {
        purpose.lowercased().contains("cholesterol") ? avatar(3) : avatar(0)
    }
}

extension Font {
    /// Rounded, tabular numerals for blood pressure values.
    static func bpNumber(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}

enum Metrics {
    static let cardRadius: CGFloat = 16
    static let screenPadding: CGFloat = 16
}
