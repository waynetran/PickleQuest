import Foundation
import CoreGraphics

enum MatchAnimationConstants {
    // Scene
    static let sceneWidth: CGFloat = 390
    static let sceneHeight: CGFloat = 844
    static let anchorPointY: CGFloat = 0

    enum Court {
        // Trapezoid: near baseline wider, far baseline narrower (behind-baseline perspective)
        static let nearBaselineWidth: CGFloat = 320
        static let farBaselineWidth: CGFloat = 180
        static let courtHeight: CGFloat = 400
        static let courtBottomY: CGFloat = 160
        static let courtTopY: CGFloat = courtBottomY + courtHeight

        // Lines
        static let lineWidth: CGFloat = 2
        static let kitchenDepthRatio: CGFloat = 0.22 // kitchen line at 22% from each baseline

        // Colors
        static let surfaceColor = "#2D6A4F"      // dark green court
        static let lineColor = "#FFFFFF"
        static let kitchenColor = "#1B4332"        // slightly darker green for kitchen
        static let netColor = "#C0C0C0"
        static let netPostColor = "#808080"
    }

    enum Sprites {
        // Pixel canvas sizes (drawn at this resolution)
        static let nearPlayerCanvasWidth = 16
        static let nearPlayerCanvasHeight = 24
        static let farPlayerCanvasWidth = 12
        static let farPlayerCanvasHeight = 18
        static let ballCanvasSize = 6

        // Scale factors for display
        static let nearPlayerScale: CGFloat = 4    // 16x24 → 64x96pt
        static let farPlayerScale: CGFloat = 3     // 12x18 → 36x54pt
        static let ballScale: CGFloat = 3          // 6x6 → 18x18pt

        // Display sizes
        static let nearPlayerWidth: CGFloat = CGFloat(nearPlayerCanvasWidth) * nearPlayerScale
        static let nearPlayerHeight: CGFloat = CGFloat(nearPlayerCanvasHeight) * nearPlayerScale
        static let farPlayerWidth: CGFloat = CGFloat(farPlayerCanvasWidth) * farPlayerScale
        static let farPlayerHeight: CGFloat = CGFloat(farPlayerCanvasHeight) * farPlayerScale
        static let ballSize: CGFloat = CGFloat(ballCanvasSize) * ballScale

        // Colors (pixel palette)
        static let playerShirtColor = "#3498DB"    // blue
        static let playerSkinColor = "#F5CBA7"
        static let playerShortsColor = "#2C3E50"
        static let playerHairColor = "#5D4037"
        static let opponentShirtColor = "#E74C3C"  // red
        static let opponentSkinColor = "#F5CBA7"
        static let opponentShortsColor = "#2C3E50"
        static let opponentHairColor = "#212121"
        static let ballColor = "#CDDC39"           // yellow-green wiffle
        static let ballDotColor = "#8BC34A"
        static let paddleColor = "#37474F"
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

        // Lateral movement range
        static let lateralRangeNX: CGFloat = 0.35   // max offset from center
    }

    enum Timing {
        // Point animation phases
        static let serveDuration: TimeInterval = 0.5
        static let bounceDuration: TimeInterval = 0.3
        static let outcomeDuration: TimeInterval = 0.4
        static let pointPause: TimeInterval = 0.3

        // Ball arc
        static let arcPeak: CGFloat = 60            // max height of ball arc in points

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
