import Foundation

public struct GridPosition: Codable, Equatable, Hashable, Sendable {
  public var x, y: Int
  public init(x: Int, y: Int) {
    self.x = x
    self.y = y
  }
}
public enum SceneryKind: String, Codable, CaseIterable, Sendable { case barn, well, stores, fence }
public enum StructureKind: Equatable, Sendable {
  case building(BuildingID)
  case scenery(SceneryKind)
}
public struct BuildingPlacement: Codable, Equatable, Sendable {
  public var id: BuildingID
  public var position: GridPosition
  public init(id: BuildingID, position: GridPosition) {
    self.id = id
    self.position = position
  }
}
public struct SceneryPlacement: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var kind: SceneryKind
  public var position: GridPosition
  public init(id: String = UUID().uuidString, kind: SceneryKind, position: GridPosition) {
    self.id = id
    self.kind = kind
    self.position = position
  }
}
public struct SettlementLayout: Codable, Equatable, Sendable {
  public var buildings: [BuildingPlacement] = []
  public var scenery: [SceneryPlacement] = []
  public init() {}
}
public enum Settlement {
  public static let size = 16
  public static let house = GridPosition(x: 6, y: 6), farm = GridPosition(x: 5, y: 10)
  public static func footprint(_ kind: StructureKind) -> (width: Int, height: Int) {
    switch kind {
    case .building, .scenery(.barn): (2, 2)
    case .scenery(.fence): (2, 1)
    case .scenery(.well), .scenery(.stores): (1, 1)
    }
  }
  public static func position(for id: BuildingID, in layout: SettlementLayout) -> GridPosition? {
    layout.buildings.first { $0.id == id }?.position
  }
  private static func cells(_ point: GridPosition, _ size: (width: Int, height: Int)) -> Set<
    GridPosition
  > {
    Set(
      (0..<size.width).flatMap { x in
        (0..<size.height).map { y in GridPosition(x: point.x + x, y: point.y + y) }
      })
  }
  public static func problem(
    _ kind: StructureKind, at point: GridPosition, layout: SettlementLayout,
    ignoringScenery: String? = nil
  ) -> String? {
    let footprint = footprint(kind)
    guard point.x >= 0, point.y >= 0, point.x <= size - footprint.width,
      point.y <= size - footprint.height
    else { return "Keep the whole footprint inside the playing area." }
    let proposed = cells(point, footprint)
    var occupied = cells(house, (3, 3)).union(cells(farm, (3, 3)))
    for building in layout.buildings where kind != .building(building.id) {
      occupied.formUnion(cells(building.position, self.footprint(.building(building.id))))
    }
    for scenery in layout.scenery where scenery.id != ignoringScenery {
      occupied.formUnion(cells(scenery.position, self.footprint(.scenery(scenery.kind))))
    }
    return proposed.isDisjoint(with: occupied)
      ? nil : "This space is occupied or reserved for the house or farmland."
  }
  public static func firstAvailable(_ id: BuildingID, in layout: SettlementLayout) -> GridPosition?
  {
    let preferred = id == .woodshed ? GridPosition(x: 3, y: 8) : GridPosition(x: 10, y: 5)
    if problem(.building(id), at: preferred, layout: layout) == nil { return preferred }
    for y in 0..<size {
      for x in 0..<size {
        let point = GridPosition(x: x, y: y)
        if problem(.building(id), at: point, layout: layout) == nil { return point }
      }
    }
    return nil
  }
  public static func legacyLayout(for state: GameState) -> SettlementLayout {
    var layout = SettlementLayout()
    layout.scenery = [
      .init(id: "legacy-barn", kind: .barn, position: .init(x: 3, y: 5)),
      .init(id: "legacy-well", kind: .well, position: .init(x: 8, y: 9)),
      .init(id: "legacy-stores", kind: .stores, position: .init(x: 9, y: 8)),
      .init(id: "legacy-fence", kind: .fence, position: .init(x: 7, y: 14)),
    ]
    for id in BuildingID.allCases where Construction.stage(id, state: state) != .empty {
      if let position = firstAvailable(id, in: layout) {
        layout.buildings.append(.init(id: id, position: position))
      }
    }
    return layout
  }
  public static func validate(_ state: GameState) throws {
    let layout = state.layout
    guard layout.buildings.count <= BuildingID.allCases.count,
      Set(layout.buildings.map(\.id)).count == layout.buildings.count,
      layout.scenery.count <= 128, Set(layout.scenery.map(\.id)).count == layout.scenery.count
    else { throw GameError("This settlement contains duplicate or excessive structures.") }
    for (point, footprint) in layout.buildings.map({
      ($0.position, self.footprint(.building($0.id)))
    }) + layout.scenery.map({ ($0.position, self.footprint(.scenery($0.kind))) }) {
      guard point.x >= 0, point.y >= 0, point.x <= size - footprint.width,
        point.y <= size - footprint.height
      else { throw GameError("A structure lies outside the playing area.") }
    }
    for building in layout.buildings {
      if let problem = problem(.building(building.id), at: building.position, layout: layout) {
        throw GameError(problem)
      }
    }
    for scenery in layout.scenery {
      guard !scenery.id.isEmpty, scenery.id.utf8.count <= 64 else {
        throw GameError("Invalid scenery identity.")
      }
      if let problem = problem(
        .scenery(scenery.kind), at: scenery.position, layout: layout, ignoringScenery: scenery.id)
      {
        throw GameError(problem)
      }
    }
    for id in BuildingID.allCases where Construction.stage(id, state: state) != .empty {
      guard position(for: id, in: layout) != nil else {
        throw GameError("A construction is missing its position.")
      }
    }
  }
}
