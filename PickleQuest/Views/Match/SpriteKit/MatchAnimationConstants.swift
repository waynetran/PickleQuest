import Foundation
import CoreGraphics

enum MatchAnimationConstants {
    // Scene
    static let sceneWidth: CGFloat = 390
    static let sceneHeight: CGFloat = 844
    static let anchorPointY: CGFloat = 0

    enum Court {
        // Trapezoid: near baseline wider, far baseline narrower (low court-level perspective)
        static let nearBaselineWidth: CGFloat = 380
        static let farBaselineWidth: CGFloat = 130
        static let courtHeight: CGFloat = 370
        static let courtBottomY: CGFloat = 250
        static let courtTopY: CGFloat = courtBottomY + courtHeight

        // Perspective foreshortening (far court appears shorter)
        static let perspectiveExponent: CGFloat = 0.75

        // Lines
        static let lineWidth: CGFloat = 2
        static let kitchenDepthRatio: CGFloat = 0.318 // 7/22, official pickleball kitchen depth

        // Colors
        static let surfaceColor = "#4A86C8"        // blue court
        static let lineColor = "#FFFFFF"
        static let kitchenColor = "#8E8E93"         // grey kitchen zone
        static let netColor = "#C0C0C0"
        static let netPostColor = "#808080"
        static let apronColor = "#3A8C42"           // green surround
        static let apronPadding: CGFloat = 30
        static let apronBottomExtraPadding: CGFloat = 30   // extra width at bottom for perspective
    }

    enum Sprites {
        // Sprite sheet frame size
        static let frameSize: CGFloat = 64

        // Scale factors for display (2.5× oversized for cartoony look)
        static let nearPlayerScale: CGFloat = 4.0   // 64×4.0 ≈ 256pt (cartoony)
        static let farPlayerScale: CGFloat = 3.5    // 64×3.5 ≈ 224pt (× perspectiveScale)
        static let ballScale: CGFloat = 3.0         // 16×3 = 48pt, visible against characters

        // Display sizes (approximate, for layout calculations)
        static let nearPlayerWidth: CGFloat = frameSize * nearPlayerScale
        static let nearPlayerHeight: CGFloat = frameSize * nearPlayerScale
        static let farPlayerWidth: CGFloat = frameSize * farPlayerScale
        static let farPlayerHeight: CGFloat = frameSize * farPlayerScale
        static let ballSize: CGFloat = 16 * ballScale
    }

    enum Positions {
        // Normalized positions on court (0-1)
        static let nearPlayerNY: CGFloat = 0.08     // near baseline
        static let farPlayerNY: CGFloat = 0.92      // far baseline
        static let playerCenterNX: CGFloat = 0.5
        static let netNY: CGFloat = 0.5

        // Serve positions
        static let serverOffsetNX: CGFloat = 0.35   // slightly right of center
        static let receiverOffsetNX: CGFloat = 0.55

        // Server positions (behind baseline for legal serve)
        static let serverNearNY: CGFloat = -0.03
        static let serverFarNY: CGFloat = 1.03

        // Kitchen approach positions (just behind kitchen line)
        static let kitchenApproachNearNY: CGFloat = 0.37
        static let kitchenApproachFarNY: CGFloat = 0.63

        // Lateral movement range
        static let lateralRangeNX: CGFloat = 0.35   // max offset from center

        // Doubles: side-by-side positions
        static let doublesLeftNX: CGFloat = 0.35
        static let doublesRightNX: CGFloat = 0.65
    }

    enum Timing {
        // Point animation phases
        static let serveDuration: TimeInterval = 0.5
        static let bounceDuration: TimeInterval = 0.3
        static let outcomeDuration: TimeInterval = 0.4
        static let pointPause: TimeInterval = 0.3

        // Ball arc
        static let arcPeak: CGFloat = 48            // max height of ball arc in points

        // Event animations
        static let matchStartDuration: TimeInterval = 2.0
        static let gameStartDuration: TimeInterval = 1.0
        static let gameEndDuration: TimeInterval = 1.5
        static let matchEndDuration: TimeInterval = 2.0
        static let streakDuration: TimeInterval = 0.8
        static let fatigueDuration: TimeInterval = 0.6
        static let abilityDuration: TimeInterval = 0.8

        // Text overlays
        static let textFadeInDuration: TimeInterval = 0.2
        static let textHoldDuration: TimeInterval = 0.6
        static let textFadeOutDuration: TimeInterval = 0.2

        // Rally bounce cap
        static let maxVisualBounces = 5
        static let doublesMaxVisualBounces = 8

        // Timeout animation
        static let timeoutWalkOffDuration: TimeInterval = 0.5
        static let timeoutHoldDuration: TimeInterval = 3.0
        static let timeoutWalkOnDuration: TimeInterval = 0.5
    }

    enum Text {
        static let announcementFontSize: CGFloat = 36
        static let calloutFontSize: CGFloat = 24
        static let smallCalloutFontSize: CGFloat = 18
        static let fontName = "Menlo-Bold"
    }

    enum ZPositions {
        static let courtSurface: CGFloat = 0
        static let courtLines: CGFloat = 1
        static let net: CGFloat = 2
        static let ballShadow: CGFloat = 3
        static let farPlayer: CGFloat = 4
        static let ball: CGFloat = 5
        static let nearPlayer: CGFloat = 6
        static let effects: CGFloat = 7
        static let text: CGFloat = 10
    }
}
