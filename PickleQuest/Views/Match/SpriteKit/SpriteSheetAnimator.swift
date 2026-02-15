import SpriteKit

@MainActor
final class SpriteSheetAnimator {
    private let node: SKSpriteNode
    private let textures: [CharacterAnimationState: [SKTexture]]
    private let isNear: Bool
    private(set) var currentState: CharacterAnimationState?

    private static let actionKey = "spriteSheetAnim"

    init(node: SKSpriteNode, textures: [CharacterAnimationState: [SKTexture]], isNear: Bool) {
        self.node = node
        self.textures = textures
        self.isNear = isNear
    }

    /// Fire-and-forget: starts animation and returns immediately.
    /// Looping animations repeat forever. One-shot animations play once then revert to idle.
    func play(_ state: CharacterAnimationState) {
        guard state != currentState else { return }
        guard let frames = textures[state], !frames.isEmpty else { return }

        currentState = state
        node.removeAction(forKey: Self.actionKey)

        let animate = SKAction.animate(with: frames, timePerFrame: state.frameDuration)

        if state.loops {
            node.run(.repeatForever(animate), withKey: Self.actionKey)
        } else {
            let idleState = CharacterAnimationState.idle(isNear: isNear)
            let idleFrames = textures[idleState] ?? []
            let revert: SKAction
            if !idleFrames.isEmpty {
                revert = .repeatForever(.animate(with: idleFrames, timePerFrame: idleState.frameDuration))
            } else {
                revert = .setTexture(frames.last!)
            }
            node.run(.sequence([animate, revert]), withKey: Self.actionKey)
            // After one-shot completes, update state
            let duration = state.frameDuration * Double(frames.count)
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                if self?.currentState == state {
                    self?.currentState = idleState
                }
            }
        }
    }

    /// Async: plays one-shot animation and returns when it completes. Reverts to idle.
    func playAsync(_ state: CharacterAnimationState) async {
        guard let frames = textures[state], !frames.isEmpty else { return }

        currentState = state
        node.removeAction(forKey: Self.actionKey)

        let animate = SKAction.animate(with: frames, timePerFrame: state.frameDuration)
        await node.runAsync(animate)

        // Revert to idle
        let idleState = CharacterAnimationState.idle(isNear: isNear)
        currentState = idleState
        if let idleFrames = textures[idleState], !idleFrames.isEmpty {
            node.run(.repeatForever(.animate(with: idleFrames, timePerFrame: idleState.frameDuration)), withKey: Self.actionKey)
        }
    }

    /// Show a specific static frame (e.g., for "frozen" states like error flinch)
    func showStaticFrame(_ state: CharacterAnimationState, frameIndex: Int = 0) {
        guard let frames = textures[state], frameIndex < frames.count else { return }
        currentState = state
        node.removeAction(forKey: Self.actionKey)
        node.texture = frames[frameIndex]
    }

    /// Stop current animation and revert to idle
    func stop() {
        let idleState = CharacterAnimationState.idle(isNear: isNear)
        play(idleState)
    }
}
