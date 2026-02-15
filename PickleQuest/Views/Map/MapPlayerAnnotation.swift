import SwiftUI

struct MapPlayerAnnotation: View {
    let appearance: CharacterAppearance

    @State private var frames: [UIImage] = []
    @State private var currentFrame = 0
    @State private var timer: Timer?

    private let animationState = CharacterAnimationState.idleFront

    var body: some View {
        ZStack {
            // Blue glow ring for visibility
            Circle()
                .fill(.blue.opacity(0.2))
                .frame(width: 48, height: 48)

            if !frames.isEmpty {
                Image(uiImage: frames[currentFrame])
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 40, height: 40)
            }
        }
        .onAppear { loadAndAnimate() }
        .onDisappear { stopTimer() }
    }

    private func loadAndAnimate() {
        guard frames.isEmpty else {
            startTimer()
            return
        }

        guard let sheet = SpriteSheetLoader.loadSheet(named: appearance.spriteSheet) else { return }

        let row = animationState.sheetRow
        let count = SpriteSheetLoader.detectFrameCount(sheet: sheet, row: row)
        guard count > 0 else { return }

        let rawFrames = SpriteSheetLoader.sliceFrames(sheet: sheet, row: row, columns: count)
        let mappings = ColorReplacer.buildMappings(from: appearance)
        let paddleColor = ColorReplacer.parseHex(appearance.paddleColor)
        let shoeColor = ColorReplacer.parseHex(appearance.shoeColor)

        var colored: [UIImage] = []
        for raw in rawFrames {
            var result = ColorReplacer.replaceColors(in: raw, mappings: mappings) ?? raw
            result = ColorReplacer.fillPaddleArea(in: result, paddleColor: paddleColor, shoeColor: shoeColor) ?? result
            colored.append(UIImage(cgImage: result))
        }

        frames = colored
        currentFrame = 0
        startTimer()
    }

    private func startTimer() {
        stopTimer()
        guard frames.count > 1 else { return }
        timer = Timer.scheduledTimer(withTimeInterval: animationState.frameDuration, repeats: true) { _ in
            currentFrame = (currentFrame + 1) % frames.count
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
