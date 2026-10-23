import Foundation

public enum WorkerID: String, Codable, CaseIterable, Sendable { case ion }
public enum TaskID: String, Codable, CaseIterable, Sendable {
  case rest, plant, tend, harvest, paid, repair, supplies, buildWoodshed, buildCellar,
    gatherWood, gatherStone
}
public enum Phase: String, Codable, Sendable { case work, summary }
public struct SeasonReport: Codable, Equatable, Sendable {
  public var foodBefore, foodAfter, moneyBefore, moneyAfter, houseBefore, houseAfter, consumption,
    wear, deficit: Int
  public var tasks: [String]
}
public struct GameState: Codable, Equatable, Sendable {
  public var version = 8, revision = 0, season = 0, year = 0
  public var phase: Phase = .work
  public var food = 18, money = 12, house = 55
  public var materials = Materials.starter
  public var houseLevel = 1
  public var lastMaterialHaul: MaterialStock? = nil
  public var assignments: [String: TaskID] = ["ion": .rest]
  public var planted = false, tended = false, harvested = false
  public var report: SeasonReport? = nil
  public var buildings: [BuildingRecord] = []
  public var layout = SettlementLayout()
  public var debugSeason: Int? = nil
  public var turn: Int { year * 4 + season }
  public var displaySeason: Int { debugSeason ?? turn % 4 }
}
public struct Action: Codable, Equatable, Sendable {
  public var type: String, revision: Int
  public var worker: WorkerID?, task: TaskID?
  public init(type: String, revision: Int, worker: WorkerID? = nil, task: TaskID? = nil) {
    self.type = type
    self.revision = revision
    self.worker = worker
    self.task = task
  }
}
public struct Task: Codable, Equatable, Sendable, Identifiable {
  public var id: TaskID
  public var name, description, icon: String
  public var workers, moneyCost, foodCost, foodGain, moneyGain, houseGain: Int
}
public struct Projection: Codable, Equatable, Sendable {
  public var foodCost = 0, moneyCost = 0, foodGain = 0, moneyGain = 0, houseGain = 0
  public var consumption = 3, wear = 0, foodAfter = 0, moneyAfter = 0, houseAfter = 0
  public var errors: [String] = [], warnings: [String] = []
}
public struct GameError: LocalizedError, Sendable {
  public let message: String
  public init(_ message: String) { self.message = message }
  public var errorDescription: String? { message }
}
