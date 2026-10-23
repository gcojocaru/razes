import AppKit
import RazesCore
import SpriteKit

@MainActor final class TerrainLayer: SKNode {
  private var tiles: [SKSpriteNode] = []
  private var signature = ""
  private var surfaces: [String: SKTexture] = [:]
  private var edges: [SKShapeNode] = []
  override init() {
    super.init()
    name = "isometric-ground"
    for (index, corners) in [
      [
        CGPoint(x: 72, y: 412.5), CGPoint(x: 600, y: 148.5), CGPoint(x: 600, y: 130.5),
        CGPoint(x: 72, y: 394.5),
      ],
      [
        CGPoint(x: 600, y: 148.5), CGPoint(x: 1128, y: 412.5), CGPoint(x: 1128, y: 394.5),
        CGPoint(x: 600, y: 130.5),
      ],
    ].enumerated() {
      let path = CGMutablePath()
      path.addLines(between: corners)
      path.closeSubpath()
      let edge = SKShapeNode(path: path)
      edge.name = "earth-edge-\(index)"
      edge.strokeColor = .clear
      edge.fillColor = index == 0 ? .init(white: 0.55, alpha: 1) : .init(white: 0.4, alpha: 1)
      edge.zPosition = -1
      edges.append(edge)
      addChild(edge)
    }
    let warp = SKWarpGeometryGrid(
      columns: 1, rows: 1,
      sourcePositions: [
        SIMD2<Float>(0, 0), SIMD2<Float>(1, 0), SIMD2<Float>(0, 1), SIMD2<Float>(1, 1),
      ],
      destinationPositions: [
        SIMD2<Float>(0, 0.5), SIMD2<Float>(0.5, 0), SIMD2<Float>(0.5, 1), SIMD2<Float>(1, 0.5),
      ])
    for column in 0..<16 {
      for row in 0..<16 {
        let tile = SKSpriteNode()
        tile.name = "tile-\(column)-\(row)"
        tile.position = IsometricLayout.point(column: CGFloat(column) / 2, row: CGFloat(row) / 2)
        tile.size = CGSize(width: 66.2, height: 33.1)
        tile.warpGeometry = warp
        tiles.append(tile)
        addChild(tile)
      }
    }
  }
  required init?(coder: NSCoder) { fatalError("Not used") }
  func update(state: GameState, texture: (String) -> SKTexture?) {
    let woodshed = Construction.stage(.woodshed, state: state) != .empty
    let cellar = Construction.stage(.cellar, state: state) != .empty
    let next = "\(state.season)-\(woodshed)-\(cellar)"
    guard next != signature else { return }
    signature = next
    for edge in edges { edge.fillTexture = texture("terrain-earth") }
    for column in 0..<16 {
      for row in 0..<16 {
        let tile = tiles[column * 16 + row]
        let path = row == 7 || column == 8
        let field = (8...11).contains(column) && (9...12).contains(row)
        let construction =
          woodshed && (1...5).contains(column) && (9...11).contains(row)
          || cellar && (9...12).contains(column) && (0...3).contains(row)
        let winter = state.season == 3
        let earth = path || field || construction
        let material = winter && !path ? "terrain-snow" : earth ? "terrain-earth" : "terrain-grass"
        let key = "\(material)-\(column%4)-\(row%4)"
        if surfaces[key] == nil, let base = texture(material) {
          surfaces[key] = SKTexture(
            rect: CGRect(
              x: CGFloat(column % 4) / 4, y: CGFloat(3 - row % 4) / 4, width: 0.25, height: 0.25),
            in: base)
        }
        tile.texture = surfaces[key]
        tile.color =
          winter
          ? NSColor(red: 0.83, green: 0.87, blue: 0.9, alpha: 1)
          : earth
            ? NSColor(red: 0.38, green: 0.29, blue: 0.17, alpha: 1)
            : state.season == 2
              ? NSColor(red: 0.63, green: 0.51, blue: 0.25, alpha: 1)
              : NSColor(red: 0.38, green: 0.47, blue: 0.20, alpha: 1)
        tile.colorBlendFactor = winter && path ? 0.5 : earth ? 0.12 : state.season == 2 ? 0.3 : 0.08
      }
    }
  }
}
