import SwiftUI

struct DragPreviewView: View {
    @Bindable var vm: InventoryViewModel

    var body: some View {
        if let drag = vm.dragState {
            VStack(spacing: 4) {
                Text(drag.item.slot.icon)
                    .font(.title)

                Text(drag.item.name)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                ForEach(drag.statDeltas) { delta in
                    HStack(spacing: 2) {
                        Text(delta.stat.displayName.prefix(3).uppercased())
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(Color(white: 0.6))
                        Text(delta.formatted)
                            .font(.system(size: 9, design: .monospaced).bold())
                            .foregroundStyle(delta.color)
                    }
                }
            }
            .padding(8)
            .background(Color.black.opacity(0.9))
            .overlay(
                Rectangle()
                    .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
            )
            .position(x: drag.location.x, y: drag.location.y - 60)
            .allowsHitTesting(false)
        }
    }
}
