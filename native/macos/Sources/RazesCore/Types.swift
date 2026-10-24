import Foundation

public enum WorkerID: String, Codable, CaseIterable, Sendable { case ion }
public enum TaskID: String, Codable, CaseIterable, Sendable {
  case rest, plant, tend, harvest, paid, repair, supplies, buildWoodshed, buildCellar,
    gatherWood, gatherStone
}
public enum Phase: String, Codable, Sendable { case work, summary, dead }
public struct SeasonReport: Codable, Equatable, Sendable {
  public var foodBefore, foodAfter, moneyBefore, moneyAfter, houseBefore, houseAfter, consumption,
    wear, deficit: Int
  public var tasks: [String]
  public var seedsBefore = 0, seedsAfter = 0
  public var character = CharacterWeek()
  public var buildingsBefore: [BuildingRecord] = []
}
public struct GameState: Codable, Equatable, Sendable {
  public var version = 11, revision = 0, season = 0, year = 0, week = 0
  public var phase: Phase = .work
  public var character = CharacterState()
  public var food = 18, money = 12, house = 55
  public var seeds = 8, cropWeeks = 0
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
  public var month: Int { week / 4 + 1 }
  public var weekOfMonth: Int { week % 4 + 1 }
  public var isMonthEnd: Bool { weekOfMonth == 4 }
  public var isSeasonEnd: Bool { week == 11 }
  public var calendarLabel: String {
    "\(Content.seasons[season]) · Month \(month) · Week \(weekOfMonth) · \(1495 + year)"
  }
  public var nextWeekLabel: String {
    let next = (week + 1) % 12
    let nextSeason = isSeasonEnd ? (season + 1) % 4 : season
    let nextYear = year + (isSeasonEnd && season == 3 ? 1 : 0)
    return
      "\(Content.seasons[nextSeason]) · Month \(next / 4 + 1) · Week \(next % 4 + 1) · \(1495 + nextYear)"
  }
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
  public var consumption = 1, wear = 0, foodAfter = 0, moneyAfter = 0, houseAfter = 0
  public var seedCost = 0, seedGain = 0, seedsAfter = 0
  public var errors: [String] = [], warnings: [String] = []
  public var character = CharacterWeek()
}
public struct GameError: LocalizedError, Sendable {
  public let message: String
  public init(_ message: String) { self.message = message }
  public var errorDescription: String? { message }
}
