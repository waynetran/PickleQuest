import SwiftUI

struct EquipmentDetailView: View {
    let equipment: Equipment
    let isEquipped: Bool
    let currentStats: PlayerStats
    let previewStats: PlayerStats?
    let playerCoins: Int
    let playerLevel: Int
    let onEquip: () -> Void
    let onUnequip: () -> Void
    let onSell: () -> Void
    let onRepair: (() -> Void)?
    let onUpgrade: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

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

                        HStack(spacing: 8) {
                            RarityBadge(rarity: equipment.rarity)
                            levelBadge
                        }

                        if let brandName = equipment.brandName {
                            Text(brandName)
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }

                        if !equipment.flavorText.isEmpty {
                            Text(equipment.flavorText)
                                .font(.subheadline.italic())
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.top)

                    // Level gate warning
                    if equipment.level > playerLevel {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.red)
                            Text("Requires Player Level \(equipment.level)")
                                .font(.subheadline.bold())
                                .foregroundStyle(.red)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Base Stat (from model)
                    if let baseStat = equipment.baseStat {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Base Stat")
                                    .font(.headline)
                                Spacer()
                                if equipment.level > 1 {
                                    Text("+\(Int((equipment.levelMultiplier - 1.0) * 100))% from level")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }

                            HStack {
                                Text(baseStat.stat.displayName)
                                    .font(.subheadline)
                                Spacer()
                                let scaledValue = Int((Double(baseStat.value) * equipment.levelMultiplier).rounded(.down))
                                if equipment.level > 1 {
                                    Text("\(baseStat.value)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Image(systemName: "arrow.right")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Text("+\(scaledValue)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.cyan)
                            }
                        }
                        .padding()
                        .background(.cyan.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Bonus Stats (from rarity)
                    if !equipment.statBonuses.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Bonus Stats")
                                .font(.headline)

                            ForEach(equipment.statBonuses, id: \.stat) { bonus in
                                HStack {
                                    Text(bonus.stat.displayName)
                                        .font(.subheadline)
                                    Spacer()
                                    let scaledValue = Int((Double(bonus.value) * equipment.levelMultiplier).rounded(.down))
                                    if equipment.level > 1 {
                                        Text("\(bonus.value)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Image(systemName: "arrow.right")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("+\(scaledValue)")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

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

                    // Set Bonuses
                    if let setID = equipment.setID, let equipSet = EquipmentSet.set(for: setID) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Set: \(equipSet.name)")
                                    .font(.headline)
                                    .foregroundStyle(.purple)
                                Spacer()
                                if let setName = equipment.setName {
                                    Text(setName)
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(.purple.opacity(0.2))
                                        .foregroundStyle(.purple)
                                        .clipShape(Capsule())
                                }
                            }

                            Text(equipSet.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(equipSet.bonusTiers, id: \.piecesRequired) { tier in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(tier.piecesRequired)pc — \(tier.label)")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary.opacity(0.8))
                                    ForEach(tier.bonuses, id: \.stat) { bonus in
                                        Text("+\(bonus.value) \(bonus.stat.displayName)")
                                            .font(.caption)
                                            .foregroundStyle(.green.opacity(0.8))
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(.purple.opacity(0.05))
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

                    // Upgrade section
                    if !equipment.isMaxLevel, let onUpgrade {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Upgrade to Lv. \(equipment.level + 1)")
                                    .font(.subheadline.bold())
                                Spacer()
                                Text("+\(Int(GameConstants.EquipmentLevel.statPercentPerLevel * 100))% stats")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }

                            Button {
                                onUpgrade()
                            } label: {
                                Label("\(equipment.upgradeCost) coins", systemImage: "arrow.up.circle.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(playerCoins >= equipment.upgradeCost ? .blue : .gray)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(playerCoins < equipment.upgradeCost)
                        }
                        .padding()
                        .background(.blue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Repair (for broken equipment)
                    if equipment.isBroken, let onRepair {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "wrench.and.screwdriver.fill")
                                    .foregroundStyle(.red)
                                Text("This equipment is broken!")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.red)
                            }

                            Button {
                                onRepair()
                            } label: {
                                Label("Repair for \(equipment.repairCost) coins", systemImage: "wrench.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(playerCoins >= equipment.repairCost ? .blue : .gray)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(playerCoins < equipment.repairCost)
                        }
                        .padding()
                        .background(.red.opacity(0.08))
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
                            Label("Sell for \(equipment.effectiveSellPrice) coins", systemImage: "dollarsign.circle")
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var levelBadge: some View {
        Text("Lv. \(equipment.level) / \(equipment.maxLevel)")
            .font(.caption2.bold().monospacedDigit())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.blue.opacity(0.15))
            .foregroundStyle(.blue)
            .clipShape(Capsule())
    }
}
