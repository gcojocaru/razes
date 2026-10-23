import CoreGraphics
import RazesCore

enum IsometricLayout {
  static func point(column: CGFloat, row: CGFloat, rotation: Int = 0) -> CGPoint {
    let c: CGFloat
    let r: CGFloat
    switch (rotation % 4 + 4) % 4 {
    case 1:
      c = 15 - row
      r = column
    case 2:
      c = 15 - column
      r = 15 - row
    case 3:
      c = row
      r = 15 - column
    default:
      c = column
      r = row
    }
    return CGPoint(x: 600 + (c - r) * 66, y: 660 - (c + r) * 33)
  }
  static func grid(at point: CGPoint, rotation: Int = 0) -> CGPoint {
    let horizontal = (point.x - 600) / 66
    let vertical = (660 - point.y) / 33
    let c = (horizontal + vertical) / 2
    let r = (vertical - horizontal) / 2
    switch (rotation % 4 + 4) % 4 {
    case 1: return CGPoint(x: r, y: 15 - c)
    case 2: return CGPoint(x: 15 - c, y: 15 - r)
    case 3: return CGPoint(x: 15 - r, y: c)
    default: return CGPoint(x: c, y: r)
    }
  }
  static func center(_ point: GridPosition, width: Int, height: Int, rotation: Int = 0) -> CGPoint {
    self.point(
      column: CGFloat(point.x) + CGFloat(width - 1) / 2,
      row: CGFloat(point.y) + CGFloat(height - 1) / 2, rotation: rotation)
  }
  static func center(_ point: GridPosition, kind: StructureKind, facing: Int = 0, rotation: Int = 0)
    -> CGPoint
  {
    let size = Settlement.footprint(kind, facing: facing)
    return center(point, width: size.width, height: size.height, rotation: rotation)
  }
  static let house = center(Settlement.house, width: 3, height: 3)
  static let field = center(Settlement.farm, width: 3, height: 3)
  static let stores = point(column: 9, row: 8)
  static let woodshed = center(GridPosition(x: 3, y: 8), kind: .building(.woodshed))
  static let cellar = center(GridPosition(x: 10, y: 5), kind: .building(.cellar))
  static func plot(_ id: BuildingID, state: GameState? = nil) -> CGPoint {
    if let state, let position = Settlement.position(for: id, in: state.layout) {
      return center(position, kind: .building(id))
    }
    return id == .woodshed ? woodshed : cellar
  }
  static func worker(_ task: TaskID, state: GameState) -> CGPoint {
    let base: CGPoint
    switch task {
    case .plant, .tend, .harvest: base = CGPoint(x: field.x + 30, y: field.y - 45)
    case .repair: base = CGPoint(x: house.x + 45, y: house.y - 4)
    case .paid: base = point(column: 12, row: 8)
    case .supplies: base = stores
    case .gatherWood: base = point(column: 1, row: 12)
    case .gatherStone: base = point(column: 14, row: 3)
    case .buildWoodshed:
      let p = plot(.woodshed, state: state)
      base = CGPoint(x: p.x + 65, y: p.y - 20)
    case .buildCellar:
      let p = plot(.cellar, state: state)
      base = CGPoint(x: p.x + 55, y: p.y - 20)
    case .rest: base = CGPoint(x: house.x + 30, y: house.y - 30)
    }
    return base
  }
}
