import Foundation

struct StoreItem: Identifiable, Sendable {
    let id: UUID
    let equipment: Equipment
    let price: Int
    var isSoldOut: Bool

    init(equipment: Equipment, price: Int, isSoldOut: Bool = false) {
        self.id = equipment.id
        self.equipment = equipment
        self.price = price
        self.isSoldOut = isSoldOut
    }
}
