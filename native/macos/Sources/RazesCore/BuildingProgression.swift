import Foundation

extension Construction {
  private static func spend(_ cost: Int, state: inout GameState) throws {
    let reserved = state.phase == .work ? Rules.preview(state).moneyCost : 0
    guard state.money - reserved >= cost else {
      throw GameError("Needs \(cost) free coins. Money reserved for seasonal work cannot be spent.")
    }
    state.money -= cost
  }
  public static func start(_ id: BuildingID, state: inout GameState) throws {
    guard stage(id, state: state) == .empty else {
      throw GameError("This building already exists or has a seasonal builder.")
    }
    let d = definition(id)
    try spend(d.cost, state: &state)
    var record = BuildingRecord(id: id, completedSeason: state.season, realtime: true, level: 0)
    record.work = BuildingWork(kind: .build, duration: d.buildTime)
    state.buildings.append(record)
  }
  public static func upgrade(_ id: BuildingID, state: inout GameState) throws {
    guard let index = state.buildings.firstIndex(where: { $0.id == id }) else {
      throw GameError("Build this structure first.")
    }
    let r = state.buildings[index]
    guard r.level > 0, r.level < 5, r.work == nil else {
      throw GameError("An upgrade needs an idle building below level 5.")
    }
    try spend(upgradeCost(r), state: &state)
    state.buildings[index].work = BuildingWork(kind: .upgrade, duration: Double(60 * (r.level + 1)))
  }
  public static func repair(_ id: BuildingID, state: inout GameState) throws {
    guard let index = state.buildings.firstIndex(where: { $0.id == id }) else {
      throw GameError("Build this structure first.")
    }
    let r = state.buildings[index]
    guard r.level > 0, r.condition < 100, r.work == nil else {
      throw GameError("Repairs need an idle, worn building.")
    }
    try spend(repairCost(id), state: &state)
    state.buildings[index].work = BuildingWork(kind: .repair, duration: 20)
  }
  public static func advance(state: inout GameState, seconds: Double) throws {
    guard seconds.isFinite, (0...86400).contains(seconds) else {
      throw GameError("Advance time by at most 24 hours.")
    }
    for index in state.buildings.indices {
      var r = state.buildings[index]
      var remaining = seconds
      if var work = r.work {
        let used = min(remaining, work.remaining)
        remaining -= used
        work.remaining -= used
        if work.remaining > 0 {
          r.work = work
        } else {
          if work.kind == .build {
            r.level = 1
            r.completedSeason = state.season
          }
          if work.kind == .upgrade { r.level += 1 }
          r.condition = 100
          r.work = nil
        }
      }
      // Split at downgrade boundaries so a long absence matches many short ticks.
      while remaining > 0 && r.work == nil && r.level > 0 && r.condition > 0 {
        let untilExhausted = r.condition * 900
        let span = min(remaining, untilExhausted)
        let cycles = (r.production + span) / 60
        let count = Int((cycles + 0.0000001).rounded(.down))
        r.production = max(0, r.production + span - Double(count) * 60)
        let d = definition(r.id)
        state.food = min(100000, state.food + count * d.food * r.level)
        state.money = min(100000, state.money + count * d.coins * r.level)
        r.condition = span == untilExhausted ? 0 : max(0, r.condition - span / 900)
        remaining -= span
        if r.condition == 0 {
          r.condition = 0
          if r.level > 1 {
            r.level -= 1
            r.condition = 60
          }
        }
      }
      state.buildings[index] = r
    }
  }
  public static func catchUp(state: inout GameState, now: Double) {
    guard now.isFinite, (0...32_503_680_000).contains(now) else { return }
    guard let previous = state.buildingClock else {
      state.buildingClock = now
      return
    }
    guard now > previous else { return }
    try? advance(state: &state, seconds: min(86400, now - previous))
    state.buildingClock = now
  }
}
