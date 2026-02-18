import SwiftUI

enum AppTheme {
    static let cardRadius: CGFloat = 12
    static let sheetRadius: CGFloat = 16
    static let cardMaterial: Material = .regularMaterial
    static let overlayMaterial: Material = .ultraThinMaterial

    static func difficultyColor(_ difficulty: NPCDifficulty) -> Color {
        switch difficulty {
        case .beginner: return .green
        case .intermediate: return .blue
        case .advanced: return .purple
        case .expert: return .orange
        case .master: return .red
        }
    }
}
