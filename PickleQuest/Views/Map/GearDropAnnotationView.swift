import SwiftUI

struct GearDropAnnotationView: View {
    let drop: GearDrop
    let isInRange: Bool
    let onTap: () -> Void

    @State private var isPulsing = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Rarity glow ring
                Circle()
                    .fill(drop.rarity.color.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .scaleEffect(isPulsing && isInRange ? 1.3 : 1.0)
                    .opacity(isPulsing && isInRange ? 0.5 : 0.8)

                // Background circle
                Circle()
                    .fill(.white)
                    .frame(width: 36, height: 36)
                    .shadow(color: drop.rarity.color.opacity(0.6), radius: 4)

                // Icon
                iconView
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(iconColor)

                // Trail order badge
                if let order = drop.trailOrder, drop.type == .trail {
                    Text("\(order + 1)")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(drop.rarity.color)
                        .clipShape(Circle())
                        .offset(x: 14, y: -14)
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            if isInRange {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
        .onChange(of: isInRange) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            } else {
                withAnimation { isPulsing = false }
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        switch drop.type {
        case .courtCache where !drop.isUnlocked:
            Image(systemName: "lock.fill")
        case .contested:
            Image(systemName: "flame.fill")
        case .fogStash:
            Image(systemName: "bag.fill")
        default:
            Image(systemName: "bag.fill")
        }
    }

    private var iconColor: Color {
        switch drop.type {
        case .courtCache where !drop.isUnlocked:
            return .gray
        case .contested:
            return .orange
        default:
            return drop.rarity.color
        }
    }
}
