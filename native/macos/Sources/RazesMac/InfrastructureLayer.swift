import AppKit
import RazesCore
import SpriteKit

struct InfrastructureSignature: Equatable {
  var pavement: [GridPosition]
  var dirtPaths: [GridPosition]
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
      pavement: state.layout.pavement, dirtPaths: state.layout.dirtPaths,
      fences: state.layout.fences,
      rotation: state.layout.viewRotation, season: state.displaySeason)
    guard infrastructureSignature != signature else { return }
    let redraw =
      infrastructureSignature?.rotation != signature.rotation
      || infrastructureSignature?.season != signature.season
    let oldStyles = Dictionary(
      uniqueKeysWithValues: (infrastructureSignature?.fences ?? []).map { ($0.edgeKey, $0.style) })
    infrastructureSignature = signature
    let keys = Set(
      signature.pavement.map { "p:\($0.x):\($0.y)" }
        + signature.dirtPaths.map { "d:\($0.x):\($0.y)" }
        + signature.fences.map { "f:" + $0.edgeKey })
    for key in Array(infrastructureNodes.keys) where !keys.contains(key) {
      infrastructureNodes.removeValue(forKey: key)?.removeFromParent()
    }
    for (point, dirt) in signature.pavement.map({ ($0, false) })
      + signature.dirtPaths.map({ ($0, true) })
    {
      let key = "\(dirt ? "d" : "p"):\(point.x):\(point.y)"
      let node: SKSpriteNode
      if let old = infrastructureNodes[key] as? SKSpriteNode {
        node = old
      } else {
        node = SKSpriteNode(texture: dirt ? texture("terrain-earth") : stoneTexture())
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
      node.colorBlendFactor = signature.season == 3 ? (dirt ? 0.65 : 0.3) : 0
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
      if !node.children.isEmpty && !redraw && oldStyles[fence.edgeKey] == fence.style { continue }
      drawFence(node, fence: fence, rotation: signature.rotation, winter: signature.season == 3)
    }
  }
  func drawFence(_ node: SKNode, fence: FenceSegment, rotation: Int, winter: Bool) {
    let (a, b) = fenceEndpoints(fence, rotation: rotation)
    let center = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    node.position = center
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
    let wattle = fence.style == .wattle
    if wattle {
      for row in 0..<7 {
        let path = CGMutablePath()
        for step in 0...12 {
          let t = CGFloat(step) / 12
          let p = CGPoint(
            x: a.x + (b.x - a.x) * t - center.x,
            y: a.y + (b.y - a.y) * t - center.y + CGFloat(5 + row * 4)
              + (step % 2 == row % 2 ? 1 : -1))
          if step == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        let twig = SKShapeNode(path: path)
        twig.name = "woven-\(row)"
        twig.strokeColor =
          winter && row == 6
          ? .white
          : row % 2 == 0
            ? NSColor(red: 0.59, green: 0.42, blue: 0.24, alpha: 1) : wood
        twig.lineWidth = 3
        twig.lineCap = .round
        node.addChild(twig)
      }
    }
    for height in wattle ? [] : [CGFloat(12), 27] {
      rail(
        CGPoint(x: a.x, y: a.y + height), CGPoint(x: b.x, y: b.y + height),
        .init(white: 0.15, alpha: 1), 6)
      rail(CGPoint(x: a.x, y: a.y + height + 1), CGPoint(x: b.x, y: b.y + height + 1), wood, 4)
      rail(
        CGPoint(x: a.x, y: a.y + height + 2), CGPoint(x: b.x, y: b.y + height + 2),
        winter ? .white : .init(red: 0.72, green: 0.56, blue: 0.32, alpha: 1), 1)
    }
    for t in wattle ? [CGFloat(0), 0.25, 0.5, 0.75, 1] : [CGFloat(0), 0.5, 1] {
      let p = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
      rail(p, CGPoint(x: p.x, y: p.y + 36), .init(white: 0.14, alpha: 1), 7)
      rail(CGPoint(x: p.x + 1, y: p.y), CGPoint(x: p.x + 1, y: p.y + 36), wood, 5)
      rail(
        CGPoint(x: p.x + 1, y: p.y + 33), CGPoint(x: p.x + 1, y: p.y + 36),
        winter ? .white : .init(red: 0.75, green: 0.6, blue: 0.36, alpha: 1), 4)
    }
  }
}
