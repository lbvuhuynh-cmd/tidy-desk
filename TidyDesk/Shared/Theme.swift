import SwiftUI
import UIKit

/// "Cozy modern tech setup": warm oak desk on soft greige by day, walnut + slate at night,
/// muted category colours, and a soft LED-strip glow when the setup is complete.
enum Theme {
    static let background = dynamic(light: 0xF2F0EB, dark: 0x15171A)
    static let desk = dynamic(light: 0xE3D4BF, dark: 0x2A2521)          // oak / walnut
    static let deskEdge = dynamic(light: 0xC9B394, dark: 0x40372F)
    static let slot = dynamic(light: 0xD8C7AF, dark: 0x332D28)
    static let drawer = dynamic(light: 0xE8E5DF, dark: 0x1E2125)
    static let drawerInset = dynamic(light: 0xDDD9D1, dark: 0x16181B)
    static let card = dynamic(light: 0xFBFAF8, dark: 0x25282D)
    static let accent = dynamic(light: 0x4F8A7B, dark: 0x7CC1AE)          // muted sage
    static let valid = dynamic(light: 0x4E9C7C, dark: 0x6FD3A8)
    static let invalid = dynamic(light: 0xC8605A, dark: 0xF07B74)
    static let star = Color(red: 0.96, green: 0.76, blue: 0.36)

    /// Soft RGB-setup glow used for the "Setup Complete" moment.
    static let led: [Color] = [
        Color(red: 0.49, green: 0.80, blue: 0.78),
        Color(red: 0.55, green: 0.64, blue: 0.93),
        Color(red: 0.74, green: 0.60, blue: 0.90),
        Color(red: 0.95, green: 0.66, blue: 0.75),
        Color(red: 0.49, green: 0.80, blue: 0.78),
    ]

    static func color(for category: ItemCategory) -> Color {
        switch category {
        case .peripheral: Color(red: 0.42, green: 0.52, blue: 0.66)  // slate blue
        case .display: Color(red: 0.34, green: 0.37, blue: 0.42)     // graphite
        case .audio: Color(red: 0.58, green: 0.51, blue: 0.71)       // dusty lavender
        case .mobile: Color(red: 0.45, green: 0.62, blue: 0.54)      // sage
        case .power: Color(red: 0.77, green: 0.53, blue: 0.42)       // clay
        case .cozy: Color(red: 0.80, green: 0.65, blue: 0.43)        // honey
        case .garden: Color(red: 0.48, green: 0.64, blue: 0.40)      // leaf green
        }
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}
