import Foundation

struct Wallet: Codable, Equatable, Sendable {
    var coins: Int

    mutating func add(_ amount: Int) {
        coins += amount
    }

    mutating func spend(_ amount: Int) -> Bool {
        guard coins >= amount else { return false }
        coins -= amount
        return true
    }

    var formattedCoins: String {
        "\(coins)"
    }
}
