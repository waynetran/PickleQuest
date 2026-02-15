import SwiftUI

struct AnimatedSpriteView: View {
    let appearance: CharacterAppearance
    var size: CGFloat = 40
    var animationState: CharacterAnimationState = .idleFront

    @State private var frames: [UIImage] = []

    var body: some View {
        Group {
            if !frames.isEmpty {
                TimelineView(.periodic(from: .now, by: animationState.frameDuration)) { context in
                    let index = frameIndex(for: context.date)
                    Image(uiImage: frames[index])
                        .interpolation(.none)
                        .resizable()
                        .frame(width: size, height: size)
                }
            } else {
                Rectangle()
                    .fill(.clear)
                    .frame(width: size, height: size)
            }
        }
        .task(id: AnimationKey(appearance: appearance, state: animationState)) {
            let loaded = await loadFrames()
            frames = loaded
        }
    }

    private func frameIndex(for date: Date) -> Int {
        guard frames.count > 1 else { return 0 }
        let elapsed = date.timeIntervalSinceReferenceDate
        let total = animationState.frameDuration * Double(frames.count)
        let position = elapsed.truncatingRemainder(dividingBy: total)
        return Int(position / animationState.frameDuration) % frames.count
    }

    @Sendable
    private func loadFrames() async -> [UIImage] {
        let sheetName = appearance.spriteSheet
        let app = appearance
        let state = animationState

        return await Task.detached {
            guard let sheet = SpriteSheetLoader.loadSheet(named: sheetName) else { return [UIImage]() }

            let row = state.sheetRow
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

private struct AnimationKey: Equatable {
    let appearance: CharacterAppearance
    let state: CharacterAnimationState
}
