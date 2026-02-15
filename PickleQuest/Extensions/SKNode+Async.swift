import SpriteKit

extension SKNode {
    @MainActor
    func runAsync(_ action: SKAction) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            run(action) {
                continuation.resume()
            }
        }
    }
}
