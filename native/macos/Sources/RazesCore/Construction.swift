import Foundation

public enum BuildingID: String, Codable, CaseIterable, Sendable { case woodshed, cellar }
public struct BuildingRecord: Codable, Equatable, Sendable {
  public var id: BuildingID
  public var completedSeason: Int
  public init(id: BuildingID, completedSeason: Int) {
    self.id = id
    self.completedSeason = completedSeason
  }
}
public struct BuildingDefinition: Sendable, Identifiable {
  public let id: BuildingID
  public let title: String
  public let task: TaskID
  public let cost: Int
  public let benefit: String
}
public enum BuildingStage: String, Sendable { case empty, planned, complete }
public enum Construction {
  public static let definitions: [BuildingDefinition] = [
    BuildingDefinition(
      id: .woodshed, title: "Woodshed", task: .buildWoodshed, cost: 3,
      benefit:
        "In winter: base consumption 6 instead of 9, weathering 6 instead of 14. Cold shelter still costs 3 extra food."
    ),
    BuildingDefinition(
      id: .cellar, title: "Root cellar", task: .buildCellar, cost: 4,
      benefit:
        "From the following season: each Buy provisions assignment brings 10 food instead of 7, for the same 4 money."
    ),
  ]
  public static func definition(_ id: BuildingID) -> BuildingDefinition {
    definitions.first { $0.id == id }!
  }
  public static func building(for task: TaskID) -> BuildingID? {
    definitions.first { $0.task == task }?.id
  }
  public static func stage(_ id: BuildingID, state: GameState) -> BuildingStage {
    if state.buildings.contains(where: { $0.id == id }) { return .complete }
    return state.assignments.values.contains(definition(id).task) ? .planned : .empty
  }
  public static func active(_ id: BuildingID, state: GameState) -> Bool {
    state.buildings.contains { $0.id == id && $0.completedSeason < state.season }
  }
  public static func unavailable(_ id: BuildingID, state: GameState) -> String? {
    if state.buildings.contains(where: { $0.id == id }) { return "Already completed." }
    if state.phase != .work {
      return "Finish the current conversation before planning construction."
    }
    if state.season == 3 {
      return "Winter is too late to build. Benefits begin the following season."
    }
    return nil
  }
}
