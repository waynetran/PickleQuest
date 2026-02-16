import SwiftUI

struct GearDropAnnotationView: View {
    let drop: GearDrop
    let isInRange: Bool
    let onTap: () -> Void

    @State private var isPulsing = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Pulsating glow — always visible, intensifies when in range
                Circle()
                    .fill(glowColor.opacity(isPulsing ? 0.6 : 0.2))
                    .frame(width: isPulsing ? 52 : 36, height: isPulsing ? 52 : 36)
                    .blur(radius: isPulsing ? 12 : 6)

                iconView

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
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }

    private var glowColor: Color {
        switch drop.type {
        case .courtCache where !drop.isUnlocked: return .gray
        case .contested: return .orange
        default: return drop.rarity.color
        }
    }

    @ViewBuilder
    private var iconView: some View {
        switch drop.type {
        case .courtCache where !drop.isUnlocked:
            Image(systemName: "lock.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.gray)
        case .contested:
            Image(systemName: "flame.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.orange)
        default:
            Image("GearDropBackpack")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                .colorMultiply(drop.rarity.color)
        }
    }
}
