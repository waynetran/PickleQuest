import SpriteKit

@MainActor
enum CourtRenderer {
    private typealias C = MatchAnimationConstants.Court
    private typealias Z = MatchAnimationConstants.ZPositions

    /// Convert normalized court coords (0-1 for both axes) to scene points.
    /// (0,0) = near-left, (1,1) = far-right.
    /// Y=0 is near baseline (bottom of court), Y=1 is far baseline (top).
    static func courtPoint(nx: CGFloat, ny: CGFloat) -> CGPoint {
        let y = C.courtBottomY + ny * C.courtHeight
        let baselineWidth = interpolatedWidth(ny: ny)
        let centerX = MatchAnimationConstants.sceneWidth / 2
        let x = centerX + (nx - 0.5) * baselineWidth
        return CGPoint(x: x, y: y)
    }

    /// Scale factor for objects at a given depth (ny: 0=near, 1=far).
    /// Near objects are full scale, far objects shrink with perspective.
    static func perspectiveScale(ny: CGFloat) -> CGFloat {
        let nearScale: CGFloat = 1.0
        let farScale: CGFloat = 0.55
        return nearScale + (farScale - nearScale) * ny
    }

    /// Build the court node tree.
    static func buildCourt() -> SKNode {
        let courtNode = SKNode()
        courtNode.name = "court"

        // Court surface (trapezoid)
        let surface = buildTrapezoid(
            bottomWidth: C.nearBaselineWidth,
            topWidth: C.farBaselineWidth,
            height: C.courtHeight,
            color: UIColor(hex: C.surfaceColor)
        )
        surface.position = CGPoint(x: MatchAnimationConstants.sceneWidth / 2, y: C.courtBottomY)
        surface.zPosition = Z.courtSurface
        surface.name = "surface"
        courtNode.addChild(surface)

        // Kitchen zones (slightly darker, near and far side)
        let kitchenNear = buildKitchenZone(bottomNY: 0, topNY: C.kitchenDepthRatio)
        kitchenNear.zPosition = Z.courtSurface + 0.1
        kitchenNear.name = "kitchenNear"
        courtNode.addChild(kitchenNear)

        let kitchenFar = buildKitchenZone(bottomNY: 1.0 - C.kitchenDepthRatio, topNY: 1.0)
        kitchenFar.zPosition = Z.courtSurface + 0.1
        kitchenFar.name = "kitchenFar"
        courtNode.addChild(kitchenFar)

        // Court lines
        let lines = buildLines()
        lines.zPosition = Z.courtLines
        lines.name = "lines"
        courtNode.addChild(lines)

        // Net
        let net = buildNet()
        net.zPosition = Z.net
        net.name = "net"
        courtNode.addChild(net)

        return courtNode
    }

    // MARK: - Private

    private static func interpolatedWidth(ny: CGFloat) -> CGFloat {
        C.nearBaselineWidth + (C.farBaselineWidth - C.nearBaselineWidth) * ny
    }

    private static func buildTrapezoid(bottomWidth: CGFloat, topWidth: CGFloat, height: CGFloat, color: UIColor) -> SKShapeNode {
        let path = CGMutablePath()
        let halfBottom = bottomWidth / 2
        let halfTop = topWidth / 2
        path.move(to: CGPoint(x: -halfBottom, y: 0))
        path.addLine(to: CGPoint(x: halfBottom, y: 0))
        path.addLine(to: CGPoint(x: halfTop, y: height))
        path.addLine(to: CGPoint(x: -halfTop, y: height))
        path.closeSubpath()

        let node = SKShapeNode(path: path)
        node.fillColor = color
        node.strokeColor = .clear
        return node
    }

    private static func buildKitchenZone(bottomNY: CGFloat, topNY: CGFloat) -> SKShapeNode {
        let bl = courtPoint(nx: 0, ny: bottomNY)
        let br = courtPoint(nx: 1, ny: bottomNY)
        let tr = courtPoint(nx: 1, ny: topNY)
        let tl = courtPoint(nx: 0, ny: topNY)

        let path = CGMutablePath()
        path.move(to: bl)
        path.addLine(to: br)
        path.addLine(to: tr)
        path.addLine(to: tl)
        path.closeSubpath()

        let node = SKShapeNode(path: path)
        node.fillColor = UIColor(hex: C.kitchenColor)
        node.strokeColor = .clear
        return node
    }

    private static func buildLines() -> SKNode {
        let container = SKNode()
        let lineColor = UIColor(hex: C.lineColor)

        // Near baseline (ny=0)
        addLine(to: container, from: courtPoint(nx: 0, ny: 0), to: courtPoint(nx: 1, ny: 0), color: lineColor)
        // Far baseline (ny=1)
        addLine(to: container, from: courtPoint(nx: 0, ny: 1), to: courtPoint(nx: 1, ny: 1), color: lineColor)
        // Left sideline
        addLine(to: container, from: courtPoint(nx: 0, ny: 0), to: courtPoint(nx: 0, ny: 1), color: lineColor)
        // Right sideline
        addLine(to: container, from: courtPoint(nx: 1, ny: 0), to: courtPoint(nx: 1, ny: 1), color: lineColor)
        // Kitchen line near
        addLine(to: container, from: courtPoint(nx: 0, ny: C.kitchenDepthRatio), to: courtPoint(nx: 1, ny: C.kitchenDepthRatio), color: lineColor)
        // Kitchen line far
        addLine(to: container, from: courtPoint(nx: 0, ny: 1.0 - C.kitchenDepthRatio), to: courtPoint(nx: 1, ny: 1.0 - C.kitchenDepthRatio), color: lineColor)
        // Center line (between kitchen lines)
        addLine(to: container, from: courtPoint(nx: 0.5, ny: C.kitchenDepthRatio), to: courtPoint(nx: 0.5, ny: 1.0 - C.kitchenDepthRatio), color: lineColor)

        return container
    }

    private static func addLine(to parent: SKNode, from: CGPoint, to: CGPoint, color: UIColor) {
        let path = CGMutablePath()
        path.move(to: from)
        path.addLine(to: to)
        let line = SKShapeNode(path: path)
        line.strokeColor = color
        line.lineWidth = C.lineWidth
        parent.addChild(line)
    }

    private static func buildNet() -> SKNode {
        let container = SKNode()

        // Net line at ny=0.5
        let left = courtPoint(nx: 0, ny: 0.5)
        let right = courtPoint(nx: 1, ny: 0.5)

        // Net slightly above the line to show height
        let netHeight: CGFloat = 8 * perspectiveScale(ny: 0.5)
        let netPath = CGMutablePath()
        netPath.move(to: CGPoint(x: left.x - 6, y: left.y))
        netPath.addLine(to: CGPoint(x: right.x + 6, y: right.y))
        netPath.addLine(to: CGPoint(x: right.x + 6, y: right.y + netHeight))
        netPath.addLine(to: CGPoint(x: left.x - 6, y: left.y + netHeight))
        netPath.closeSubpath()

        let netShape = SKShapeNode(path: netPath)
        netShape.fillColor = UIColor(hex: MatchAnimationConstants.Court.netColor).withAlphaComponent(0.7)
        netShape.strokeColor = UIColor(hex: MatchAnimationConstants.Court.netColor)
        netShape.lineWidth = 1
        container.addChild(netShape)

        // Net posts
        let postColor = UIColor(hex: MatchAnimationConstants.Court.netPostColor)
        for x in [left.x - 6, right.x + 6] {
            let post = SKShapeNode(rectOf: CGSize(width: 3, height: netHeight + 4))
            post.position = CGPoint(x: x, y: left.y + netHeight / 2)
            post.fillColor = postColor
            post.strokeColor = .clear
            container.addChild(post)
        }

        return container
    }
}
