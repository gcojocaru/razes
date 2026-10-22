import Foundation

public enum SaveCodec {
  public static func encode(_ state: GameState) throws -> Data { try JSONEncoder().encode(state) }
  public static func decode(_ data: Data) throws -> GameState {
    guard data.count <= 1_000_000 else { throw GameError("This save is too large to read safely.") }
    let s: GameState
    do { s = try JSONDecoder().decode(GameState.self, from: data) } catch {
      throw GameError("This save could not be read. You can start a fresh household.")
    }
    guard s.version == 1 else {
      throw GameError(
        "This save belongs to an unsupported version. You can start a fresh household.")
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
      s.house + b.wear[3] < b.coldThreshold ? "winter-cold" : "winter-hearth",
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
        assigned.reduce(0) { $0 + Content.shared.tasks[$1.rawValue]!.moneyCost } <= s.money)
      try ensure(assigned.reduce(0) { $0 + Content.shared.tasks[$1.rawValue]!.foodCost } <= s.food)
    }
    return s
  }
}
