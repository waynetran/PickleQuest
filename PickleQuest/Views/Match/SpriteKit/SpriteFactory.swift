import SpriteKit
import UIKit

@MainActor
enum SpriteFactory {
    // MARK: - Texture Cache

    private static var textureCache: [CharacterAppearance: [CharacterAnimationState: [SKTexture]]] = [:]

    // MARK: - Sprite Sheet Character Node

    static func makeCharacterNode(
        appearance: CharacterAppearance,
        isNearPlayer: Bool
    ) -> (node: SKSpriteNode, textures: [CharacterAnimationState: [SKTexture]]) {
        let textures = loadTextures(for: appearance)
        let idleState = CharacterAnimationState.idle(isNear: isNearPlayer)
        let idleFrames = textures[idleState] ?? []

        let firstTexture = idleFrames.first ?? makeFallbackTexture(isNear: isNearPlayer)
        let node = SKSpriteNode(texture: firstTexture)
        node.texture?.filteringMode = .nearest

        return (node, textures)
    }

    // MARK: - Ball Textures from Sprite Sheet

    static func makeBallTextures() -> [SKTexture] {
        let frames = SpriteSheetLoader.sliceBallFrames(named: "ball")
        if frames.isEmpty {
            // Fallback to programmatic ball
            return [makeBall()]
        }
        return frames.map { cgImage in
            let texture = SKTexture(cgImage: cgImage)
            texture.filteringMode = .nearest
            return texture
        }
    }

    // MARK: - Texture Loading & Caching

    static func loadTextures(for appearance: CharacterAppearance) -> [CharacterAnimationState: [SKTexture]] {
        if let cached = textureCache[appearance] {
            return cached
        }

        guard let sheet = SpriteSheetLoader.loadSheet(named: "character1-Sheet") else {
            // Fallback: return empty dict, callers use fallback textures
            return [:]
        }

        // Apply color replacement to entire sheet
        let mappings = ColorReplacer.buildMappings(from: appearance)
        guard let colorReplaced = ColorReplacer.replaceColors(in: sheet, mappings: mappings) else {
            return [:]
        }

        // Fill paddle interior solid (fix checkerboard string pattern)
        let paddleColor = ColorReplacer.parseHex(appearance.paddleColor)
        let shoeColor = ColorReplacer.parseHex(appearance.shoeColor)
        let recoloredSheet = ColorReplacer.fillPaddleArea(
            in: colorReplaced,
            paddleColor: paddleColor,
            shoeColor: shoeColor
        ) ?? colorReplaced

        // Slice all animation states
        var textures: [CharacterAnimationState: [SKTexture]] = [:]

        for state in allAnimationStates {
            let frameCount = SpriteSheetLoader.detectFrameCount(sheet: recoloredSheet, row: state.sheetRow)
            guard frameCount > 0 else { continue }

            let frames = SpriteSheetLoader.sliceFrames(
                sheet: recoloredSheet,
                row: state.sheetRow,
                columns: frameCount
            )

            textures[state] = frames.map { cgImage in
                let texture = SKTexture(cgImage: cgImage)
                texture.filteringMode = .nearest
                return texture
            }
        }

        textureCache[appearance] = textures
        return textures
    }

    static func clearCache() {
        textureCache.removeAll()
    }

    // MARK: - All States

    private static let allAnimationStates: [CharacterAnimationState] = [
        .idleBack, .idleFront, .walkToward, .walkAway,
        .walkLeft, .walkRight, .ready, .servePrep,
        .serveSwing, .forehand, .backhand, .runDive, .celebrate
    ]

    // MARK: - Fallback (Programmatic Sprites)

    private static func makeFallbackTexture(isNear: Bool) -> SKTexture {
        if isNear {
            return makeNearPlayer()
        } else {
            return makeFarPlayer()
        }
    }

    private static func makeNearPlayer() -> SKTexture {
        let w = 16
        let h = 24
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        let image = renderer.image { ctx in
            let c = ctx.cgContext
            c.setFillColor(UIColor(hex: "#5D4037").cgColor)
            c.fill(CGRect(x: 5, y: 0, width: 6, height: 2))
            c.fill(CGRect(x: 4, y: 2, width: 8, height: 3))
            c.setFillColor(UIColor(hex: "#F5CBA7").cgColor)
            c.fill(CGRect(x: 6, y: 5, width: 4, height: 1))
            c.setFillColor(UIColor(hex: "#3498DB").cgColor)
            c.fill(CGRect(x: 3, y: 6, width: 10, height: 4))
            c.fill(CGRect(x: 4, y: 10, width: 8, height: 3))
            c.setFillColor(UIColor(hex: "#F5CBA7").cgColor)
            c.fill(CGRect(x: 1, y: 7, width: 2, height: 4))
            c.fill(CGRect(x: 13, y: 7, width: 2, height: 4))
            c.setFillColor(UIColor(hex: "#2C3E50").cgColor)
            c.fill(CGRect(x: 5, y: 13, width: 6, height: 3))
            c.setFillColor(UIColor(hex: "#F5CBA7").cgColor)
            c.fill(CGRect(x: 5, y: 16, width: 2, height: 5))
            c.fill(CGRect(x: 9, y: 16, width: 2, height: 5))
            c.setFillColor(UIColor.white.cgColor)
            c.fill(CGRect(x: 4, y: 21, width: 3, height: 3))
            c.fill(CGRect(x: 9, y: 21, width: 3, height: 3))
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }

    private static func makeFarPlayer() -> SKTexture {
        let w = 12
        let h = 18
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        let image = renderer.image { ctx in
            let c = ctx.cgContext
            c.setFillColor(UIColor(hex: "#212121").cgColor)
            c.fill(CGRect(x: 3, y: 0, width: 6, height: 2))
            c.setFillColor(UIColor(hex: "#F5CBA7").cgColor)
            c.fill(CGRect(x: 3, y: 2, width: 6, height: 3))
            c.setFillColor(UIColor.black.cgColor)
            c.fill(CGRect(x: 4, y: 3, width: 1, height: 1))
            c.fill(CGRect(x: 7, y: 3, width: 1, height: 1))
            c.setFillColor(UIColor(hex: "#F5CBA7").cgColor)
            c.fill(CGRect(x: 5, y: 5, width: 2, height: 1))
            c.setFillColor(UIColor(hex: "#E74C3C").cgColor)
            c.fill(CGRect(x: 2, y: 6, width: 8, height: 3))
            c.fill(CGRect(x: 3, y: 9, width: 6, height: 2))
            c.setFillColor(UIColor(hex: "#F5CBA7").cgColor)
            c.fill(CGRect(x: 0, y: 6, width: 2, height: 3))
            c.fill(CGRect(x: 10, y: 6, width: 2, height: 3))
            c.setFillColor(UIColor(hex: "#2C3E50").cgColor)
            c.fill(CGRect(x: 3, y: 11, width: 6, height: 2))
            c.setFillColor(UIColor(hex: "#F5CBA7").cgColor)
            c.fill(CGRect(x: 4, y: 13, width: 2, height: 3))
            c.fill(CGRect(x: 7, y: 13, width: 2, height: 3))
            c.setFillColor(UIColor.white.cgColor)
            c.fill(CGRect(x: 3, y: 16, width: 3, height: 2))
            c.fill(CGRect(x: 7, y: 16, width: 3, height: 2))
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }

    // MARK: - Legacy Ball (fallback)
    static func makeBall() -> SKTexture {
        let s = 6
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: s, height: s))
        let image = renderer.image { ctx in
            let c = ctx.cgContext
            c.setFillColor(UIColor(hex: "#CDDC39").cgColor)
            c.fill(CGRect(x: 1, y: 0, width: 4, height: 1))
            c.fill(CGRect(x: 0, y: 1, width: 6, height: 4))
            c.fill(CGRect(x: 1, y: 5, width: 4, height: 1))
            c.setFillColor(UIColor(hex: "#8BC34A").cgColor)
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
