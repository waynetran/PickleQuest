import SwiftUI

/// Draws a simplified pickleball court (near half) with perspective as a background.
struct CourtBackgroundView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            // Perspective: near baseline is wider, far (net line) is narrower
            let nearWidth = w * 0.95
            let farWidth = w * 0.55
            let courtTop = h * 0.08    // net line Y
            let courtBottom = h * 0.98 // near baseline Y
            let courtHeight = courtBottom - courtTop

            // Kitchen line at ~32% from the net
            let kitchenY = courtTop + courtHeight * 0.32

            // Center line X
            let cx = w / 2

            Canvas { context, _ in
                // Helper: interpolate width at a given Y fraction (0=top/far, 1=bottom/near)
                func widthAt(_ fraction: CGFloat) -> CGFloat {
                    farWidth + (nearWidth - farWidth) * fraction
                }
                func leftX(_ fraction: CGFloat) -> CGFloat {
                    cx - widthAt(fraction) / 2
                }
                func rightX(_ fraction: CGFloat) -> CGFloat {
                    cx + widthAt(fraction) / 2
                }
                func fractionForY(_ y: CGFloat) -> CGFloat {
                    (y - courtTop) / courtHeight
                }

                // Green fill — covers entire canvas so no black edges show
                var fullFill = Path()
                fullFill.addRect(CGRect(x: 0, y: 0, width: w, height: h))
                context.fill(fullFill, with: .color(Color(hex: "3A8C42")))

                // Court surface (blue)
                var surfacePath = Path()
                surfacePath.move(to: CGPoint(x: leftX(0), y: courtTop))
                surfacePath.addLine(to: CGPoint(x: rightX(0), y: courtTop))
                surfacePath.addLine(to: CGPoint(x: rightX(1), y: courtBottom))
                surfacePath.addLine(to: CGPoint(x: leftX(1), y: courtBottom))
                surfacePath.closeSubpath()
                context.fill(surfacePath, with: .color(Color(hex: "4A86C8")))

                // Kitchen zone (grey, from net to kitchen line)
                let kitchenFrac = fractionForY(kitchenY)
                var kitchenPath = Path()
                kitchenPath.move(to: CGPoint(x: leftX(0), y: courtTop))
                kitchenPath.addLine(to: CGPoint(x: rightX(0), y: courtTop))
                kitchenPath.addLine(to: CGPoint(x: rightX(kitchenFrac), y: kitchenY))
                kitchenPath.addLine(to: CGPoint(x: leftX(kitchenFrac), y: kitchenY))
                kitchenPath.closeSubpath()
                context.fill(kitchenPath, with: .color(Color(hex: "8E8E93")))

                // Lines (white, 4x thick)
                let lineWidth: CGFloat = 8
                let lineColor = Color.white

                // Near baseline
                var baseline = Path()
                baseline.move(to: CGPoint(x: leftX(1), y: courtBottom))
                baseline.addLine(to: CGPoint(x: rightX(1), y: courtBottom))
                context.stroke(baseline, with: .color(lineColor), lineWidth: lineWidth)

                // Far baseline (net line)
                var netLine = Path()
                netLine.move(to: CGPoint(x: leftX(0), y: courtTop))
                netLine.addLine(to: CGPoint(x: rightX(0), y: courtTop))
                context.stroke(netLine, with: .color(lineColor), lineWidth: lineWidth)

                // Left sideline
                var leftSide = Path()
                leftSide.move(to: CGPoint(x: leftX(0), y: courtTop))
                leftSide.addLine(to: CGPoint(x: leftX(1), y: courtBottom))
                context.stroke(leftSide, with: .color(lineColor), lineWidth: lineWidth)

                // Right sideline
                var rightSide = Path()
                rightSide.move(to: CGPoint(x: rightX(0), y: courtTop))
                rightSide.addLine(to: CGPoint(x: rightX(1), y: courtBottom))
                context.stroke(rightSide, with: .color(lineColor), lineWidth: lineWidth)

                // Kitchen line
                var kLine = Path()
                kLine.move(to: CGPoint(x: leftX(kitchenFrac), y: kitchenY))
                kLine.addLine(to: CGPoint(x: rightX(kitchenFrac), y: kitchenY))
                context.stroke(kLine, with: .color(lineColor), lineWidth: lineWidth)

                // Center service line (baseline to kitchen)
                var centerLine = Path()
                centerLine.move(to: CGPoint(x: cx, y: courtBottom))
                centerLine.addLine(to: CGPoint(x: cx, y: kitchenY))
                context.stroke(centerLine, with: .color(lineColor), lineWidth: lineWidth)

                // Net (thick bar at the top)
                let netHeight: CGFloat = 12
                var netRect = Path()
                netRect.move(to: CGPoint(x: leftX(0) - 12, y: courtTop))
                netRect.addLine(to: CGPoint(x: rightX(0) + 12, y: courtTop))
                netRect.addLine(to: CGPoint(x: rightX(0) + 12, y: courtTop - netHeight))
                netRect.addLine(to: CGPoint(x: leftX(0) - 12, y: courtTop - netHeight))
                netRect.closeSubpath()
                context.fill(netRect, with: .color(Color(hex: "C0C0C0").opacity(0.7)))
                context.stroke(netRect, with: .color(Color(hex: "C0C0C0")), lineWidth: 2)
            }
        }
    }
}

// MARK: - Hex Color Extension

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
