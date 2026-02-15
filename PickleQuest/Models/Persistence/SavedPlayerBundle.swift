import Foundation

struct SavedPlayerBundle: Sendable {
    let player: Player
    let inventory: [Equipment]
    let consumables: [Consumable]
    let fogCells: Set<FogCell>
    let tutorialCompleted: Bool
}
