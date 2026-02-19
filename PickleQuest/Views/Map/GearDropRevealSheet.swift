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
        .onAppear {
            SoundManager.shared.playUI(.lootReveal)
        }
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(drop.rarity.color.opacity(0.2))
                    .frame(width: 72, height: 72)
                Image("GearDropBackpack")
                    .resizable()
                    .frame(width: 40, height: 40)
            }

            Text("You found a \(drop.rarity.displayName) \(drop.type.displayName)!")
                .font(.title3.bold())
                .multilineTextAlignment(.center)

            Text(rarityQuip)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var rarityQuip: String {
        switch drop.rarity {
        case .common:
            return "Hey, even pros started with a wooden paddle."
        case .uncommon:
            return "Not bad — this gear's got some dink potential."
        case .rare:
            return "Ooh, that's got some serious kitchen energy!"
        case .epic:
            return "Your opponents won't know what hit 'em."
        case .legendary:
            return "The pickleball gods have blessed you today!"
        }
    }
}
