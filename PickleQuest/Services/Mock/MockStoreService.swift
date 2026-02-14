import Foundation

actor MockStoreService: StoreService {
    private var storeItems: [StoreItem]
    private let lootGenerator: LootGenerator

    init() {
        let generator = LootGenerator()
        self.lootGenerator = generator
        self.storeItems = generator.generateStoreInventory()
    }

    func getStoreInventory() async -> [StoreItem] {
        storeItems
    }

    func refreshStore() async -> [StoreItem] {
        storeItems = lootGenerator.generateStoreInventory()
        return storeItems
    }

    func buyItem(_ itemID: UUID) async -> Equipment? {
        guard let index = storeItems.firstIndex(where: { $0.id == itemID && !$0.isSoldOut }) else {
            return nil
        }
        storeItems[index].isSoldOut = true
        return storeItems[index].equipment
    }
}
