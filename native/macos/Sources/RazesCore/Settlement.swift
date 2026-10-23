import Foundation

public struct GridPosition: Codable, Equatable, Hashable, Sendable {
  public var x, y: Int
  public init(x: Int, y: Int) {
    self.x = x
    self.y = y
  }
}
public enum SceneryKind: String, Codable, CaseIterable, Sendable { case barn, well, stores, fence }
public enum InfrastructureKind: String, CaseIterable, Sendable {
  case pavement, dirtPath, farmland, fence, wattleFence, erase
  public var isFence: Bool { self == .fence || self == .wattleFence }
  public var title: String {
    switch self {
    case .pavement: "Stone pavement"
    case .dirtPath: "Dirt path"
    case .farmland: "Farmland"
    case .fence: "Rail fence"
    case .wattleFence: "Wattle fence"
    case .erase: "Erase"
    }
  }
}
public enum FenceStyle: String, Codable, Sendable { case rail, wattle }
public enum StructureKind: Equatable, Sendable {
  case building(BuildingID)
  case scenery(SceneryKind)
  case infrastructure(InfrastructureKind)
}
public struct BuildingPlacement: Codable, Equatable, Sendable {
  public var id: BuildingID
  public var position: GridPosition
  public var facing: Int
  public init(id: BuildingID, position: GridPosition, facing: Int = 0) {
    self.id = id
    self.position = position
    self.facing = facing
  }
}
public struct SceneryPlacement: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var kind: SceneryKind
  public var position: GridPosition
  public var facing: Int
  public init(
    id: String = UUID().uuidString, kind: SceneryKind, position: GridPosition, facing: Int = 0
  ) {
    self.id = id
    self.kind = kind
    self.position = position
    self.facing = facing
  }
}
public struct FenceSegment: Codable, Equatable, Hashable, Sendable {
  public var position: GridPosition
  public var facing: Int
  public var style: FenceStyle
  public init(position: GridPosition, facing: Int = 0, style: FenceStyle = .rail) {
    self.position = position
    self.facing = facing
    self.style = style
  }
  public var edgeKey: String {
    facing % 2 == 0
      ? "h:\(position.x):\(position.y + (facing == 2 ? 1 : 0))"
      : "v:\(position.x + (facing == 1 ? 1 : 0)):\(position.y)"
  }
}
public struct SettlementLayout: Codable, Equatable, Sendable {
  public var buildings: [BuildingPlacement] = []
  public var scenery: [SceneryPlacement] = []
  public var pavement: [GridPosition] = []
  public var dirtPaths: [GridPosition] = []
  public var farmland: [GridPosition] = Settlement.startingFarmland
  public var fences: [FenceSegment] = []
  public var viewRotation = 0
  public init() {}
  private enum CodingKeys: String, CodingKey {
    case buildings, scenery, pavement, dirtPaths, farmland, fences, viewRotation
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    buildings = try c.decode([BuildingPlacement].self, forKey: .buildings)
    scenery = try c.decode([SceneryPlacement].self, forKey: .scenery)
    pavement = try c.decode([GridPosition].self, forKey: .pavement)
    dirtPaths = try c.decode([GridPosition].self, forKey: .dirtPaths)
    // Missing means an older save; an explicitly empty field must stay empty.
    farmland =
      try c.decodeIfPresent([GridPosition].self, forKey: .farmland) ?? Settlement.startingFarmland
    fences = try c.decode([FenceSegment].self, forKey: .fences)
    viewRotation = try c.decode(Int.self, forKey: .viewRotation)
  }
}
public enum Settlement {
  public static let size = 16
  public static let startingFarmland = (5...7).flatMap { x in
    (10...12).map { y in GridPosition(x: x, y: y) }
  }
  public static func farmlandEditingProblem(_ state: GameState) -> String? {
    if state.planted && !state.harvested && state.season < 3 {
      return "Harvest the crop before changing farmland."
    }
    if state.phase == .work
      && state.assignments.values.contains(where: {
        [TaskID.plant, .tend, .harvest].contains($0)
      })
    {
      return "Cancel the farming assignment before changing farmland."
    }
    return nil
  }
  public static func infrastructureProblem(
    _ kind: InfrastructureKind, at point: GridPosition, state: GameState, facing: Int = 0
  ) -> String? {
    if kind == .farmland || (kind == .erase && state.layout.farmland.contains(point)),
      let problem = farmlandEditingProblem(state)
    {
      return problem
    }
    return problem(.infrastructure(kind), at: point, layout: state.layout, facing: facing)
  }
  public static let house = GridPosition(x: 6, y: 6), farm = GridPosition(x: 5, y: 10)
  public static func footprint(_ kind: StructureKind, facing: Int = 0) -> (width: Int, height: Int)
  {
    switch kind {
    case .building, .scenery(.barn): (2, 2)
    case .scenery(.fence): facing % 2 == 0 ? (2, 1) : (1, 2)
    case .scenery(.well), .scenery(.stores), .infrastructure: (1, 1)
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
    facing: Int = 0, ignoringScenery: String? = nil, checkDuplicate: Bool = true
  ) -> String? {
    guard (0...3).contains(facing) else { return "Choose one of four directions." }
    let footprint = footprint(kind, facing: facing)
    guard point.x >= 0, point.y >= 0, point.x <= size - footprint.width,
      point.y <= size - footprint.height
    else { return "Keep the whole footprint inside the playing area." }
    if kind == .infrastructure(.erase) { return nil }
    if checkDuplicate {
      if kind == .infrastructure(.pavement) || kind == .infrastructure(.dirtPath),
        layout.pavement.contains(point) || layout.dirtPaths.contains(point)
      {
        return "A path surface is already laid here."
      }
      if case .infrastructure(let material) = kind, material.isFence,
        layout.fences.contains(where: {
          $0.edgeKey == FenceSegment(position: point, facing: facing).edgeKey
        })
      {
        return "A fence already occupies this edge."
      }
    }
    let proposed = cells(point, footprint)
    var occupied = cells(house, (3, 3))
    occupied.formUnion(
      layout.farmland.filter {
        !(kind == .infrastructure(.farmland) && !checkDuplicate && $0 == point)
      })
    for building in layout.buildings where kind != .building(building.id) {
      occupied.formUnion(
        cells(building.position, self.footprint(.building(building.id), facing: building.facing)))
    }
    for scenery in layout.scenery where scenery.id != ignoringScenery {
      occupied.formUnion(
        cells(scenery.position, self.footprint(.scenery(scenery.kind), facing: scenery.facing)))
    }
    if case .infrastructure(let material) = kind, material != .farmland {
    } else {
      occupied.formUnion(layout.pavement)
      occupied.formUnion(layout.dirtPaths)
      occupied.formUnion(layout.fences.map(\.position))
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
    let surfaces = layout.pavement + layout.dirtPaths + layout.farmland
    guard layout.buildings.count <= BuildingID.allCases.count,
      Set(layout.buildings.map(\.id)).count == layout.buildings.count,
      layout.scenery.count <= 128, Set(layout.scenery.map(\.id)).count == layout.scenery.count,
      surfaces.count <= 256, Set(surfaces).count == surfaces.count,
      layout.fences.count <= 1024, (0...3).contains(layout.viewRotation),
      (layout.buildings.map(\.facing) + layout.scenery.map(\.facing) + layout.fences.map(\.facing))
        .allSatisfy({ (0...3).contains($0) })
    else {
      throw GameError(
        "This settlement contains invalid directions, duplicate or excessive structures.")
    }
    let footprints =
      layout.buildings.map { ($0.position, self.footprint(.building($0.id), facing: $0.facing)) }
      + layout.scenery.map { ($0.position, self.footprint(.scenery($0.kind), facing: $0.facing)) }
      + (surfaces + layout.fences.map(\.position)).map { ($0, (width: 1, height: 1)) }
    for (point, footprint) in footprints {
      guard point.x >= 0, point.y >= 0, point.x <= size - footprint.width,
        point.y <= size - footprint.height
      else { throw GameError("A structure lies outside the playing area.") }
    }
    guard Set(layout.fences.map(\.edgeKey)).count == layout.fences.count else {
      throw GameError("Duplicate fence edge.")
    }
    for building in layout.buildings {
      if let problem = problem(
        .building(building.id), at: building.position, layout: layout, facing: building.facing)
      {
        throw GameError(problem)
      }
    }
    for scenery in layout.scenery {
      guard !scenery.id.isEmpty, scenery.id.utf8.count <= 64 else {
        throw GameError("Invalid scenery identity.")
      }
      if let problem = problem(
        .scenery(scenery.kind), at: scenery.position, layout: layout, facing: scenery.facing,
        ignoringScenery: scenery.id)
      {
        throw GameError(problem)
      }
    }
    for (point, kind, facing) in layout.pavement.map({ ($0, InfrastructureKind.pavement, 0) })
      + layout.dirtPaths.map({ ($0, InfrastructureKind.dirtPath, 0) })
      + layout.farmland.map({ ($0, InfrastructureKind.farmland, 0) })
      + layout.fences.map({ ($0.position, InfrastructureKind.fence, $0.facing) })
    {
      if let problem = problem(
        .infrastructure(kind), at: point, layout: layout, facing: facing, checkDuplicate: false)
      {
        throw GameError(problem)
      }
    }
    if state.planted && !state.harvested && state.season < 3 && layout.farmland.isEmpty {
      throw GameError("A growing crop is missing its farmland.")
    }
    for id in BuildingID.allCases where Construction.stage(id, state: state) != .empty {
      guard position(for: id, in: layout) != nil else {
        throw GameError("A construction is missing its position.")
      }
    }
  }
}
