import SwiftUI

struct CourtAnnotationView: View {
    let court: Court
    let isDiscovered: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                if isDiscovered {
                    ZStack {
                        Circle()
                            .fill(difficultyColor.opacity(0.9))
                            .frame(width: 36, height: 36)
                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)

                        Image(systemName: "sportscourt.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                    }

                    Text(court.name)
                        .font(.caption2.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .fixedSize()
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(Color.orange, lineWidth: 2.5)
                            )
                            .shadow(color: .yellow.opacity(0.6), radius: 6)

                        Text("?")
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(.black)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var difficultyColor: Color {
        switch court.primaryDifficulty {
        case .beginner: return .green
        case .intermediate: return .blue
        case .advanced: return .purple
        case .expert: return .orange
        case .master: return .red
        }
    }
}
