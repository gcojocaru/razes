import Foundation

public enum BuildingID: String, Codable, CaseIterable, Sendable {
  case woodshed, cellar, barn, well, granary, workshop, bakery, smithy, stable, apiary
}
public enum BuildingWorkKind: String, Codable, Sendable { case build, upgrade, repair }
public struct BuildingWork: Codable, Equatable, Sendable {
  public var kind: BuildingWorkKind
  public var remaining, duration: Double
  public init(kind: BuildingWorkKind, duration: Double) {
    self.kind = kind
    self.remaining = duration
    self.duration = duration
  }
}
public struct BuildingRecord: Codable, Equatable, Sendable {
  public var id: BuildingID
  public var completedSeason: Int
  public var debugPlaced: Bool?
  public var realtime: Bool
  public var level: Int
  public var condition, production: Double
  public var work: BuildingWork?
  public init(
    id: BuildingID, completedSeason: Int, debugPlaced: Bool? = nil,
    realtime: Bool = false, level: Int = 1, condition: Double = 100
  ) {
    self.id = id
    self.completedSeason = completedSeason
    self.debugPlaced = debugPlaced
    self.realtime = realtime
    self.level = level
    self.condition = condition
    self.production = 0
  }
}
public struct BuildingDefinition: Sendable, Identifiable {
  public let id: BuildingID
  public let title: String
  public var task: TaskID? = nil
  public let cost: Int
  public let benefit: String
  public let food, coins: Int
  public var buildTime: Double { Double(cost * 10) }
  public func yieldText(level: Int) -> String {
    [food > 0 ? "\(food * level) food" : nil, coins > 0 ? "\(coins * level) coins" : nil]
      .compactMap { $0 }.joined(separator: " + ") + " / minute"
  }
}
public enum BuildingStage: String, Sendable { case empty, planned, complete }
public enum Construction {
  public static let definitions: [BuildingDefinition] = [
    .init(
      id: .woodshed, title: "Woodshed", task: .buildWoodshed, cost: 3,
      benefit:
        "Firewood sales. From next season: winter base food use 6 and shelter wear 6; cold shelter still needs 3 extra food.",
      food: 0, coins: 1),
    .init(
      id: .cellar, title: "Root cellar", task: .buildCellar, cost: 4,
      benefit: "Preserved vegetables. From next season: Buy provisions brings 10 food for 4 coins.",
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
      benefit: "Forged tools bring the strongest coin income.", food: 0, coins: 3),
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
      $0.id == id && $0.level > 0 && $0.condition > 0 && $0.completedSeason < state.season
    }
  }
  // Legacy seasonal assignments remain valid for existing drafts and reference years.
  public static func unavailable(_ id: BuildingID, state: GameState) -> String? {
    if state.buildings.contains(where: { $0.id == id }) {
      return "Already completed or under construction."
    }
    if state.phase != .work {
      return "Finish the current conversation before assigning seasonal work."
    }
    if state.season == 3 {
      return "Seasonal construction is unavailable in winter. Use the real-time builder."
    }
    return nil
  }
  public static func upgradeCost(_ record: BuildingRecord) -> Int {
    definition(record.id).cost * (record.level + 1)
  }
  public static func repairCost(_ id: BuildingID) -> Int { (definition(id).cost + 1) / 2 }
}
