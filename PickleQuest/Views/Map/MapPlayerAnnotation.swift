import SwiftUI

struct MapPlayerAnnotation: View {
    let appearance: CharacterAppearance

    @State private var frames: [UIImage] = []

    private static let frameDuration: TimeInterval = 0.15

    var body: some View {
        ZStack {
            Circle()
                .fill(.blue.opacity(0.2))
                .frame(width: 48, height: 48)

            if !frames.isEmpty {
                TimelineView(.periodic(from: .now, by: Self.frameDuration)) { context in
                    let index = frameIndex(for: context.date)
                    Image(uiImage: frames[index])
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 40, height: 40)
                }
            }
        }
        .task {
            guard frames.isEmpty else { return }
            let loaded = await loadFrames()
            frames = loaded
        }
    }

    private func frameIndex(for date: Date) -> Int {
        guard frames.count > 1 else { return 0 }
        let elapsed = date.timeIntervalSinceReferenceDate
        let total = Self.frameDuration * Double(frames.count)
        let position = elapsed.truncatingRemainder(dividingBy: total)
        return Int(position / Self.frameDuration) % frames.count
    }

    @Sendable
    private func loadFrames() async -> [UIImage] {
        let sheetName = appearance.spriteSheet
        let app = appearance

        return await Task.detached {
            guard let sheet = SpriteSheetLoader.loadSheet(named: sheetName) else { return [UIImage]() }

            let row = CharacterAnimationState.idleFront.sheetRow
            let count = SpriteSheetLoader.detectFrameCount(sheet: sheet, row: row)
            guard count > 0 else { return [UIImage]() }

            let rawFrames = SpriteSheetLoader.sliceFrames(sheet: sheet, row: row, columns: count)
            let mappings = ColorReplacer.buildMappings(from: app)
            let paddleColor = ColorReplacer.parseHex(app.paddleColor)
            let shoeColor = ColorReplacer.parseHex(app.shoeColor)

            var colored: [UIImage] = []
            for raw in rawFrames {
                var result = ColorReplacer.replaceColors(in: raw, mappings: mappings) ?? raw
                result = ColorReplacer.fillPaddleArea(in: result, paddleColor: paddleColor, shoeColor: shoeColor) ?? result
                colored.append(UIImage(cgImage: result))
            }
            return colored
        }.value
    }
}
