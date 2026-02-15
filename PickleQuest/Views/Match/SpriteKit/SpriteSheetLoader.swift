import UIKit
import CoreGraphics

enum SpriteSheetLoader {
    static let frameWidth = 64
    static let frameHeight = 64
    static let columns = 10
    static let rows = 13

    static func loadSheet(named name: String) -> CGImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let data = try? Data(contentsOf: url),
              let provider = CGDataProvider(data: data as CFData),
              let image = CGImage(
                  pngDataProviderSource: provider,
                  decode: nil,
                  shouldInterpolate: false,
                  intent: .defaultIntent
              ) else {
            return nil
        }
        return image
    }

    static func sliceFrames(sheet: CGImage, row: Int, columns count: Int) -> [CGImage] {
        var frames: [CGImage] = []
        let y = row * frameHeight

        for col in 0..<count {
            let x = col * frameWidth
            let rect = CGRect(x: x, y: y, width: frameWidth, height: frameHeight)
            if let cropped = sheet.cropping(to: rect) {
                frames.append(cropped)
            }
        }
        return frames
    }

    static func detectFrameCount(sheet: CGImage, row: Int) -> Int {
        let y = row * frameHeight
        let rowStrip = sheet.cropping(to: CGRect(x: 0, y: y, width: sheet.width, height: frameHeight))
        guard let strip = rowStrip else { return 0 }

        // Read pixel data to check for non-empty frames
        let bytesPerPixel = 4
        let bytesPerRow = strip.width * bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: strip.width * strip.height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixelData,
            width: strip.width,
            height: strip.height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 0 }

        context.draw(strip, in: CGRect(x: 0, y: 0, width: strip.width, height: strip.height))

        var count = 0
        for col in 0..<Self.columns {
            let startX = col * frameWidth
            var hasContent = false

            // Check if this frame has any non-transparent pixels
            for py in 0..<frameHeight {
                for px in startX..<(startX + frameWidth) {
                    let offset = (py * bytesPerRow) + (px * bytesPerPixel) + 3 // alpha channel
                    if pixelData[offset] > 10 {
                        hasContent = true
                        break
                    }
                }
                if hasContent { break }
            }

            if hasContent {
                count = col + 1 // contiguous from left
            } else {
                break // stop at first empty frame
            }
        }

        return count
    }

    static func sliceBallFrames(named name: String) -> [CGImage] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let data = try? Data(contentsOf: url),
              let provider = CGDataProvider(data: data as CFData),
              let image = CGImage(
                  pngDataProviderSource: provider,
                  decode: nil,
                  shouldInterpolate: false,
                  intent: .defaultIntent
              ) else {
            return []
        }

        // ball.png is 32x16 — two 16x16 frames side by side
        let ballSize = 16
        var frames: [CGImage] = []
        let count = image.width / ballSize

        for i in 0..<count {
            let rect = CGRect(x: i * ballSize, y: 0, width: ballSize, height: ballSize)
            if let cropped = image.cropping(to: rect) {
                frames.append(cropped)
            }
        }
        return frames
    }
}
