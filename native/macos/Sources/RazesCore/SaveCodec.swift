import Foundation

public enum SaveCodec {
  public static func encode(_ state: GameState) throws -> Data { try JSONEncoder().encode(state) }
  public static func decode(_ data: Data) throws -> GameState {
    guard data.count <= 1_000_000 else { throw GameError("This save is too large to read safely.") }
    let s: GameState
    do {
      struct Header: Decodable { let version: Int }
      guard try JSONDecoder().decode(Header.self, from: data).version == 9 else {
        throw GameError("This save belongs to an unsupported version. Start a fresh settlement.")
      }
      s = try JSONDecoder().decode(GameState.self, from: data)
    } catch let error as GameError { throw error } catch {
      throw GameError("This save could not be read. You can start a fresh settlement.")
    }
    func ensure(_ valid: Bool) throws {
      if !valid {
        throw GameError("This save is invalid or incomplete. You can start a fresh settlement.")
      }
    }
    func integer(_ value: Int, _ min: Int = 0, _ max: Int = 100000) -> Bool {
      (min...max).contains(value)
    }
    try ensure(integer(s.revision, 0, 1_000_000_000) && integer(s.year) && integer(s.season, 0, 3))
    try ensure(integer(s.week, 0, 11) && integer(s.seeds) && integer(s.cropWeeks, 0, 24))
    try ensure(integer(s.food) && integer(s.money) && integer(s.house, 0, 100))
    try ensure(integer(s.houseLevel, 1, 5))
    try ensure(MaterialID.allCases.allSatisfy { integer(s.materials[$0]) })
    if let haul = s.lastMaterialHaul {
      try ensure(
        integer(haul.wood, 0, 2) && integer(haul.stone, 0, 1) && haul.planks == 0 && haul.total <= 2
      )
      try ensure(s.phase == .summary)
    }
    if let season = s.debugSeason { try ensure(integer(season, 0, 3)) }
    try ensure(Set(s.assignments.keys) == ["ion"])
    let task = s.assignments["ion"]!
    let resolved = s.phase == .summary
    try ensure(s.planted ? s.cropWeeks > 0 : s.cropWeeks == 0 && !s.tended && !s.harvested)
    try ensure(s.cropWeeks <= s.season * 12 + s.week + (resolved ? 1 : 0))
    try ensure(!s.tended || (s.planted && s.cropWeeks >= 5))
    try ensure(!s.harvested || (s.planted && s.cropWeeks == 24 && s.season >= 2))
    if task == .plant {
      try ensure(s.season == 0 && (resolved ? s.planted && s.cropWeeks == 1 : !s.planted))
    }
    if task == .tend {
      try ensure(resolved ? s.tended && !s.harvested && s.season != 3 : Farming.canTend(s))
    }
    if task == .harvest {
      try ensure(s.season == 2 && (resolved ? s.harvested : Farming.canHarvest(s)))
    }
    if resolved {
      guard let r = s.report else { throw GameError("This save has no weekly report.") }
      try ensure(
        [
          r.foodBefore, r.foodAfter, r.moneyBefore, r.moneyAfter,
          r.consumption, r.wear, r.deficit, r.seedsBefore, r.seedsAfter,
        ].allSatisfy { integer($0) })
      try ensure(integer(r.houseBefore, 0, 100) && integer(r.houseAfter, 0, 100))
      try ensure(r.tasks == ["Ion: \(Rules.task(task).name)"])
    } else {
      try ensure(s.report == nil)
    }
    try ensure(s.buildings.count <= BuildingID.allCases.count)
    try ensure(Set(s.buildings.map(\.id)).count == s.buildings.count)
    for record in s.buildings {
      try ensure(
        integer(record.level, 0, 5) && record.condition.isFinite
          && (0...100).contains(record.condition))
      try ensure(integer(record.completedSeason, 0, s.turn))
      if record.legacyAssignment && record.debugPlaced != true {
        guard Construction.definition(record.id).task != nil else {
          throw GameError("Invalid worker building.")
        }
        try ensure(record.completedSeason % 4 < 3)
      }
    }
    if let id = Construction.building(for: task) {
      try ensure(s.season < 3)
      let completion = s.buildings.first { $0.id == id }
      try ensure(
        resolved
          ? completion?.completedSeason == s.turn && completion?.legacyAssignment == true
          : completion == nil)
    }
    try Settlement.validate(s)
    if !resolved {
      try ensure(Rules.assignmentProblem(s, worker: .ion, task: task) == nil)
    }
    return s
  }
}
