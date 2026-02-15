import SwiftUI

struct MapPlayerAnnotation: View {
    let appearance: CharacterAppearance
    let animationState: CharacterAnimationState

    init(appearance: CharacterAppearance, animationState: CharacterAnimationState = .idleFront) {
        self.appearance = appearance
        self.animationState = animationState
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(.blue.opacity(0.2))
                .frame(width: 192, height: 192)

            AnimatedSpriteView(appearance: appearance, size: 160, animationState: animationState)
        }
    }
}
