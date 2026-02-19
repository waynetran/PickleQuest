import SwiftUI

struct SkillTreeView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var container: DependencyContainer
    @State private var viewModel: SkillTreeViewModel?
    @State private var selectedSkill: SkillDefinition?

    var body: some View {
        ScrollView {
            if let vm = viewModel {
                VStack(spacing: 20) {
                    // Skill points header
                    if vm.availableSkillPoints > 0 {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.purple)
                            Text("\(vm.availableSkillPoints) skill point\(vm.availableSkillPoints == 1 ? "" : "s") available")
                                .font(.subheadline.bold())
                                .foregroundStyle(.purple)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.purple.opacity(0.1))
                        .clipShape(Capsule())
                    }

                    // Core Skills
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Core Skills")
                            .font(.title3.bold())
                            .padding(.horizontal)

                        ForEach(vm.sharedSkills, id: \.id) { def in
                            skillCard(def, vm: vm)
                        }
                    }

                    // Exclusive Skills
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(vm.playerType.displayName) Skills")
                            .font(.title3.bold())
                            .padding(.horizontal)

                        ForEach(vm.exclusiveSkills, id: \.id) { def in
                            skillCard(def, vm: vm)
                        }
                    }
                }
                .padding(.vertical)
            } else {
                ProgressView()
                    .padding(.top, 40)
            }
        }
        .navigationTitle("Skill Tree")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let vm = SkillTreeViewModel(skillService: container.skillService)
            vm.load(player: appState.player)
            viewModel = vm
        }
        .sheet(item: $selectedSkill) { def in
            skillDetailSheet(def)
        }
    }

    // MARK: - Skill Card

    @ViewBuilder
    private func skillCard(_ def: SkillDefinition, vm: SkillTreeViewModel) -> some View {
        let acquired = vm.isAcquired(def.id)
        let locked = vm.isLocked(def)
        let rank = vm.rank(for: def.id)
        let progress = vm.lessonProgress[def.id]

        Button {
            selectedSkill = def
        } label: {
            HStack(spacing: 12) {
                Image(systemName: def.icon)
                    .font(.title2)
                    .foregroundStyle(locked ? .secondary : (acquired ? Color.purple : Color.accentColor))
                    .frame(width: 44, height: 44)
                    .background(locked ? Color(.systemGray5) : (acquired ? Color.purple.opacity(0.15) : Color.accentColor.opacity(0.1)))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(def.name)
                            .font(.subheadline.bold())
                            .foregroundStyle(locked ? .secondary : .primary)

                        if locked {
                            Text("Lv.\(def.requiredLevel)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray5))
                                .clipShape(Capsule())
                                .foregroundStyle(.secondary)
                        }
                    }

                    if acquired {
                        HStack(spacing: 3) {
                            ForEach(1...def.maxRank, id: \.self) { i in
                                Circle()
                                    .fill(i <= rank ? Color.purple : Color(.systemGray4))
                                    .frame(width: 8, height: 8)
                            }
                            Text("Rank \(rank)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } else if let progress, !locked {
                        HStack(spacing: 4) {
                            ProgressView(value: Double(progress.lessonsCompleted), total: Double(GameConstants.Skills.lessonsToAcquire))
                                .tint(.accentColor)
                                .frame(maxWidth: 80)
                            Text("\(progress.lessonsCompleted)/\(GameConstants.Skills.lessonsToAcquire) lessons")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } else if !locked {
                        Text(def.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if acquired && vm.canUpgrade(def.id, player: appState.player) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(.purple)
                }

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(acquired ? Color.purple.opacity(0.05) : Color(.systemGray6))
            )
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail Sheet

    @ViewBuilder
    private func skillDetailSheet(_ def: SkillDefinition) -> some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: def.icon)
                    .font(.system(size: 48))
                    .foregroundStyle(.purple)
                    .padding()
                    .background(.purple.opacity(0.1))
                    .clipShape(Circle())

                Text(def.name)
                    .font(.title2.bold())

                if let exclusive = def.exclusiveTo {
                    Label(exclusive.displayName, systemImage: exclusive.displayIcon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(def.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                let rank = viewModel?.rank(for: def.id) ?? 0
                let acquired = viewModel?.isAcquired(def.id) ?? false

                if acquired {
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            ForEach(1...def.maxRank, id: \.self) { i in
                                Circle()
                                    .fill(i <= rank ? Color.purple : Color(.systemGray4))
                                    .frame(width: 12, height: 12)
                            }
                        }
                        Text("Rank \(rank) / \(def.maxRank)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Each rank = 20% of full effect")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    if let vm = viewModel, vm.canUpgrade(def.id, player: appState.player) {
                        Button {
                            @Bindable var state = appState
                            if vm.upgradeSkill(def.id, player: &state.player) {
                                Task {
                                    await container.playerService.savePlayer(appState.player)
                                }
                            }
                        } label: {
                            Label("Upgrade (1 skill point)", systemImage: "arrow.up.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .padding(.horizontal)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                        Text("Requires Level \(def.requiredLevel)")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    VStack(spacing: 4) {
                        Text("Learned via:")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        ForEach(Array(def.teachingDrills), id: \.self) { drill in
                            Text(drill.displayName)
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }

                Spacer()
            }
            .padding(.top, 24)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { selectedSkill = nil }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

extension SkillDefinition: Identifiable {}
