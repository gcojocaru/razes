import AppKit
import RazesCore
import SpriteKit

@MainActor final class TerrainLayer: SKNode {
  private var tiles: [SKSpriteNode] = []
  private struct Signature: Equatable {
    var season: Int
    var rotation: Int
    var construction: [BuildingPlacement]
    var farm: Bool
  }
  private var signature: Signature?
  private var surfaces: [String: SKTexture] = [:]
  private var edges: [SKShapeNode] = []
  override init() {
    super.init()
    name = "isometric-ground"
    for (index, corners) in [
      [
        CGPoint(x: -456, y: 165), CGPoint(x: 600, y: -363), CGPoint(x: 600, y: -381),
        CGPoint(x: -456, y: 147),
      ],
      [
        CGPoint(x: 600, y: -363), CGPoint(x: 1656, y: 165), CGPoint(x: 1656, y: 147),
        CGPoint(x: 600, y: -381),
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
    for column in 0..<32 {
      for row in 0..<32 {
        let tile = SKSpriteNode()
        tile.name = "tile-\(column)-\(row)"
        tile.position = IsometricLayout.point(
          column: (CGFloat(column) - 0.5) / 2, row: (CGFloat(row) - 0.5) / 2)
        tile.size = CGSize(width: 66.2, height: 33.1)
        tile.warpGeometry = warp
        tiles.append(tile)
        addChild(tile)
      }
    }
  }
  required init?(coder: NSCoder) { fatalError("Not used") }
  func update(state: GameState, texture: (String) -> SKTexture?) {
    let next = Signature(
      season: state.displaySeason, rotation: state.layout.viewRotation,
      construction: state.layout.buildings.filter {
        Construction.stage($0.id, state: state) != .empty
      }, farm: state.planted || state.assignments.values.contains(.plant))
    guard next != signature else { return }
    signature = next
    for edge in edges { edge.fillTexture = texture("terrain-earth") }
    for column in 0..<32 {
      for row in 0..<32 {
        let tile = tiles[column * 32 + row]
        tile.position = IsometricLayout.point(
          column: (CGFloat(column) - 0.5) / 2, row: (CGFloat(row) - 0.5) / 2,
          rotation: state.layout.viewRotation)
        let path =
          row == 18 && column >= 4 && column <= 29 || column == 18 && row >= 12 && row <= 29
        let logical = GridPosition(x: column / 2, y: row / 2)
        let field = next.farm && (5...7).contains(logical.x) && (10...12).contains(logical.y)
        let construction = next.construction.contains { building in
          logical.x >= building.position.x && logical.x < building.position.x + 2
            && logical.y >= building.position.y && logical.y < building.position.y + 2
        }
        let winter = state.displaySeason == 3
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
            : state.displaySeason == 2
              ? NSColor(red: 0.63, green: 0.51, blue: 0.25, alpha: 1)
              : NSColor(red: 0.38, green: 0.47, blue: 0.20, alpha: 1)
        tile.colorBlendFactor =
          winter && path ? 0.5 : earth ? 0.12 : state.displaySeason == 2 ? 0.3 : 0.08
      }
    }
  }
}
