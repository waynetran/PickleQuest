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
        let app = appearance
        let state = animationState
        let cacheKey = FrameCacheKey(appearance: app, state: state)

        if let cached = FrameCache.shared.get(cacheKey) {
            return cached
        }

        return await Task.detached {
            let sheetName = app.spriteSheet
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
            FrameCache.shared.set(cacheKey, frames: colored)
            return colored
        }.value
    }
}

private struct AnimationKey: Equatable {
    let appearance: CharacterAppearance
    let state: CharacterAnimationState
}

// MARK: - Frame Cache

private struct FrameCacheKey: Hashable {
    let appearance: CharacterAppearance
    let state: CharacterAnimationState
}

private final class FrameCacheEntry {
    let frames: [UIImage]
    init(_ frames: [UIImage]) { self.frames = frames }
}

private final class FrameCache: @unchecked Sendable {
    static let shared = FrameCache()
    private let cache = NSCache<AnyHashableWrapper, FrameCacheEntry>()

    init() {
        cache.countLimit = 64
    }

    func get(_ key: FrameCacheKey) -> [UIImage]? {
        cache.object(forKey: AnyHashableWrapper(key))?.frames
    }

    func set(_ key: FrameCacheKey, frames: [UIImage]) {
        cache.setObject(FrameCacheEntry(frames), forKey: AnyHashableWrapper(key))
    }
}

private final class AnyHashableWrapper: NSObject {
    let wrapped: AnyHashable
    init(_ wrapped: AnyHashable) { self.wrapped = wrapped }
    override var hash: Int { wrapped.hashValue }
    override func isEqual(_ object: Any?) -> Bool {
        (object as? AnyHashableWrapper)?.wrapped == wrapped
    }
}
