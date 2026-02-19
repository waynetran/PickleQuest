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

    /// Split step animation: run frames 0-3 then idle frames 0-1, reverts to idle loop.
    /// Timed so the run portion takes `runDuration` and idle portion takes `idleDuration`.
    func playSplitStep() {
        let runState = CharacterAnimationState.run(isNear: isNear)
        let idleState = CharacterAnimationState.idle(isNear: isNear)

        guard let runFrames = textures[runState], runFrames.count >= 4,
              let idleFrames = textures[idleState], idleFrames.count >= 2 else { return }

        currentState = runState
        node.removeAction(forKey: Self.actionKey)

        // Run frames 0-3 (4 frames at 0.08s = 0.32s)
        let runAnim = SKAction.animate(with: Array(runFrames.prefix(4)), timePerFrame: 0.08)
        // Idle frames 0-1 (2 frames at 0.15s = 0.30s)
        let idleAnim = SKAction.animate(with: Array(idleFrames.prefix(2)), timePerFrame: 0.15)
        // Then continue with full idle loop
        let fullIdle = SKAction.repeatForever(.animate(with: idleFrames, timePerFrame: idleState.frameDuration))

        let sequence = SKAction.sequence([runAnim, idleAnim, fullIdle])
        node.run(sequence, withKey: Self.actionKey)

        // Update state after split step finishes
        let totalDuration = 0.08 * 4 + 0.15 * 2
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) { [weak self] in
            if self?.currentState == runState {
                self?.currentState = idleState
            }
        }
    }

    /// Lunge: play first 3 frames of runSide fast, then revert to idle.
    func playLunge(goingRight: Bool) {
        let state = CharacterAnimationState.runSide
        guard let frames = textures[state], frames.count >= 3 else { return }

        currentState = state
        node.removeAction(forKey: Self.actionKey)

        // 3 frames at 0.06s each = 0.18s total
        let lungeAnim = SKAction.animate(with: Array(frames.prefix(3)), timePerFrame: 0.06)

        let idleState = CharacterAnimationState.idle(isNear: isNear)
        let idleFrames = textures[idleState] ?? []
        let revert: SKAction
        if !idleFrames.isEmpty {
            revert = .repeatForever(.animate(with: idleFrames, timePerFrame: idleState.frameDuration))
        } else {
            revert = .setTexture(frames.last!)
        }
        node.run(.sequence([lungeAnim, revert]), withKey: Self.actionKey)

        let duration = 0.06 * 3
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            if self?.currentState == state {
                self?.currentState = idleState
            }
        }
    }

    /// Duration of the run portion of the split step (4 frames at 0.08s)
    static let splitStepRunDuration: CGFloat = 0.08 * 4

    /// Stop current animation and revert to idle
    func stop() {
        let idleState = CharacterAnimationState.idle(isNear: isNear)
        play(idleState)
    }
}
