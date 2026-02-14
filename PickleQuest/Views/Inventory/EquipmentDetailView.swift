import SwiftUI

struct EquipmentDetailView: View {
    let equipment: Equipment
    let isEquipped: Bool
    let currentStats: PlayerStats
    let previewStats: PlayerStats?
    let onEquip: () -> Void
    let onUnequip: () -> Void
    let onSell: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text(equipment.slot.icon)
                            .font(.system(size: 50))

                        Text(equipment.name)
                            .font(.title2.bold())
                            .foregroundStyle(equipment.rarity.color)

                        RarityBadge(rarity: equipment.rarity)
                    }
                    .padding(.top)

                    // Stat Bonuses
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Stat Bonuses")
                            .font(.headline)

                        ForEach(equipment.statBonuses, id: \.stat) { bonus in
                            HStack {
                                Text(bonus.stat.displayName)
                                    .font(.subheadline)
                                Spacer()
                                Text("+\(bonus.value)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Ability (if any)
                    if let ability = equipment.ability {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ability")
                                .font(.headline)

                            Text(ability.name)
                                .font(.subheadline.bold())
                                .foregroundStyle(.orange)

                            Text(ability.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Stat Comparison Preview
                    if let preview = previewStats, !isEquipped {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("If Equipped")
                                .font(.headline)

                            ForEach(StatType.allCases, id: \.self) { stat in
                                let current = currentStats.stat(stat)
                                let after = preview.stat(stat)
                                if current != after {
                                    HStack {
                                        Text(stat.displayName)
                                            .font(.subheadline)
                                        Spacer()
                                        Text("\(current)")
                                            .font(.subheadline.monospacedDigit())
                                        Image(systemName: "arrow.right")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("\(after)")
                                            .font(.subheadline.monospacedDigit().bold())
                                            .foregroundStyle(after > current ? .green : .red)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Actions
                    VStack(spacing: 12) {
                        if isEquipped {
                            Button(action: onUnequip) {
                                Label("Unequip", systemImage: "minus.circle")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(.orange)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        } else {
                            Button(action: onEquip) {
                                Label("Equip", systemImage: "checkmark.circle")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(.green)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        Button(action: onSell) {
                            Label("Sell for \(equipment.sellPrice) coins", systemImage: "dollarsign.circle")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.red.opacity(0.15))
                                .foregroundStyle(.red)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Equipment Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
