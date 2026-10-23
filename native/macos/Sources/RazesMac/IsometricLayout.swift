import CoreGraphics
import RazesCore

enum IsometricLayout {
  static func point(column: CGFloat, row: CGFloat) -> CGPoint {
    CGPoint(x: 600 + (column - row) * 66, y: 660 - (column + row) * 33)
  }
  static func grid(at point: CGPoint) -> CGPoint {
    let horizontal = (point.x - 600) / 66
    let vertical = (660 - point.y) / 33
    return CGPoint(x: (horizontal + vertical) / 2, y: (vertical - horizontal) / 2)
  }
  static func center(_ point: GridPosition, width: Int, height: Int) -> CGPoint {
    self.point(
      column: CGFloat(point.x) + CGFloat(width - 1) / 2,
      row: CGFloat(point.y) + CGFloat(height - 1) / 2)
  }
  static func center(_ point: GridPosition, kind: StructureKind) -> CGPoint {
    let size = Settlement.footprint(kind)
    return center(point, width: size.width, height: size.height)
  }
  static let house = center(Settlement.house, width: 3, height: 3)
  static let field = center(Settlement.farm, width: 3, height: 3)
  static let stores = point(column: 9, row: 8)
  static let visitor = point(column: 9, row: 7)
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
    case .help: base = visitor
    case .supplies: base = stores
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
