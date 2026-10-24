import Foundation

public enum BuildingID: String, Codable, CaseIterable, Sendable {
  case woodshed, cellar, barn, well, granary, workshop, bakery, smithy, stable, apiary, storehouse
}
public struct BuildingRecord: Codable, Equatable, Sendable {
  public var id: BuildingID
  public var completedSeason: Int
  public var debugPlaced: Bool?
  public var legacyAssignment: Bool
  public var level: Int
  public var condition: Double
  public init(
    id: BuildingID, completedSeason: Int, debugPlaced: Bool? = nil,
    legacyAssignment: Bool = true, level: Int = 1, condition: Double = 100
  ) {
    self.id = id
    self.completedSeason = completedSeason
    self.debugPlaced = debugPlaced
    self.legacyAssignment = legacyAssignment
    self.level = level
    self.condition = condition
  }
}
public struct BuildingDefinition: Sendable, Identifiable {
  public let id: BuildingID
  public let title: String
  public var task: TaskID? = nil
  public let cost: Int
  public let benefit: String
  public let food, coins: Int
  public func yieldText(level: Int) -> String {
    if id == .storehouse { return "+\(40 * level) shared storage" }
    return [food > 0 ? "\(food * level) food" : nil, coins > 0 ? "\(coins * level) Galbeni" : nil]
      .compactMap { $0 }.joined(separator: " + ") + " / season"
  }
}
public enum BuildingStage: String, Sendable { case empty, planned, complete }
public struct ConstructionRequirements: Equatable, Sendable {
  public let houseLevel, buildingLevel: Int
  public let prerequisite: BuildingID?
  public let coins, freeCoins: Int
  public let materials, freeMaterials: MaterialStock
  public let locks, shortages: [String]
  public var problems: [String] { locks + shortages }
  public var isMet: Bool { problems.isEmpty }

  init(
    houseLevel: Int = 0, buildingLevel: Int = 0, prerequisite: BuildingID? = nil,
    coins: Int, materials: MaterialStock, state: GameState, locks: [String] = []
  ) {
    self.houseLevel = houseLevel
    self.buildingLevel = buildingLevel
    self.prerequisite = prerequisite
    self.coins = coins
    self.materials = materials
    self.freeCoins = Construction.freeCoins(state)
    self.freeMaterials = Materials.available(state)
    self.locks = locks
    var shortages: [String] = []
    if freeCoins < coins {
      shortages.append(
        "Needs \(coins) free Galbeni; \(max(0, freeCoins)) available, \(coins - freeCoins) missing."
      )
    }
    for id in MaterialID.allCases where freeMaterials[id] < materials[id] {
      shortages.append(
        "Needs \(materials[id]) free \(id.rawValue); \(max(0, freeMaterials[id])) available, \(materials[id] - freeMaterials[id]) missing."
      )
    }
    self.shortages = shortages
  }
}
public enum Construction {
  public static let definitions: [BuildingDefinition] = [
    .init(
      id: .storehouse, title: "Storehouse", cost: 4,
      benefit:
        "Shared room for wood, stone and crafted supplies. Adds 40 storage per completed level.",
      food: 0, coins: 0),
    .init(
      id: .woodshed, title: "Woodshed", task: .buildWoodshed, cost: 3,
      benefit:
        "Save 1 food at winter month end and reduce winter shelter wear to 6. Firewood sales begin the following season.",
      food: 0, coins: 1),
    .init(
      id: .cellar, title: "Root cellar", task: .buildCellar, cost: 4,
      benefit:
        "Buy provisions brings 10 food for 4 Galbeni once completed. Preserved vegetables arrive from the following season.",
      food: 2, coins: 0),
    .init(
      id: .barn, title: "Barn", cost: 5,
      benefit: "Livestock and dairy supply food and a small income.", food: 1, coins: 1),
    .init(
      id: .well, title: "Well", cost: 3, benefit: "Clean water supports the kitchen garden.",
      food: 1, coins: 0),
    .init(
      id: .granary, title: "Granary", cost: 6,
      benefit: "Dry grain stores feed the household and supply market sales.", food: 2, coins: 1),
    .init(
      id: .workshop, title: "Workshop", cost: 5,
      benefit: "Carpentry and everyday tools earn a steady income.", food: 0, coins: 2),
    .init(
      id: .bakery, title: "Bakery", cost: 7, benefit: "Bread for the table and the village market.",
      food: 3, coins: 1),
    .init(
      id: .smithy, title: "Smithy", cost: 8,
      benefit:
        "Craft each plank from 1 wood. Forged tools bring Galbeni from the following season.",
      food: 0, coins: 3),
    .init(
      id: .stable, title: "Stable", cost: 9, benefit: "Horses and transport bring trade income.",
      food: 1, coins: 2),
    .init(
      id: .apiary, title: "Apiary", cost: 4,
      benefit: "Honey and wax provide food and market goods.", food: 2, coins: 1),
  ]
  public static func definition(_ id: BuildingID) -> BuildingDefinition {
    definitions.first { $0.id == id }!
  }
  public static func building(for task: TaskID) -> BuildingID? {
    definitions.first { $0.task == task }?.id
  }
  public static func stage(_ id: BuildingID, state: GameState) -> BuildingStage {
    if let record = state.buildings.first(where: { $0.id == id }) {
      return record.level == 0 ? .planned : .complete
    }
    return definition(id).task.map { state.assignments.values.contains($0) } == true
      ? .planned : .empty
  }
  public static func active(_ id: BuildingID, state: GameState) -> Bool {
    state.buildings.contains {
      $0.id == id && $0.level > 0 && $0.condition > 0 && $0.completedSeason < state.turn
    }
  }
  public static func operationalLevel(_ id: BuildingID, state: GameState) -> Int {
    state.buildings.first { $0.id == id && $0.level > 0 && $0.condition > 0 }?.level ?? 0
  }
  private static func minimumLevel(_ id: BuildingID) -> Int {
    switch id {
    case .woodshed, .cellar, .well, .workshop: 1
    case .barn, .granary, .apiary, .storehouse: 2
    case .bakery, .smithy, .stable: 3
    }
  }
  private static func prerequisite(_ id: BuildingID) -> BuildingID? {
    switch id {
    case .barn, .apiary: .well
    case .granary: .cellar
    case .storehouse, .smithy: .workshop
    case .bakery: .granary
    case .stable: .barn
    default: nil
    }
  }
  public static func unlockProblems(
    _ id: BuildingID, state: GameState, level: Int = 1
  ) -> [String] {
    let required = max(minimumLevel(id), level)
    var problems: [String] = []
    if state.houseLevel < required { problems.append("Requires House level \(required).") }
    if state.character.level(.building) < required {
      problems.append("Requires Building skill level \(required).")
    }
    if let prerequisite = prerequisite(id),
      !state.buildings.contains(where: { $0.id == prerequisite && $0.level > 0 })
    {
      problems.append("Requires completed \(definition(prerequisite).title).")
    }
    return problems
  }
  public static func requirements(
    _ id: BuildingID, state: GameState, level: Int = 1
  ) -> ConstructionRequirements {
    let required = max(minimumLevel(id), level)
    var locks = unlockProblems(id, state: state, level: level)
    if !(1...5).contains(level) {
      locks.append("Building levels range from 1 to 5.")
    } else if level == 1 {
      if stage(id, state: state) != .empty {
        locks.append("This building already exists or has a weekly builder.")
      }
    } else if !state.buildings.contains(where: { $0.id == id && $0.level == level - 1 }) {
      locks.append("An upgrade to level \(level) needs a completed level \(level - 1) building.")
    }
    let costLevel = min(5, max(1, level))
    return .init(
      houseLevel: required, buildingLevel: required, prerequisite: prerequisite(id),
      coins: definition(id).cost * costLevel, materials: materialCost(id).scaled(costLevel),
      state: state, locks: locks)
  }
  public static func repairRequirements(
    _ id: BuildingID, state: GameState
  ) -> ConstructionRequirements {
    let repairable = state.buildings.contains { $0.id == id && $0.level > 0 && $0.condition < 100 }
    return .init(
      coins: repairCost(id), materials: repairMaterials(id), state: state,
      locks: repairable ? [] : ["Repairs need a completed, worn building."])
  }
  public static func practicalBenefit(_ id: BuildingID, level: Int) -> String {
    switch id {
    case .woodshed: "Save 1 food at winter month end; winter shelter wear becomes 6."
    case .cellar: "Buy provisions yields 10 food instead of 7."
    case .well: "+\(2 * level) food per harvest."
    case .granary: "+\(level) grain seeds per harvest."
    case .bakery: "+\(level) food each time you Buy provisions; stacks with the Root cellar."
    case .stable: "+1 Galbeni for each week of wages."
    case .smithy: "Craft 1 plank from 1 wood instead of 2 wood."
    case .workshop: "Craft planks immediately here using free wood; no worker or experience needed."
    case .storehouse: "+\(40 * level) shared storage, including at zero condition."
    case .barn, .apiary: "Seasonal food and Galbeni begin the following season."
    }
  }
  public static func unavailable(_ id: BuildingID, state: GameState) -> String? {
    if state.buildings.contains(where: { $0.id == id }) {
      return "Already completed or under construction."
    }
    if state.phase != .work {
      return "Continue to the next week before assigning work."
    }
    if state.season == 3 {
      return "Worker construction is unavailable in winter. Use the building palette."
    }
    return nil
  }
  public static func upgradeCost(_ record: BuildingRecord) -> Int {
    definition(record.id).cost * (record.level + 1)
  }
  public static func repairCost(_ id: BuildingID) -> Int { (definition(id).cost + 1) / 2 }
  public static func materialCost(_ id: BuildingID) -> MaterialStock {
    switch id {
    case .woodshed: .init(wood: 4)
    case .cellar: .init(wood: 2, stone: 4)
    case .barn: .init(wood: 6, stone: 2)
    case .well: .init(wood: 1, stone: 5)
    case .workshop: .init(wood: 4, stone: 2)
    case .granary: .init(wood: 4, stone: 2, planks: 2)
    case .bakery: .init(wood: 2, stone: 4, planks: 2)
    case .smithy: .init(wood: 2, stone: 6, planks: 2)
    case .stable: .init(wood: 4, stone: 2, planks: 4)
    case .apiary: .init(wood: 3, planks: 1)
    case .storehouse: .init(wood: 6, stone: 2, planks: 2)
    }
  }
  public static func repairMaterials(_ id: BuildingID) -> MaterialStock {
    switch id {
    case .cellar, .well, .bakery, .smithy: .init(stone: 1)
    default: .init(wood: 1)
    }
  }
  public static func priceText(_ id: BuildingID, level: Int = 1) -> String {
    "\(definition(id).cost * level) Galbeni · \(materialCost(id).scaled(level).text)"
  }
}
