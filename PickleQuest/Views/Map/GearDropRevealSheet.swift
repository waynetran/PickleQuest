import SwiftUI

struct GearDropRevealSheet: View {
    let drop: GearDrop
    let equipment: [Equipment]
    let coins: Int
    @Binding var lootDecisions: [UUID: LootDecision]
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        // Header
                        headerView

                        // Coin reward
                        if coins > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "dollarsign.circle.fill")
                                    .foregroundStyle(.yellow)
                                Text("+\(coins) coins")
                                    .font(.subheadline.bold())
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(.yellow.opacity(0.1))
                            .clipShape(Capsule())
                        }

                        // Equipment list
                        ForEach(equipment) { item in
                            LootDropRow(
                                equipment: item,
                                decision: Binding(
                                    get: { lootDecisions[item.id] },
                                    set: { lootDecisions[item.id] = $0 }
                                )
                            )
                        }
                    }
                    .padding()
                }

                // Sticky dismiss button
                Button(action: onDismiss) {
                    Text("Dismiss")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Gear Drop")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(drop.rarity.color.opacity(0.2))
                    .frame(width: 72, height: 72)
                Image(systemName: "bag.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(drop.rarity.color)
            }

            Text("You found a \(drop.rarity.displayName) \(drop.type.displayName)!")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
        }
    }
}
