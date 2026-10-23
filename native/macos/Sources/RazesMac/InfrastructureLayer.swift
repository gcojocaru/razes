import AppKit
import RazesCore
import SpriteKit

struct InfrastructureSignature: Equatable {
  var pavement: [GridPosition]
  var fences: [FenceSegment]
  var rotation, season: Int
}
extension HomesteadScene {
  private func stoneTexture() -> SKTexture {
    if let pavementTexture { return pavementTexture }
    let image = NSImage(size: NSSize(width: 128, height: 128))
    image.lockFocus()
    NSColor(red: 0.28, green: 0.28, blue: 0.25, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: 128, height: 128).fill()
    for row in 0..<8 {
      for column in -1..<7 {
        let shade = Double((row * 7 + column * 13 + 20) % 9) / 70
        NSColor(red: 0.47 + shade, green: 0.46 + shade, blue: 0.40 + shade, alpha: 1).setFill()
        let stone = NSRect(
          x: column * 22 + (row % 2) * 11 + 1, y: row * 16 + 1, width: 20, height: 14)
        NSBezierPath(roundedRect: stone, xRadius: 3, yRadius: 3).fill()
        NSColor.white.withAlphaComponent(0.12).setStroke()
        let highlight = NSBezierPath()
        highlight.move(to: .init(x: stone.minX + 4, y: stone.maxY - 2))
        highlight.line(to: .init(x: stone.maxX - 3, y: stone.maxY - 2))
        highlight.stroke()
      }
    }
    image.unlockFocus()
    let texture = SKTexture(image: image)
    pavementTexture = texture
    return texture
  }
  func fenceEndpoints(_ fence: FenceSegment, rotation: Int) -> (CGPoint, CGPoint) {
    let x = CGFloat(fence.position.x)
    let y = CGFloat(fence.position.y)
    let corners = [
      CGPoint(x: x - 0.5, y: y - 0.5), CGPoint(x: x + 0.5, y: y - 0.5),
      CGPoint(x: x + 0.5, y: y + 0.5), CGPoint(x: x - 0.5, y: y + 0.5),
    ]
    let a = corners[fence.facing]
    let b = corners[(fence.facing + 1) % 4]
    return (
      IsometricLayout.point(column: a.x, row: a.y, rotation: rotation),
      IsometricLayout.point(column: b.x, row: b.y, rotation: rotation)
    )
  }
  func updateInfrastructure(state: GameState) {
    let signature = InfrastructureSignature(
      pavement: state.layout.pavement, fences: state.layout.fences,
      rotation: state.layout.viewRotation, season: state.displaySeason)
    guard infrastructureSignature != signature else { return }
    let redraw =
      infrastructureSignature?.rotation != signature.rotation
      || infrastructureSignature?.season != signature.season
    infrastructureSignature = signature
    let keys = Set(
      signature.pavement.map { "p:\($0.x):\($0.y)" } + signature.fences.map { "f:" + $0.edgeKey })
    for key in Array(infrastructureNodes.keys) where !keys.contains(key) {
      infrastructureNodes.removeValue(forKey: key)?.removeFromParent()
    }
    for point in signature.pavement {
      let key = "p:\(point.x):\(point.y)"
      let node: SKSpriteNode
      if let old = infrastructureNodes[key] as? SKSpriteNode {
        node = old
      } else {
        node = SKSpriteNode(texture: stoneTexture())
        node.name = key
        node.size = CGSize(width: 131, height: 65.5)
        node.warpGeometry = SKWarpGeometryGrid(
          columns: 1, rows: 1,
          sourcePositions: [
            SIMD2<Float>(0, 0), SIMD2<Float>(1, 0), SIMD2<Float>(0, 1), SIMD2<Float>(1, 1),
          ],
          destinationPositions: [
            SIMD2<Float>(0, 0.5), SIMD2<Float>(0.5, 0), SIMD2<Float>(0.5, 1), SIMD2<Float>(1, 0.5),
          ])
        node.zPosition = 1
        childNode(withName: "terrain")!.addChild(node)
        infrastructureNodes[key] = node
      }
      node.position = IsometricLayout.point(
        column: CGFloat(point.x), row: CGFloat(point.y), rotation: signature.rotation)
      node.color = .white
      node.colorBlendFactor = signature.season == 3 ? 0.3 : 0
    }
    for fence in signature.fences {
      let key = "f:" + fence.edgeKey
      let node: SKNode
      if let old = infrastructureNodes[key] {
        node = old
      } else {
        node = SKNode()
        node.name = key
        childNode(withName: "world")!.addChild(node)
        infrastructureNodes[key] = node
      }
      let (a, b) = fenceEndpoints(fence, rotation: signature.rotation)
      let center = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
      node.position = center
      node.zPosition = 1000 - center.y
      if !node.children.isEmpty && !redraw { continue }
      node.removeAllChildren()
      func rail(_ start: CGPoint, _ end: CGPoint, _ color: NSColor, _ width: CGFloat) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: start.x - center.x, y: start.y - center.y))
        path.addLine(to: CGPoint(x: end.x - center.x, y: end.y - center.y))
        let line = SKShapeNode(path: path)
        line.strokeColor = color
        line.lineWidth = width
        line.lineCap = .round
        node.addChild(line)
      }
      let wood = NSColor(red: 0.44, green: 0.30, blue: 0.16, alpha: 1)
      for height in [CGFloat(12), 27] {
        rail(
          CGPoint(x: a.x, y: a.y + height), CGPoint(x: b.x, y: b.y + height),
          .init(white: 0.15, alpha: 1), 6)
        rail(CGPoint(x: a.x, y: a.y + height + 1), CGPoint(x: b.x, y: b.y + height + 1), wood, 4)
        rail(
          CGPoint(x: a.x, y: a.y + height + 2), CGPoint(x: b.x, y: b.y + height + 2),
          signature.season == 3 ? .white : .init(red: 0.72, green: 0.56, blue: 0.32, alpha: 1), 1)
      }
      for t in [CGFloat(0), 0.5, 1] {
        let p = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        rail(p, CGPoint(x: p.x, y: p.y + 36), .init(white: 0.14, alpha: 1), 7)
        rail(CGPoint(x: p.x + 1, y: p.y), CGPoint(x: p.x + 1, y: p.y + 36), wood, 5)
        rail(
          CGPoint(x: p.x + 1, y: p.y + 33), CGPoint(x: p.x + 1, y: p.y + 36),
          .init(red: 0.75, green: 0.6, blue: 0.36, alpha: 1), 4)
      }
    }
  }
}
