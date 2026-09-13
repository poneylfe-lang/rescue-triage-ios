import SwiftUI

/// Lifted from the concept site so the app and the website read as one product.
enum RescuePalette {
    static let orange = Color(hex: 0xE8562F)
    static let navy   = Color(hex: 0x171C3A)
    static let lime   = Color(hex: 0xD8FB45)
    static let cream  = Color(hex: 0xFAF3DF)
    static let paper  = Color(hex: 0xECE7DA)
    static let ink    = Color(hex: 0x17130E)
    static let amber  = Color(hex: 0xE0A32E)
    static let muted  = Color(hex: 0x5C5648)

    static func background(for outcome: Outcome) -> Color {
        switch outcome {
        case .accepted: lime
        case .heldForHuman: amber
        case .rejected: orange
        }
    }

    static func foreground(for outcome: Outcome) -> Color {
        switch outcome {
        case .accepted: ink
        case .heldForHuman, .rejected: .white
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
