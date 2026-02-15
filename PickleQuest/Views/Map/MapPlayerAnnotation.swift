import SwiftUI

struct MapPlayerAnnotation: View {
    let appearance: CharacterAppearance

    var body: some View {
        ZStack {
            Circle()
                .fill(.blue.opacity(0.2))
                .frame(width: 48, height: 48)

            AnimatedSpriteView(appearance: appearance, size: 40, animationState: .idleFront)
        }
    }
}
