import UIKit
import CoreGraphics

struct ColorMapping: Sendable {
    let sourceR: UInt8
    let sourceG: UInt8
    let sourceB: UInt8
    let targetR: UInt8
    let targetG: UInt8
    let targetB: UInt8
}

enum ColorReplacer {
    /// Tolerance for RGB matching (0-255 scale)
    private static let tolerance: Int = 12

    // MARK: - Source palette from character1-Sheet.png

    /// Hair dark shade
    static let srcHairDark = (r: UInt8(0x35), g: UInt8(0x2B), b: UInt8(0x42))
    /// Hair base/lighter shade
    static let srcHairBase = (r: UInt8(0x6A), g: UInt8(0x53), b: UInt8(0x6E))

    /// Skin base (lighter tone)
    static let srcSkinBase = (r: UInt8(0xA7), g: UInt8(0x7B), b: UInt8(0x5B))
    /// Skin dark (shadow)
    static let srcSkinDark = (r: UInt8(0x80), g: UInt8(0x49), b: UInt8(0x3A))

    /// Shirt base (off-white in template)
    static let srcShirtBase = (r: UInt8(0xF2), g: UInt8(0xF0), b: UInt8(0xE5))
    /// Shirt shadow
    static let srcShirtShadow = (r: UInt8(0xB8), g: UInt8(0xB5), b: UInt8(0xB9))

    /// Shorts
    static let srcShorts = (r: UInt8(0x3A), g: UInt8(0x38), b: UInt8(0x58))

    /// Shoe light
    static let srcShoeLight = (r: UInt8(0xED), g: UInt8(0xE1), b: UInt8(0x9E))
    /// Shoe base
    static let srcShoeBase = (r: UInt8(0xB2), g: UInt8(0xB4), b: UInt8(0x7E))
    /// Shoe dark
    static let srcShoeDark = (r: UInt8(0x7B), g: UInt8(0x72), b: UInt8(0x43))

    /// Racquet strings (yellow-green in template)
    static let srcRacquet = (r: UInt8(0xC2), g: UInt8(0xD3), b: UInt8(0x68))

    // MARK: - Color Replacement

    static func replaceColors(in image: CGImage, mappings: [ColorMapping]) -> CGImage? {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        for i in stride(from: 0, to: pixelData.count, by: bytesPerPixel) {
            let a = pixelData[i + 3]
            guard a > 10 else { continue } // skip transparent

            let r = pixelData[i]
            let g = pixelData[i + 1]
            let b = pixelData[i + 2]

            // Unpremultiply if needed
            let ur: UInt8, ug: UInt8, ub: UInt8
            if a < 255 {
                ur = UInt8(min(255, Int(r) * 255 / Int(a)))
                ug = UInt8(min(255, Int(g) * 255 / Int(a)))
                ub = UInt8(min(255, Int(b) * 255 / Int(a)))
            } else {
                ur = r; ug = g; ub = b
            }

            for mapping in mappings {
                if matches(ur, ug, ub, mapping.sourceR, mapping.sourceG, mapping.sourceB) {
                    let newR = blendChannel(original: ur, sourceBase: mapping.sourceR, target: mapping.targetR)
                    let newG = blendChannel(original: ug, sourceBase: mapping.sourceG, target: mapping.targetG)
                    let newB = blendChannel(original: ub, sourceBase: mapping.sourceB, target: mapping.targetB)

                    // Re-premultiply
                    if a < 255 {
                        pixelData[i] = UInt8(Int(newR) * Int(a) / 255)
                        pixelData[i + 1] = UInt8(Int(newG) * Int(a) / 255)
                        pixelData[i + 2] = UInt8(Int(newB) * Int(a) / 255)
                    } else {
                        pixelData[i] = newR
                        pixelData[i + 1] = newG
                        pixelData[i + 2] = newB
                    }
                    break // first match wins
                }
            }
        }

        return context.makeImage()
    }

    // MARK: - Mapping Builder

    static func buildMappings(from appearance: CharacterAppearance) -> [ColorMapping] {
        var mappings: [ColorMapping] = []

        let hair = parseHex(appearance.hairColor)
        let hairDark = darken(hair, factor: 0.6)
        mappings.append(ColorMapping(
            sourceR: srcHairDark.r, sourceG: srcHairDark.g, sourceB: srcHairDark.b,
            targetR: hairDark.r, targetG: hairDark.g, targetB: hairDark.b
        ))
        mappings.append(ColorMapping(
            sourceR: srcHairBase.r, sourceG: srcHairBase.g, sourceB: srcHairBase.b,
            targetR: hair.r, targetG: hair.g, targetB: hair.b
        ))

        let skin = parseHex(appearance.skinTone)
        let skinDark = darken(skin, factor: 0.7)
        mappings.append(ColorMapping(
            sourceR: srcSkinBase.r, sourceG: srcSkinBase.g, sourceB: srcSkinBase.b,
            targetR: skin.r, targetG: skin.g, targetB: skin.b
        ))
        mappings.append(ColorMapping(
            sourceR: srcSkinDark.r, sourceG: srcSkinDark.g, sourceB: srcSkinDark.b,
            targetR: skinDark.r, targetG: skinDark.g, targetB: skinDark.b
        ))

        let shirt = parseHex(appearance.shirtColor)
        let shirtShadow = darken(shirt, factor: 0.75)
        mappings.append(ColorMapping(
            sourceR: srcShirtBase.r, sourceG: srcShirtBase.g, sourceB: srcShirtBase.b,
            targetR: shirt.r, targetG: shirt.g, targetB: shirt.b
        ))
        mappings.append(ColorMapping(
            sourceR: srcShirtShadow.r, sourceG: srcShirtShadow.g, sourceB: srcShirtShadow.b,
            targetR: shirtShadow.r, targetG: shirtShadow.g, targetB: shirtShadow.b
        ))

        let shorts = parseHex(appearance.shortsColor)
        mappings.append(ColorMapping(
            sourceR: srcShorts.r, sourceG: srcShorts.g, sourceB: srcShorts.b,
            targetR: shorts.r, targetG: shorts.g, targetB: shorts.b
        ))

        let shoe = parseHex(appearance.shoeColor)
        let shoeDark = darken(shoe, factor: 0.6)
        let shoeMid = darken(shoe, factor: 0.8)
        mappings.append(ColorMapping(
            sourceR: srcShoeLight.r, sourceG: srcShoeLight.g, sourceB: srcShoeLight.b,
            targetR: shoe.r, targetG: shoe.g, targetB: shoe.b
        ))
        mappings.append(ColorMapping(
            sourceR: srcShoeBase.r, sourceG: srcShoeBase.g, sourceB: srcShoeBase.b,
            targetR: shoeMid.r, targetG: shoeMid.g, targetB: shoeMid.b
        ))
        mappings.append(ColorMapping(
            sourceR: srcShoeDark.r, sourceG: srcShoeDark.g, sourceB: srcShoeDark.b,
            targetR: shoeDark.r, targetG: shoeDark.g, targetB: shoeDark.b
        ))

        let paddle = parseHex(appearance.paddleColor)
        mappings.append(ColorMapping(
            sourceR: srcRacquet.r, sourceG: srcRacquet.g, sourceB: srcRacquet.b,
            targetR: paddle.r, targetG: paddle.g, targetB: paddle.b
        ))

        return mappings
    }

    // MARK: - Helpers

    private static func matches(
        _ r: UInt8, _ g: UInt8, _ b: UInt8,
        _ sr: UInt8, _ sg: UInt8, _ sb: UInt8
    ) -> Bool {
        abs(Int(r) - Int(sr)) <= tolerance &&
        abs(Int(g) - Int(sg)) <= tolerance &&
        abs(Int(b) - Int(sb)) <= tolerance
    }

    /// Luminance-preserving blend: scales target by (original / sourceBase) ratio
    private static func blendChannel(original: UInt8, sourceBase: UInt8, target: UInt8) -> UInt8 {
        guard sourceBase > 0 else { return target }
        let ratio = Double(original) / Double(sourceBase)
        let result = Double(target) * ratio
        return UInt8(min(255, max(0, Int(result.rounded()))))
    }

    private static func parseHex(_ hex: String) -> (r: UInt8, g: UInt8, b: UInt8) {
        let stripped = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgbValue: UInt64 = 0
        Scanner(string: stripped).scanHexInt64(&rgbValue)
        return (
            r: UInt8((rgbValue & 0xFF0000) >> 16),
            g: UInt8((rgbValue & 0x00FF00) >> 8),
            b: UInt8(rgbValue & 0x0000FF)
        )
    }

    private static func darken(_ color: (r: UInt8, g: UInt8, b: UInt8), factor: Double) -> (r: UInt8, g: UInt8, b: UInt8) {
        (
            r: UInt8(max(0, min(255, Int(Double(color.r) * factor)))),
            g: UInt8(max(0, min(255, Int(Double(color.g) * factor)))),
            b: UInt8(max(0, min(255, Int(Double(color.b) * factor))))
        )
    }
}
