import SwiftUI

extension Color {
    /// Accepts "#RRGGBB" or "RRGGBB". Falls back to grey on anything else.
    init(hex: String) {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else {
            self = .gray
            return
        }
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}

extension Occurrence {
    var color: Color {
        guard isScheduled else { return .gray }
        return Color(hex: colorHex)
    }
}

enum Palette {
    /// Offered when creating a new subject.
    static let choices: [String] = [
        "#0A84FF", "#30D158", "#FF375F", "#FF9F0A",
        "#BF5AF2", "#64D2FF", "#5E5CE6", "#FFD60A",
        "#FF6482", "#40C8E0", "#AC8E68", "#8E8E93",
    ]

    static func next(avoiding used: [String]) -> String {
        return choices.first { !used.contains($0) } ?? choices[0]
    }
}
