import SwiftUI

struct CourtAnnotationView: View {
    let court: Court
    let isDiscovered: Bool
    let hasCoach: Bool
    let onTap: () -> Void

    init(court: Court, isDiscovered: Bool, hasCoach: Bool = false, onTap: @escaping () -> Void) {
        self.court = court
        self.isDiscovered = isDiscovered
        self.hasCoach = hasCoach
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .fill(isDiscovered ? difficultyColor.opacity(0.9) : Color.gray.opacity(0.7))
                            .frame(width: 36, height: 36)
                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)

                        if isDiscovered {
                            Image(systemName: "sportscourt.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                        } else {
                            Text("?")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }

                    // Coach badge
                    if isDiscovered && hasCoach {
                        AnimatedSpriteView(
                            appearance: Coach.coachAppearance,
                            size: 28,
                            animationState: .idleFront
                        )
                        .offset(x: 14, y: 8)
                    }
                }

                if isDiscovered {
                    Text(court.name)
                        .font(.caption2.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .fixedSize()
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
