import SwiftUI

struct ItemDetailView: View {
    let equipment: Equipment
    let isEquipped: Bool
    let currentStats: PlayerStats
    let previewStats: PlayerStats?
    let playerCoins: Int
    let playerLevel: Int
    let onEquip: () -> Void
    let onUnequip: () -> Void
    let onSell: (() -> Void)?
    let onRepair: (() -> Void)?
    let onUpgrade: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    VStack(spacing: 8) {
                        Text(equipment.slot.icon)
                            .font(.system(size: 64))

                        Text(equipment.name)
                            .font(.system(size: 18, design: .monospaced).bold())
                            .foregroundStyle(equipment.rarity.color)

                        HStack(spacing: 8) {
                            Text(equipment.rarity.displayName.uppercased())
                                .font(.system(size: 10, design: .monospaced).bold())
                                .foregroundStyle(equipment.rarity.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(equipment.rarity.color.opacity(0.15))
                                .overlay(
                                    Rectangle()
                                        .strokeBorder(equipment.rarity.color.opacity(0.3), lineWidth: 1)
                                )

                            Text("LV.\(equipment.level)/\(equipment.maxLevel)")
                                .font(.system(size: 10, design: .monospaced).bold())
                                .foregroundStyle(.cyan)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.cyan.opacity(0.1))
                                .overlay(
                                    Rectangle()
                                        .strokeBorder(.cyan.opacity(0.3), lineWidth: 1)
                                )
                        }

                        if let brandName = equipment.brandName {
                            Text(brandName)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color(white: 0.5))
                        }

                        if !equipment.flavorText.isEmpty {
                            Text(equipment.flavorText)
                                .font(.system(size: 11, design: .monospaced).italic())
                                .foregroundStyle(Color(white: 0.4))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.top, 16)

                    pixelDivider

                    // Base Stat
                    if let baseStat = equipment.baseStat {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader("BASE STAT")

                            HStack {
                                Text(baseStat.stat.displayName)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(Color(white: 0.7))
                                Spacer()
                                let scaled = Int((Double(baseStat.value) * equipment.levelMultiplier).rounded(.down))
                                Text("+\(scaled)")
                                    .font(.system(size: 14, design: .monospaced).bold())
                                    .foregroundStyle(.cyan)
                            }
                        }
                        .padding(12)
                        .background(Color(white: 0.1))
                        .overlay(
                            Rectangle().strokeBorder(Color(white: 0.2), lineWidth: 1)
                        )
                        .padding(.horizontal, 12)
                    }

                    // Bonus Stats
                    if !equipment.statBonuses.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader("BONUS STATS")

                            ForEach(equipment.statBonuses, id: \.stat) { bonus in
                                HStack {
                                    Text(bonus.stat.displayName)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(Color(white: 0.7))
                                    Spacer()
                                    let scaled = Int((Double(bonus.value) * equipment.levelMultiplier).rounded(.down))
                                    Text("+\(scaled)")
                                        .font(.system(size: 14, design: .monospaced).bold())
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(white: 0.1))
                        .overlay(
                            Rectangle().strokeBorder(Color(white: 0.2), lineWidth: 1)
                        )
                        .padding(.horizontal, 12)
                    }

                    // Traits
                    if !equipment.traits.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader("TRAITS")

                            ForEach(equipment.traits, id: \.type) { trait in
                                HStack(spacing: 8) {
                                    Text(trait.tier.displayName.uppercased())
                                        .font(.system(size: 8, design: .monospaced).bold())
                                        .foregroundStyle(traitColor(trait.tier))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(traitColor(trait.tier).opacity(0.15))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(trait.type.displayName)
                                            .font(.system(size: 11, design: .monospaced).bold())
                                            .foregroundStyle(traitColor(trait.tier))
                                        Text(trait.type.description)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(Color(white: 0.5))
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(white: 0.1))
                        .overlay(
                            Rectangle().strokeBorder(Color(white: 0.2), lineWidth: 1)
                        )
                        .padding(.horizontal, 12)
                    }

                    // Ability
                    if let ability = equipment.ability {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader("ABILITY")

                            Text(ability.name)
                                .font(.system(size: 12, design: .monospaced).bold())
                                .foregroundStyle(.orange)

                            Text(ability.description)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color(white: 0.5))
                        }
                        .padding(12)
                        .background(Color(white: 0.1))
                        .overlay(
                            Rectangle().strokeBorder(Color(white: 0.2), lineWidth: 1)
                        )
                        .padding(.horizontal, 12)
                    }

                    // Set Bonuses
                    if let setID = equipment.setID, let equipSet = EquipmentSet.set(for: setID) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                sectionHeader("SET: \(equipSet.name.uppercased())")
                                Spacer()
                            }

                            Text(equipSet.description)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Color(white: 0.5))

                            ForEach(equipSet.bonusTiers, id: \.piecesRequired) { tier in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(tier.piecesRequired)pc — \(tier.label)")
                                        .font(.system(size: 10, design: .monospaced).bold())
                                        .foregroundStyle(.purple)
                                    ForEach(tier.bonuses, id: \.stat) { bonus in
                                        Text("+\(bonus.value) \(bonus.stat.displayName)")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(.green.opacity(0.8))
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(white: 0.1))
                        .overlay(
                            Rectangle().strokeBorder(.purple.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal, 12)
                    }

                    // Stat Comparison
                    if let preview = previewStats, !isEquipped {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader("IF EQUIPPED")

                            ForEach(StatType.allCases, id: \.self) { stat in
                                let current = currentStats.stat(stat)
                                let after = preview.stat(stat)
                                if current != after {
                                    HStack {
                                        Text(stat.displayName)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(Color(white: 0.6))
                                        Spacer()
                                        Text("\(current)")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(Color(white: 0.4))
                                        Text(">")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(Color(white: 0.3))
                                        Text("\(after)")
                                            .font(.system(size: 12, design: .monospaced).bold())
                                            .foregroundStyle(after > current ? .green : .red)
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(white: 0.1))
                        .overlay(
                            Rectangle().strokeBorder(Color(white: 0.2), lineWidth: 1)
                        )
                        .padding(.horizontal, 12)
                    }

                    // Upgrade section
                    if !equipment.isMaxLevel, let onUpgrade {
                        VStack(spacing: 8) {
                            HStack {
                                Text("UPGRADE TO LV.\(equipment.level + 1)")
                                    .font(.system(size: 10, design: .monospaced).bold())
                                    .foregroundStyle(.cyan)
                                Spacer()
                                Text("+\(Int(GameConstants.EquipmentLevel.statPercentPerLevel * 100))% stats")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.cyan.opacity(0.7))
                            }

                            Button(action: onUpgrade) {
                                Text("\(equipment.upgradeCost) COINS")
                                    .font(.system(size: 12, design: .monospaced).bold())
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(playerCoins >= equipment.upgradeCost ? Color.cyan.opacity(0.8) : Color(white: 0.2))
                                    .overlay(
                                        Rectangle().strokeBorder(
                                            playerCoins >= equipment.upgradeCost ? .cyan : Color(white: 0.3),
                                            lineWidth: 2
                                        )
                                    )
                            }
                            .disabled(playerCoins < equipment.upgradeCost)
                        }
                        .padding(12)
                        .background(Color(white: 0.1))
                        .overlay(
                            Rectangle().strokeBorder(.cyan.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal, 12)
                    }

                    // Repair
                    if equipment.isBroken, let onRepair {
                        VStack(spacing: 8) {
                            Text("BROKEN!")
                                .font(.system(size: 11, design: .monospaced).bold())
                                .foregroundStyle(.red)

                            Button(action: onRepair) {
                                Text("REPAIR \(equipment.repairCost) COINS")
                                    .font(.system(size: 12, design: .monospaced).bold())
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(playerCoins >= equipment.repairCost ? Color.red.opacity(0.6) : Color(white: 0.2))
                                    .overlay(
                                        Rectangle().strokeBorder(.red.opacity(0.5), lineWidth: 2)
                                    )
                            }
                            .disabled(playerCoins < equipment.repairCost)
                        }
                        .padding(12)
                        .background(.red.opacity(0.05))
                        .overlay(
                            Rectangle().strokeBorder(.red.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal, 12)
                    }

                    Spacer(minLength: 16)
                }
            }

            // Sticky bottom action buttons
            VStack(spacing: 8) {
                pixelDivider

                if isEquipped {
                    Button(action: onUnequip) {
                        Text("UNEQUIP")
                            .font(.system(size: 14, design: .monospaced).bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.orange.opacity(0.8))
                            .overlay(
                                Rectangle().strokeBorder(.orange, lineWidth: 2)
                            )
                    }
                } else {
                    Button(action: onEquip) {
                        Text("EQUIP")
                            .font(.system(size: 14, design: .monospaced).bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.green.opacity(0.8))
                            .overlay(
                                Rectangle().strokeBorder(.green, lineWidth: 2)
                            )
                    }
                }

                if let onSell {
                    Button(action: onSell) {
                        Text("SELL \(equipment.effectiveSellPrice) COINS")
                            .font(.system(size: 11, design: .monospaced).bold())
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(.red.opacity(0.1))
                            .overlay(
                                Rectangle().strokeBorder(.red.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(white: 0.06))
        }
        .background(Color(white: 0.08))
        .navigationTitle("ITEM")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close") { dismiss() }
                    .font(.system(size: 12, design: .monospaced))
            }
        }
        .toolbarBackground(Color(white: 0.08), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, design: .monospaced).bold())
            .foregroundStyle(Color(white: 0.5))
    }

    private var pixelDivider: some View {
        Rectangle()
            .fill(Color(white: 0.2))
            .frame(height: 2)
            .padding(.horizontal, 12)
    }

    private func traitColor(_ tier: TraitTier) -> Color {
        switch tier {
        case .minor: return .teal
        case .major: return .purple
        case .unique: return .orange
        }
    }
}
