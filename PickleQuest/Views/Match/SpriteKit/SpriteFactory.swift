import SpriteKit
import UIKit

@MainActor
enum SpriteFactory {
    // MARK: - Near Player (back view, 16x24 canvas → 64x96pt)
    static func makeNearPlayer(
        shirtColor: UIColor = UIColor(hex: MatchAnimationConstants.Sprites.playerShirtColor),
        shortsColor: UIColor = UIColor(hex: MatchAnimationConstants.Sprites.playerShortsColor),
        skinColor: UIColor = UIColor(hex: MatchAnimationConstants.Sprites.playerSkinColor),
        hairColor: UIColor = UIColor(hex: MatchAnimationConstants.Sprites.playerHairColor)
    ) -> SKTexture {
        let w = MatchAnimationConstants.Sprites.nearPlayerCanvasWidth
        let h = MatchAnimationConstants.Sprites.nearPlayerCanvasHeight
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        let image = renderer.image { ctx in
            let c = ctx.cgContext

            // Hair/head (top, rows 0-5)
            c.setFillColor(hairColor.cgColor)
            c.fill(CGRect(x: 5, y: 0, width: 6, height: 2))
            c.fill(CGRect(x: 4, y: 2, width: 8, height: 3))
            // Neck
            c.setFillColor(skinColor.cgColor)
            c.fill(CGRect(x: 6, y: 5, width: 4, height: 1))

            // Shirt (torso, rows 6-14)
            c.setFillColor(shirtColor.cgColor)
            c.fill(CGRect(x: 3, y: 6, width: 10, height: 4))
            c.fill(CGRect(x: 4, y: 10, width: 8, height: 3))
            // Arms (skin on sides of torso)
            c.setFillColor(skinColor.cgColor)
            c.fill(CGRect(x: 1, y: 7, width: 2, height: 4))   // left arm
            c.fill(CGRect(x: 13, y: 7, width: 2, height: 4))  // right arm

            // Paddle (right hand)
            c.setFillColor(UIColor(hex: MatchAnimationConstants.Sprites.paddleColor).cgColor)
            c.fill(CGRect(x: 14, y: 6, width: 2, height: 3))

            // Shorts (rows 13-16)
            c.setFillColor(shortsColor.cgColor)
            c.fill(CGRect(x: 5, y: 13, width: 6, height: 3))

            // Legs (skin, rows 16-21)
            c.setFillColor(skinColor.cgColor)
            c.fill(CGRect(x: 5, y: 16, width: 2, height: 5))  // left leg
            c.fill(CGRect(x: 9, y: 16, width: 2, height: 5))  // right leg

            // Shoes (rows 21-23)
            c.setFillColor(UIColor.white.cgColor)
            c.fill(CGRect(x: 4, y: 21, width: 3, height: 3))  // left shoe
            c.fill(CGRect(x: 9, y: 21, width: 3, height: 3))  // right shoe
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }

    // MARK: - Far Player (front view, 12x18 canvas → 36x54pt)
    static func makeFarPlayer(
        shirtColor: UIColor = UIColor(hex: MatchAnimationConstants.Sprites.opponentShirtColor),
        shortsColor: UIColor = UIColor(hex: MatchAnimationConstants.Sprites.opponentShortsColor),
        skinColor: UIColor = UIColor(hex: MatchAnimationConstants.Sprites.opponentSkinColor),
        hairColor: UIColor = UIColor(hex: MatchAnimationConstants.Sprites.opponentHairColor)
    ) -> SKTexture {
        let w = MatchAnimationConstants.Sprites.farPlayerCanvasWidth
        let h = MatchAnimationConstants.Sprites.farPlayerCanvasHeight
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        let image = renderer.image { ctx in
            let c = ctx.cgContext

            // Hair (rows 0-1)
            c.setFillColor(hairColor.cgColor)
            c.fill(CGRect(x: 3, y: 0, width: 6, height: 2))

            // Face (rows 2-4)
            c.setFillColor(skinColor.cgColor)
            c.fill(CGRect(x: 3, y: 2, width: 6, height: 3))
            // Eyes
            c.setFillColor(UIColor.black.cgColor)
            c.fill(CGRect(x: 4, y: 3, width: 1, height: 1))
            c.fill(CGRect(x: 7, y: 3, width: 1, height: 1))

            // Neck
            c.setFillColor(skinColor.cgColor)
            c.fill(CGRect(x: 5, y: 5, width: 2, height: 1))

            // Shirt (rows 6-10)
            c.setFillColor(shirtColor.cgColor)
            c.fill(CGRect(x: 2, y: 6, width: 8, height: 3))
            c.fill(CGRect(x: 3, y: 9, width: 6, height: 2))
            // Arms
            c.setFillColor(skinColor.cgColor)
            c.fill(CGRect(x: 0, y: 6, width: 2, height: 3))
            c.fill(CGRect(x: 10, y: 6, width: 2, height: 3))

            // Paddle (right hand)
            c.setFillColor(UIColor(hex: MatchAnimationConstants.Sprites.paddleColor).cgColor)
            c.fill(CGRect(x: 10, y: 5, width: 2, height: 2))

            // Shorts (rows 11-13)
            c.setFillColor(shortsColor.cgColor)
            c.fill(CGRect(x: 3, y: 11, width: 6, height: 2))

            // Legs (rows 13-16)
            c.setFillColor(skinColor.cgColor)
            c.fill(CGRect(x: 4, y: 13, width: 2, height: 3))
            c.fill(CGRect(x: 7, y: 13, width: 2, height: 3))

            // Shoes (rows 16-17)
            c.setFillColor(UIColor.white.cgColor)
            c.fill(CGRect(x: 3, y: 16, width: 3, height: 2))
            c.fill(CGRect(x: 7, y: 16, width: 3, height: 2))
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }

    // MARK: - Ball (6x6 canvas → 18x18pt)
    static func makeBall() -> SKTexture {
        let s = MatchAnimationConstants.Sprites.ballCanvasSize
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: s, height: s))
        let image = renderer.image { ctx in
            let c = ctx.cgContext
            let ballColor = UIColor(hex: MatchAnimationConstants.Sprites.ballColor)
            let dotColor = UIColor(hex: MatchAnimationConstants.Sprites.ballDotColor)

            // Ball body (circle approximation)
            c.setFillColor(ballColor.cgColor)
            c.fill(CGRect(x: 1, y: 0, width: 4, height: 1))
            c.fill(CGRect(x: 0, y: 1, width: 6, height: 4))
            c.fill(CGRect(x: 1, y: 5, width: 4, height: 1))

            // Holes (wiffle ball dots)
            c.setFillColor(dotColor.cgColor)
            c.fill(CGRect(x: 1, y: 2, width: 1, height: 1))
            c.fill(CGRect(x: 3, y: 1, width: 1, height: 1))
            c.fill(CGRect(x: 4, y: 3, width: 1, height: 1))
            c.fill(CGRect(x: 2, y: 4, width: 1, height: 1))
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }
}

// MARK: - UIColor hex helper
extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgbValue: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgbValue)
        self.init(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
}
