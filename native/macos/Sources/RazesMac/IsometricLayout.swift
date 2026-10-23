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
  static let house = point(column: 3.3, row: 2.5)
  static let barn = point(column: 0.8, row: 3.4)
  static let field = point(column: 5, row: 5.2)
  static let well = point(column: 3.8, row: 3.7)
  static let stores = point(column: 4.2, row: 2.6)
  static let woodshed = point(column: 1.5, row: 5)
  static let cellar = point(column: 5.2, row: 0.8)
  static let visitor = point(column: 5, row: 2.7)
  static let fence = point(column: 6.5, row: 5.5)
  static func plot(_ id: BuildingID) -> CGPoint { id == .woodshed ? woodshed : cellar }
  static func worker(_ task: TaskID) -> CGPoint {
    switch task {
    case .plant, .tend, .harvest: point(column: 5.4, row: 5.2)
    case .repair: point(column: 3.8, row: 2.1)
    case .paid: point(column: 6.7, row: 2)
    case .help: point(column: 5.5, row: 2.1)
    case .supplies: point(column: 4.8, row: 3.1)
    case .buildWoodshed: point(column: 2.2, row: 5)
    case .buildCellar: point(column: 5.6, row: 1.5)
    case .rest: point(column: 4.1, row: 2.7)
    }
  }
}
