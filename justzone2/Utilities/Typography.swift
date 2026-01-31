import SwiftUI

// MARK: - App Typography
// Central font configuration - change the font family here to update everywhere

enum AppFont {
    // Change this to update the font throughout the app
    static let family = "ArialRoundedMTBold"

    // Fallback to system rounded if custom font not available
    static func custom(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // Arial Rounded MT Bold only comes in one weight, so we use it directly
        return .custom(family, size: size)
    }
}

// MARK: - Semantic Font Styles

extension Font {
    // MARK: - Display (large numbers, hero text)
    static var displayLarge: Font { AppFont.custom(size: 72) }
    static var displayMedium: Font { AppFont.custom(size: 56) }
    static var displaySmall: Font { AppFont.custom(size: 44) }

    // MARK: - Headlines
    static var headlineLarge: Font { AppFont.custom(size: 24) }
    static var headlineMedium: Font { AppFont.custom(size: 20) }
    static var headlineSmall: Font { AppFont.custom(size: 17) }

    // MARK: - Body
    static var bodyLarge: Font { AppFont.custom(size: 17) }
    static var bodyMedium: Font { AppFont.custom(size: 15) }
    static var bodySmall: Font { AppFont.custom(size: 13) }

    // MARK: - Labels
    static var labelLarge: Font { AppFont.custom(size: 14) }
    static var labelMedium: Font { AppFont.custom(size: 12) }
    static var labelSmall: Font { AppFont.custom(size: 11) }

    // MARK: - Tiny (chart labels, timestamps)
    static var tiny: Font { AppFont.custom(size: 10) }

    // MARK: - Monospaced (for timers - keeps numbers aligned)
    static var timerLarge: Font { AppFont.custom(size: 56) }
    static var timerMedium: Font { AppFont.custom(size: 32) }
    static var timerSmall: Font { AppFont.custom(size: 17) }
}
