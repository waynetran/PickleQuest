import SpriteKit
import UIKit

@MainActor
final class TrainingDrillScene: SKScene {
    private var playerNode: SKSpriteNode?
    private var coachNode: SKSpriteNode?
    private var playerTextures: [CharacterAnimationState: [SKTexture]] = [:]
    private var coachTextures: [CharacterAnimationState: [SKTexture]] = [:]
    private var ballTextures: [SKTexture] = []
    private let drillType: DrillType
    private let statGained: StatType
    private let statGainAmount: Int
    private let appearance: CharacterAppearance
    private let coachAppearance: CharacterAppearance
    private let onComplete: () -> Void

    init(
        drillType: DrillType,
        statGained: StatType,
        statGainAmount: Int,
        appearance: CharacterAppearance,
        coachAppearance: CharacterAppearance,
        onComplete: @escaping () -> Void
    ) {
        self.drillType = drillType
        self.statGained = statGained
        self.statGainAmount = statGainAmount
        self.appearance = appearance
        self.coachAppearance = coachAppearance
        self.onComplete = onComplete
        super.init(size: CGSize(
            width: MatchAnimationConstants.sceneWidth,
            height: MatchAnimationConstants.sceneHeight
        ))
        self.scaleMode = .aspectFill
        self.anchorPoint = CGPoint(x: 0, y: 0)
        self.backgroundColor = UIColor(hex: "#2C3E50")
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    override func didMove(to view: SKView) {
        buildScene()
        runDrillAnimation()
    }

    private func buildScene() {
        // Court background
        let court = CourtRenderer.buildCourt()
        addChild(court)

        // Player sprite (near side, facing away)
        let (node, textures) = SpriteFactory.makeCharacterNode(appearance: appearance, isNearPlayer: true)
        playerTextures = textures
        playerNode = node
        node.setScale(MatchAnimationConstants.Sprites.nearPlayerScale)

        let startPos = CourtRenderer.courtPoint(nx: 0.5, ny: 0.15)
        node.position = startPos
        node.zPosition = MatchAnimationConstants.ZPositions.nearPlayer
        addChild(node)

        // Coach sprite (far side, using coach's actual appearance)
        let (cNode, cTextures) = SpriteFactory.makeCharacterNode(appearance: coachAppearance, isNearPlayer: false)
        coachTextures = cTextures
        coachNode = cNode
        let farScale = MatchAnimationConstants.Sprites.farPlayerScale * CourtRenderer.perspectiveScale(ny: 0.92)
        cNode.setScale(farScale)

        let coachPos = CourtRenderer.courtPoint(nx: 0.5, ny: 0.92)
        cNode.position = coachPos
        cNode.zPosition = MatchAnimationConstants.ZPositions.farPlayer
        addChild(cNode)

        // Ball textures
        ballTextures = SpriteFactory.makeBallTextures()
    }

    private func runDrillAnimation() {
        guard let player = playerNode, let coach = coachNode else { return }

        let duration = GameConstants.Training.drillAnimationDuration

        switch drillType {
        case .servePractice:
            runServeAnimation(player: player, duration: duration)
            runCoachFeedingAnimation(coach: coach, duration: duration)
        case .baselineRally:
            runRallyAnimation(player: player, duration: duration)
            runCoachFeedingAnimation(coach: coach, duration: duration)
        case .dinkingDrill:
            runRallyAnimation(player: player, duration: duration)
            runCoachFeedingAnimation(coach: coach, duration: duration)
        case .returnOfServe:
            runDefenseAnimation(player: player, coach: coach, duration: duration)
        }

        // Show stat gain label at end, then call onComplete
        let showDelay = SKAction.wait(forDuration: duration + 0.5)
        let showLabel = SKAction.run { [weak self] in
            self?.showStatGainLabel()
        }
        let completeDelay = SKAction.wait(forDuration: 1.0)
        let complete = SKAction.run { [weak self] in
            self?.onComplete()
        }
        run(SKAction.sequence([showDelay, showLabel, completeDelay, complete]))
    }

    // MARK: - Coach Feeding Animation

    private func runCoachFeedingAnimation(coach: SKSpriteNode, duration: Double) {
        let forehandFrames = coachTextures[.forehand] ?? []
        let backhandFrames = coachTextures[.backhand] ?? []

        let forehandAction = forehandFrames.isEmpty
            ? SKAction.wait(forDuration: 0.3)
            : SKAction.animate(with: forehandFrames, timePerFrame: 0.06)
        let backhandAction = backhandFrames.isEmpty
            ? SKAction.wait(forDuration: 0.3)
            : SKAction.animate(with: backhandFrames, timePerFrame: 0.06)

        let feedCycle = SKAction.sequence([
            forehandAction,
            SKAction.wait(forDuration: 0.7),
            backhandAction,
            SKAction.wait(forDuration: 0.7)
        ])

        let repeatFeed = SKAction.repeat(feedCycle, count: Int(duration / 1.7))
        coach.run(repeatFeed)
    }

    // MARK: - Drill Animations

    private func runServeAnimation(player: SKSpriteNode, duration: Double) {
        let servePrepPos = CourtRenderer.courtPoint(nx: 0.35, ny: -0.03)

        // Move to serve position
        let moveToServe = SKAction.move(to: servePrepPos, duration: 0.4)

        // Serve prep animation
        let prepFrames = playerTextures[.servePrep] ?? []
        let prepAction = prepFrames.isEmpty
            ? SKAction.wait(forDuration: 0.3)
            : SKAction.animate(with: prepFrames, timePerFrame: 0.10)

        // Serve swing
        let swingFrames = playerTextures[.serveSwing] ?? []
        let swingAction = swingFrames.isEmpty
            ? SKAction.wait(forDuration: 0.3)
            : SKAction.animate(with: swingFrames, timePerFrame: 0.06)

        // Ball arc
        let fireBall = SKAction.run { [weak self] in
            self?.launchBall(
                from: servePrepPos,
                to: CourtRenderer.courtPoint(nx: 0.6, ny: 0.7),
                duration: 0.6
            )
        }

        // Repeat serve sequence
        let singleServe = SKAction.sequence([
            moveToServe, prepAction, swingAction, fireBall,
            SKAction.wait(forDuration: 0.8)
        ])
        let repeatServes = SKAction.repeat(singleServe, count: Int(duration / 2.0))
        player.run(repeatServes)
    }

    private func runRallyAnimation(player: SKSpriteNode, duration: Double) {
        let centerPos = CourtRenderer.courtPoint(nx: 0.5, ny: 0.25)
        let leftPos = CourtRenderer.courtPoint(nx: 0.3, ny: 0.25)
        let rightPos = CourtRenderer.courtPoint(nx: 0.7, ny: 0.25)

        let forehandFrames = playerTextures[.forehand] ?? []
        let backhandFrames = playerTextures[.backhand] ?? []

        let forehandAction = forehandFrames.isEmpty
            ? SKAction.wait(forDuration: 0.3)
            : SKAction.animate(with: forehandFrames, timePerFrame: 0.06)
        let backhandAction = backhandFrames.isEmpty
            ? SKAction.wait(forDuration: 0.3)
            : SKAction.animate(with: backhandFrames, timePerFrame: 0.06)

        let rallyBounce = SKAction.sequence([
            SKAction.move(to: centerPos, duration: 0.3),
            SKAction.move(to: rightPos, duration: 0.3),
            forehandAction,
            SKAction.run { [weak self] in
                self?.launchBall(from: rightPos, to: CourtRenderer.courtPoint(nx: 0.4, ny: 0.8), duration: 0.5)
            },
            SKAction.wait(forDuration: 0.5),
            SKAction.move(to: leftPos, duration: 0.3),
            backhandAction,
            SKAction.run { [weak self] in
                self?.launchBall(from: leftPos, to: CourtRenderer.courtPoint(nx: 0.6, ny: 0.75), duration: 0.5)
            },
            SKAction.wait(forDuration: 0.5)
        ])

        let repeatRally = SKAction.repeat(rallyBounce, count: Int(duration / 2.5))
        player.run(SKAction.sequence([SKAction.move(to: centerPos, duration: 0.3), repeatRally]))
    }

    private func runDefenseAnimation(player: SKSpriteNode, coach: SKSpriteNode, duration: Double) {
        let centerPos = CourtRenderer.courtPoint(nx: 0.5, ny: 0.20)
        let forehandFrames = playerTextures[.forehand] ?? []
        let backhandFrames = playerTextures[.backhand] ?? []
        let diveFrames = playerTextures[.runDive] ?? []

        let coachForehand = coachTextures[.forehand] ?? []
        let coachBackhand = coachTextures[.backhand] ?? []

        let forehandAction = forehandFrames.isEmpty
            ? SKAction.wait(forDuration: 0.3)
            : SKAction.animate(with: forehandFrames, timePerFrame: 0.06)
        let backhandAction = backhandFrames.isEmpty
            ? SKAction.wait(forDuration: 0.3)
            : SKAction.animate(with: backhandFrames, timePerFrame: 0.06)
        let diveAction = diveFrames.isEmpty
            ? SKAction.wait(forDuration: 0.3)
            : SKAction.animate(with: diveFrames, timePerFrame: 0.08)

        let coachForehandAction = coachForehand.isEmpty
            ? SKAction.wait(forDuration: 0.3)
            : SKAction.animate(with: coachForehand, timePerFrame: 0.06)
        let coachBackhandAction = coachBackhand.isEmpty
            ? SKAction.wait(forDuration: 0.3)
            : SKAction.animate(with: coachBackhand, timePerFrame: 0.06)

        // Coach feeds balls, player reacts
        let defenseSeq = SKAction.sequence([
            SKAction.move(to: centerPos, duration: 0.2),
            SKAction.run { [weak self] in
                coach.run(coachForehandAction)
                self?.launchBall(from: CourtRenderer.courtPoint(nx: 0.7, ny: 0.85), to: CourtRenderer.courtPoint(nx: 0.7, ny: 0.20), duration: 0.4)
            },
            SKAction.wait(forDuration: 0.3),
            SKAction.move(to: CourtRenderer.courtPoint(nx: 0.7, ny: 0.20), duration: 0.2),
            forehandAction,
            SKAction.wait(forDuration: 0.3),
            SKAction.run { [weak self] in
                coach.run(coachBackhandAction)
                self?.launchBall(from: CourtRenderer.courtPoint(nx: 0.3, ny: 0.85), to: CourtRenderer.courtPoint(nx: 0.3, ny: 0.15), duration: 0.4)
            },
            SKAction.wait(forDuration: 0.3),
            SKAction.move(to: CourtRenderer.courtPoint(nx: 0.3, ny: 0.15), duration: 0.3),
            backhandAction,
            SKAction.wait(forDuration: 0.3),
            SKAction.run { [weak self] in
                coach.run(coachForehandAction)
                self?.launchBall(from: CourtRenderer.courtPoint(nx: 0.5, ny: 0.9), to: CourtRenderer.courtPoint(nx: 0.2, ny: 0.10), duration: 0.3)
            },
            SKAction.wait(forDuration: 0.2),
            SKAction.move(to: CourtRenderer.courtPoint(nx: 0.2, ny: 0.10), duration: 0.2),
            diveAction,
            SKAction.wait(forDuration: 0.5)
        ])

        player.run(defenseSeq)
    }

    private func runFootworkAnimation(player: SKSpriteNode, duration: Double) {
        let leftFrames = playerTextures[.walkLeft] ?? []
        let rightFrames = playerTextures[.walkRight] ?? []

        let walkLeftAction = leftFrames.isEmpty
            ? SKAction.wait(forDuration: 0.4)
            : SKAction.animate(with: leftFrames, timePerFrame: 0.10)
        let walkRightAction = rightFrames.isEmpty
            ? SKAction.wait(forDuration: 0.4)
            : SKAction.animate(with: rightFrames, timePerFrame: 0.10)

        let leftPos = CourtRenderer.courtPoint(nx: 0.15, ny: 0.20)
        let rightPos = CourtRenderer.courtPoint(nx: 0.85, ny: 0.20)
        let centerPos = CourtRenderer.courtPoint(nx: 0.5, ny: 0.20)

        let shuttle = SKAction.sequence([
            SKAction.group([
                SKAction.move(to: leftPos, duration: 0.5),
                walkLeftAction
            ]),
            SKAction.group([
                SKAction.move(to: rightPos, duration: 0.5),
                walkRightAction
            ]),
            SKAction.group([
                SKAction.move(to: centerPos, duration: 0.3),
                walkLeftAction
            ]),
            SKAction.wait(forDuration: 0.2)
        ])

        let repeatShuttle = SKAction.repeat(shuttle, count: Int(duration / 1.5))
        player.run(SKAction.sequence([SKAction.move(to: centerPos, duration: 0.3), repeatShuttle]))
    }

    // MARK: - Ball

    private func launchBall(from: CGPoint, to: CGPoint, duration: Double) {
        guard let texture = ballTextures.first else { return }
        let ball = SKSpriteNode(texture: texture)
        ball.setScale(MatchAnimationConstants.Sprites.ballScale * 0.7)
        ball.position = from
        ball.zPosition = MatchAnimationConstants.ZPositions.ball
        addChild(ball)

        let midY = max(from.y, to.y) + MatchAnimationConstants.Timing.arcPeak
        let midPoint = CGPoint(x: (from.x + to.x) / 2, y: midY)

        let arc = SKAction.sequence([
            SKAction.move(to: midPoint, duration: duration * 0.5),
            SKAction.move(to: to, duration: duration * 0.5)
        ])
        let fadeOut = SKAction.sequence([
            SKAction.wait(forDuration: duration),
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.removeFromParent()
        ])

        ball.run(SKAction.group([arc, fadeOut]))
    }

    // MARK: - Stat Gain Display

    private func showStatGainLabel() {
        let text = "+\(statGainAmount) \(statGained.displayName)"
        let label = SKLabelNode(text: text)
        label.fontName = MatchAnimationConstants.Text.fontName
        label.fontSize = 48
        label.fontColor = .green
        label.position = CGPoint(
            x: MatchAnimationConstants.sceneWidth / 2,
            y: MatchAnimationConstants.sceneHeight / 2
        )
        label.zPosition = MatchAnimationConstants.ZPositions.text
        label.setScale(0.1)
        addChild(label)

        let scaleUp = SKAction.scale(to: 1.5, duration: 0.3)
        scaleUp.timingMode = .easeOut
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.15)
        label.run(SKAction.sequence([scaleUp, scaleDown]))
    }
}
