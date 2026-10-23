import Foundation

public enum SaveCodec {
  public static func encode(_ state: GameState) throws -> Data { try JSONEncoder().encode(state) }
  public static func decode(_ data: Data) throws -> GameState {
    guard data.count <= 1_000_000 else { throw GameError("This save is too large to read safely.") }
    let s: GameState
    do {
      struct Header: Decodable { let version: Int }
      guard try JSONDecoder().decode(Header.self, from: data).version == 8 else {
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
    try ensure(integer(s.food) && integer(s.money) && integer(s.house, 0, 100))
    try ensure(integer(s.houseLevel, 1, 5))
    try ensure(MaterialID.allCases.allSatisfy { integer(s.materials[$0]) })
    if let haul = s.lastMaterialHaul {
      try ensure(MaterialID.allCases.allSatisfy { integer(haul[$0], 0, 6) } && haul.total <= 6)
      try ensure(s.phase == .summary)
    }
    if let season = s.debugSeason { try ensure(integer(season, 0, 3)) }
    try ensure(Set(s.assignments.keys) == ["ion"])
    let task = s.assignments["ion"]!
    let resolved = s.phase == .summary
    try ensure(!s.tended || s.planted)
    try ensure(!s.harvested || (s.planted && s.season >= 2))
    if task == .plant { try ensure(s.season == 0) }
    if task == .tend { try ensure(s.season == 1 && s.planted) }
    if task == .harvest { try ensure(s.season == 2 && s.planted) }
    if s.season == 0 { try ensure(s.planted == (resolved && task == .plant)) }
    if s.season <= 1 { try ensure(s.tended == (s.season == 1 && resolved && task == .tend)) }
    if s.season <= 2 { try ensure(s.harvested == (s.season == 2 && resolved && task == .harvest)) }
    if resolved {
      guard let r = s.report else { throw GameError("This save has no seasonal report.") }
      try ensure(
        [
          r.foodBefore, r.foodAfter, r.moneyBefore, r.moneyAfter,
          r.consumption, r.wear, r.deficit,
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
        guard let builtTask = Construction.definition(record.id).task else {
          throw GameError("Invalid worker building.")
        }
        try ensure(record.level > 0 && record.completedSeason % 4 < 3)
        if record.completedSeason == s.turn { try ensure(resolved && task == builtTask) }
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
