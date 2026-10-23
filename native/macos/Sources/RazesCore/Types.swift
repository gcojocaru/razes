import Foundation

public enum WorkerID: String, Codable, CaseIterable, Sendable { case ion, ana, petru }
public enum TaskID: String, Codable, CaseIterable, Sendable {
  case rest, plant, tend, harvest, paid, repair, help, supplies, buildWoodshed, buildCellar
}
public enum Phase: String, Codable, Sendable { case opening, work, consequence, summary, ending }
public struct Memory: Codable, Equatable, Sendable {
  public var id, title, detail: String
  public var season: Int
  public var tone: String
}
public struct HistoryEntry: Codable, Equatable, Sendable {
  public var event, choice, title, detail: String
  public var season: Int
}
public struct Hardship: Codable, Equatable, Sendable {
  public var season: Int
  public var kind: String
  public var amount: Int
}
public struct SeasonReport: Codable, Equatable, Sendable {
  public var foodBefore, foodAfter, moneyBefore, moneyAfter, houseBefore, houseAfter, consumption,
    wear, deficit: Int
  public var tasks: [String]
}
public struct GameState: Codable, Equatable, Sendable {
  public var version = 3, revision = 0, season = 0
  public var phase: Phase = .opening
  public var food = 18, money = 12, house = 55
  public var assignments: [String: TaskID] = ["ion": .rest, "ana": .rest, "petru": .rest]
  public var reservedWorker: String? = nil
  public var planted = false, tended = false, harvested = false
  public var cropBonus = 0
  public var ox = "none", trust = 0
  public var fairShare = false
  public var memories: [Memory] = []
  public var history: [HistoryEntry] = []
  public var hardship: [Hardship] = []
  public var report: SeasonReport? = nil
  public var buildings: [BuildingRecord] = []
  public var layout = SettlementLayout()
}
public struct Action: Codable, Equatable, Sendable {
  public var type: String, revision: Int
  public var event: String?, choice: String?, worker: WorkerID?, task: TaskID?
  public init(
    type: String, revision: Int, event: String? = nil, choice: String? = nil,
    worker: WorkerID? = nil, task: TaskID? = nil
  ) {
    self.type = type
    self.revision = revision
    self.event = event
    self.choice = choice
    self.worker = worker
    self.task = task
  }
}
public struct Effect: Codable, Sendable {
  public var food, money, house, trust: Int?
  public var ox: String?
  public var fairShare, reserve: Bool?
}
public struct Choice: Codable, Sendable, Identifiable {
  public var id, label, detail: String
  public var effect: Effect
  public struct MemoryText: Codable, Sendable { public var title, detail, tone: String }
  public var memory: MemoryText?
}
public struct GameEvent: Codable, Sendable {
  public var id, eyebrow, title, person, text: String
  public var choices: [Choice]
}
public struct Task: Codable, Equatable, Sendable, Identifiable {
  public var id: TaskID
  public var name, description, icon: String
  public var workers, moneyCost, foodCost, foodGain, moneyGain, houseGain: Int
}
public struct Projection: Codable, Equatable, Sendable {
  public var foodCost = 0, moneyCost = 0, foodGain = 0, moneyGain = 0, houseGain = 0
  public var consumption = 9, wear = 0, foodAfter = 0, moneyAfter = 0, houseAfter = 0
  public var errors: [String] = [], warnings: [String] = []
}
public struct Ending: Codable, Equatable, Sendable {
  public var category, title, text: String
  public var decisions: [HistoryEntry]
}
public struct GameError: LocalizedError, Sendable {
  public let message: String
  public init(_ message: String) { self.message = message }
  public var errorDescription: String? { message }
}
