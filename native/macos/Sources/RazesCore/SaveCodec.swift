import Foundation

public enum SaveCodec {
  public static func encode(_ state: GameState) throws -> Data { try JSONEncoder().encode(state) }
  public static func decode(_ data: Data) throws -> GameState {
    guard data.count <= 1_000_000 else { throw GameError("This save is too large to read safely.") }
    var s: GameState
    do {
      struct Header: Decodable { let version: Int }
      let version = try JSONDecoder().decode(Header.self, from: data).version
      guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw GameError("This save could not be read.")
      }
      guard (1...5).contains(version) else {
        throw GameError("This save belongs to an unsupported version.")
      }
      if version == 1 {
        guard object["buildings"] == nil,
          let assignments = object["assignments"] as? [String: String],
          assignments.values.allSatisfy({ Content.shared.tasks[$0] != nil })
        else {
          throw GameError("This legacy save contains unsupported construction data.")
        }
        object["version"] = 2
        object["buildings"] = []
      }
      if version < 3 {
        guard object["layout"] == nil else {
          throw GameError("This legacy save contains unsupported placement data.")
        }
        object["layout"] = ["buildings": [], "scenery": []]
        object["version"] = 3
      }
      if version < 4 {
        guard object["buildingClock"] == nil else {
          throw GameError("Unsupported legacy clock data.")
        }
        guard var records = object["buildings"] as? [[String: Any]] else {
          throw GameError("Missing buildings.")
        }
        for index in records.indices {
          guard ["woodshed", "cellar"].contains(records[index]["id"] as? String ?? ""),
            ["level", "condition", "production", "work", "realtime"].allSatisfy({
              records[index][$0] == nil
            })
          else { throw GameError("Unsupported legacy progression data.") }
          records[index]["level"] = 1
          records[index]["condition"] = 100
          records[index]["production"] = 0
          records[index]["realtime"] = false
        }
        object["buildings"] = records
        object["version"] = 4
      }
      if version < 5 { try migrateSeasonal(&object) }
      s = try JSONDecoder().decode(
        GameState.self, from: JSONSerialization.data(withJSONObject: object))
      if version < 3 { s.layout = Settlement.legacyLayout(for: s) }
    } catch let error as GameError { throw error } catch {
      throw GameError("This save could not be read. You can start a fresh household.")
    }
    func ensure(_ valid: Bool) throws {
      if !valid {
        throw GameError("This save is invalid or incomplete. You can start a fresh household.")
      }
    }
    func integer(_ value: Int, _ min: Int = 0, _ max: Int = 100000) -> Bool {
      (min...max).contains(value)
    }
    func text(_ value: String) -> Bool { value.utf16.count <= 2000 }
    let b = Content.shared.balance
    try ensure(
      integer(s.revision) && integer(s.season, 0, 3) && integer(s.food) && integer(s.money)
        && integer(s.house, 0, 100) && integer(s.trust, -5, 5))
    try ensure(integer(s.settlementSeasons) && (s.settlementSeasons == 0 || s.phase == .ending))
    if let season = s.debugSeason { try ensure(integer(season, 0, 3)) }
    try ensure(["none", "borrowed", "paid", "declined", "honoured", "broken"].contains(s.ox))
    try ensure(s.cropBonus == 0 || s.cropBonus == b.oxBonus)
    try ensure(Set(s.assignments.keys) == Set(WorkerID.allCases.map(\.rawValue)))
    try ensure(
      s.reservedWorker == nil
        || (s.reservedWorker == "petru" && s.season == 2 && s.ox == "honoured"
          && s.assignments["petru"] == .help)
    )
    try ensure(!s.tended || s.planted)
    try ensure(!s.harvested || (s.planted && s.season >= 2))
    try ensure(!(s.season == 0 && s.tended))
    try ensure(s.planted || s.cropBonus == 0)
    try ensure(s.phase != .ending || s.season == 3)
    try ensure(s.ox != "none" || (s.season == 0 && s.phase == .opening))
    try ensure(s.history.count <= 8 && s.memories.count <= 12 && s.hardship.count <= 8)
    var seen = Set<String>()
    for h in s.history {
      try ensure(
        text(h.event) && text(h.choice) && text(h.title) && text(h.detail)
          && integer(h.season, 0, 3))
      try ensure(
        Content.shared.events[h.event]?.choices.contains { $0.id == h.choice } == true
          && !seen.contains(h.event))
      seen.insert(h.event)
    }
    let count =
      s.season * 2 + (s.phase == .opening ? 0 : s.phase == .work || s.phase == .consequence ? 1 : 2)
    try ensure(s.history.count == count)
    for m in s.memories {
      try ensure(
        text(m.id) && text(m.title) && text(m.detail) && integer(m.season, 0, 3)
          && ["good", "bad", "neutral"].contains(m.tone))
    }
    for h in s.hardship {
      try ensure(
        integer(h.season, 0, 3) && ["food", "shelter"].contains(h.kind) && integer(h.amount, 1))
    }
    let resolved = [.consequence, .summary, .ending].contains(s.phase)
    if resolved {
      guard let r = s.report else { throw GameError("This save has no seasonal report.") }
      try ensure(
        [
          r.foodBefore, r.foodAfter, r.moneyBefore, r.moneyAfter, r.houseBefore, r.houseAfter,
          r.consumption, r.wear, r.deficit,
        ].allSatisfy { integer($0) })
      try ensure(r.tasks.count == 3 && r.tasks.allSatisfy(text))
    } else {
      try ensure(s.report == nil)
    }
    let opening = s.history.first { $0.event == "spring-ox" }
    let autumn = s.history.first { $0.event == "autumn-promise" }
    let ox =
      opening == nil
      ? "none"
      : opening!.choice == "pay"
        ? "paid"
        : opening!.choice == "decline"
          ? "declined"
          : autumn == nil ? "borrowed" : autumn!.choice == "honour" ? "honoured" : "broken"
    try ensure(s.ox == ox)
    let events = [
      "spring-ox", "spring-table", "summer-brother", s.tended ? "summer-tended" : "summer-dry",
      opening?.choice == "borrow" ? "autumn-promise" : "autumn-free", "autumn-dispute",
      ox == "broken" ? "winter-isolation" : "winter-friend",
      s.house + (s.report?.wear ?? Rules.weathering(s)) < b.coldThreshold
        ? "winter-cold" : "winter-hearth",
    ]
    for (i, h) in s.history.enumerated() { try ensure(h.event == events[i] && h.season == i / 2) }
    try ensure(
      s.fairShare == s.history.contains { $0.event == "summer-brother" && $0.choice == "share" })
    let reserved = s.season == 2 && s.ox == "honoured"
    try ensure(s.reservedWorker == (reserved ? "petru" : nil))
    if reserved { try ensure(s.assignments["petru"] == .help) }
    let assigned = Array(s.assignments.values)
    func n(_ task: TaskID) -> Int { assigned.filter { $0 == task }.count }
    try ensure(n(.plant) <= 1 && n(.tend) <= 1 && n(.harvest) <= 2)
    if s.phase == .opening { try ensure(assigned.allSatisfy { $0 == .rest }) }
    for task in assigned {
      if task == .plant { try ensure(s.season == 0) }
      if task == .tend { try ensure(s.season == 1 && s.planted) }
      if task == .harvest { try ensure(s.season == 2 && s.planted) }
    }
    if resolved { try ensure(n(.harvest) != 1) }
    if s.season == 0 { try ensure(s.planted == (resolved && n(.plant) == 1)) }
    if s.season <= 1 { try ensure(s.tended == (s.season == 1 && resolved && n(.tend) == 1)) }
    if s.season <= 2 { try ensure(s.harvested == (s.season == 2 && resolved && n(.harvest) == 2)) }
    try ensure(s.cropBonus == (s.planted && opening?.choice != "decline" ? b.oxBonus : 0))
    if s.phase == .work {
      try ensure(
        assigned.reduce(0) { $0 + Rules.task($1).moneyCost } <= s.money)
      try ensure(assigned.reduce(0) { $0 + Rules.task($1).foodCost } <= s.food)
    }
    try ensure(s.buildings.count <= BuildingID.allCases.count)
    try ensure(Set(s.buildings.map(\.id)).count == s.buildings.count)
    for record in s.buildings {
      try ensure(
        integer(record.level, 0, 5) && record.condition.isFinite
          && (0...100).contains(record.condition))
      try ensure(integer(record.completedSeason, 0, s.turn))
      if record.legacyAssignment && record.debugPlaced != true {
        guard let task = Construction.definition(record.id).task else {
          throw GameError("Invalid seasonal worker building.")
        }
        try ensure(record.level > 0 && record.completedSeason < 3)
        if record.completedSeason == s.season { try ensure(resolved && assigned.contains(task)) }
      }
    }
    for definition in Construction.definitions {
      guard let task = definition.task else { continue }
      try ensure(n(task) <= 1)
      if n(task) > 0 {
        try ensure(s.season < 3)
        let completion = s.buildings.first { $0.id == definition.id }
        try ensure(
          resolved
            ? completion?.completedSeason == s.season && completion?.legacyAssignment == true
            : completion == nil)
      }
    }
    try Settlement.validate(s)
    return s
  }
  private static func migrateSeasonal(_ object: inout [String: Any]) throws {
    struct Work: Decodable {
      var kind: String
      var remaining, duration: Double
    }
    struct Record: Decodable {
      var id: BuildingID
      var level: Int
      var condition, production: Double
      var realtime: Bool
      var work: Work?
    }
    struct Clock: Decodable { var buildingClock: Double? }
    let data = try JSONSerialization.data(withJSONObject: object)
    let clock = try JSONDecoder().decode(Clock.self, from: data).buildingClock
    guard clock == nil || clock!.isFinite && (0...32_503_680_000).contains(clock!),
      object["settlementSeasons"] == nil, object["debugSeason"] == nil,
      var records = object["buildings"] as? [[String: Any]],
      var layout = object["layout"] as? [String: Any],
      ["viewRotation", "pavement", "fences"].allSatisfy({ layout[$0] == nil })
    else { throw GameError("Invalid legacy clock or placement data.") }
    let typed = try JSONDecoder().decode(
      [Record].self, from: JSONSerialization.data(withJSONObject: records))
    for (index, r) in typed.enumerated() {
      guard (0...5).contains(r.level), r.condition.isFinite, (0...100).contains(r.condition),
        r.production.isFinite, (0..<60).contains(r.production),
        records[index]["legacyAssignment"] == nil
      else { throw GameError("Invalid legacy building progression.") }
      if let w = r.work {
        let expected: Double
        switch w.kind {
        case "build":
          guard r.level == 0, r.realtime else { throw GameError("Invalid legacy foundation.") }
          expected = Double(Construction.definition(r.id).cost * 10)
        case "upgrade":
          guard (1...4).contains(r.level) else { throw GameError("Invalid legacy upgrade.") }
          expected = Double(60 * (r.level + 1))
          records[index]["level"] = r.level + 1
          records[index]["condition"] = 100
        case "repair":
          guard r.level > 0, r.condition < 100 else { throw GameError("Invalid legacy repair.") }
          expected = 20
          records[index]["condition"] = 100
        default: throw GameError("Unknown legacy job.")
        }
        guard w.duration == expected, w.remaining.isFinite, w.remaining > 0, w.remaining <= expected
        else { throw GameError("Invalid legacy timer.") }
      } else if r.level == 0 {
        throw GameError("Missing legacy construction job.")
      }
      records[index]["legacyAssignment"] = !r.realtime
      for key in ["work", "production", "realtime"] { records[index].removeValue(forKey: key) }
    }
    for key in ["buildings", "scenery"] {
      guard var placements = layout[key] as? [[String: Any]] else {
        throw GameError("Missing legacy layout.")
      }
      for index in placements.indices {
        guard placements[index]["facing"] == nil else {
          throw GameError("Unexpected legacy direction.")
        }
        placements[index]["facing"] = 0
      }
      layout[key] = placements
    }
    layout["viewRotation"] = 0
    layout["pavement"] = []
    layout["fences"] = []
    object["layout"] = layout
    object["buildings"] = records
    object["settlementSeasons"] = 0
    object.removeValue(forKey: "buildingClock")
    object["version"] = 5
  }
}
