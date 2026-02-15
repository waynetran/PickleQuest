import SpriteKit
import UIKit

@MainActor
final class TrainingDrillScene: SKScene {
    private var playerNode: SKSpriteNode?
    private var playerTextures: [CharacterAnimationState: [SKTexture]] = [:]
    private var ballTextures: [SKTexture] = []
    private let drillType: DrillType
    private let grade: DrillGrade
    private let appearance: CharacterAppearance
    private var animationComplete = false

    init(drillType: DrillType, grade: DrillGrade, appearance: CharacterAppearance) {
        self.drillType = drillType
        self.grade = grade
        self.appearance = appearance
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

        // Ball textures
        ballTextures = SpriteFactory.makeBallTextures()
    }

    private func runDrillAnimation() {
        guard let player = playerNode else { return }

        let duration = GameConstants.Training.drillAnimationDuration

        switch drillType {
        case .servePractice:
            runServeAnimation(player: player, duration: duration)
        case .rallyDrill:
            runRallyAnimation(player: player, duration: duration)
        case .defenseDrill:
            runDefenseAnimation(player: player, duration: duration)
        case .footworkTraining:
            runFootworkAnimation(player: player, duration: duration)
        }

        // Show grade at end
        let gradeDelay = SKAction.wait(forDuration: duration + 0.5)
        let showGrade = SKAction.run { [weak self] in
            self?.showGradeLabel()
        }
        run(SKAction.sequence([gradeDelay, showGrade]))
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

    private func runDefenseAnimation(player: SKSpriteNode, duration: Double) {
        let centerPos = CourtRenderer.courtPoint(nx: 0.5, ny: 0.20)
        let forehandFrames = playerTextures[.forehand] ?? []
        let backhandFrames = playerTextures[.backhand] ?? []
        let diveFrames = playerTextures[.runDive] ?? []

        let forehandAction = forehandFrames.isEmpty
            ? SKAction.wait(forDuration: 0.3)
            : SKAction.animate(with: forehandFrames, timePerFrame: 0.06)
        let backhandAction = backhandFrames.isEmpty
            ? SKAction.wait(forDuration: 0.3)
            : SKAction.animate(with: backhandFrames, timePerFrame: 0.06)
        let diveAction = diveFrames.isEmpty
            ? SKAction.wait(forDuration: 0.3)
            : SKAction.animate(with: diveFrames, timePerFrame: 0.08)

        let defenseSeq = SKAction.sequence([
            SKAction.move(to: centerPos, duration: 0.2),
            // Ball comes from far side, player reacts
            SKAction.run { [weak self] in
                self?.launchBall(from: CourtRenderer.courtPoint(nx: 0.7, ny: 0.85), to: CourtRenderer.courtPoint(nx: 0.7, ny: 0.20), duration: 0.4)
            },
            SKAction.wait(forDuration: 0.3),
            SKAction.move(to: CourtRenderer.courtPoint(nx: 0.7, ny: 0.20), duration: 0.2),
            forehandAction,
            SKAction.wait(forDuration: 0.3),
            SKAction.run { [weak self] in
                self?.launchBall(from: CourtRenderer.courtPoint(nx: 0.3, ny: 0.85), to: CourtRenderer.courtPoint(nx: 0.3, ny: 0.15), duration: 0.4)
            },
            SKAction.wait(forDuration: 0.3),
            SKAction.move(to: CourtRenderer.courtPoint(nx: 0.3, ny: 0.15), duration: 0.3),
            backhandAction,
            SKAction.wait(forDuration: 0.3),
            // Dive save
            SKAction.run { [weak self] in
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

    // MARK: - Grade Display

    private func showGradeLabel() {
        animationComplete = true

        let gradeLabel = SKLabelNode(text: grade.rawValue)
        gradeLabel.fontName = MatchAnimationConstants.Text.fontName
        gradeLabel.fontSize = 72
        gradeLabel.fontColor = UIColor(grade.color)
        gradeLabel.position = CGPoint(
            x: MatchAnimationConstants.sceneWidth / 2,
            y: MatchAnimationConstants.sceneHeight / 2
        )
        gradeLabel.zPosition = MatchAnimationConstants.ZPositions.text
        gradeLabel.setScale(0.1)
        addChild(gradeLabel)

        let scaleUp = SKAction.scale(to: 1.5, duration: 0.3)
        scaleUp.timingMode = .easeOut
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.15)
        gradeLabel.run(SKAction.sequence([scaleUp, scaleDown]))
    }
}
