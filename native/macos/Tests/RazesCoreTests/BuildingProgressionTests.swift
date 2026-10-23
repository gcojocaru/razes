import XCTest

@testable import RazesCore

final class BuildingProgressionTests: XCTestCase {
  func funded() -> GameState {
    var s = Rules.newGame()
    s.money = 1000
    return s
  }
  func testCatalogHasTenUniqueTypes() {
    XCTAssertEqual(BuildingID.allCases.count, 10)
    XCTAssertEqual(Set(Construction.definitions.map(\.id)).count, 10)
  }
  func testTimedBuildUpgradeRepairAndLevelCap() throws {
    var s = funded()
    try Construction.start(.woodshed, state: &s)
    XCTAssertEqual(s.money, 997)
    XCTAssertEqual(s.buildings[0].level, 0)
    try Construction.advance(state: &s, seconds: 29)
    XCTAssertEqual(s.buildings[0].level, 0)
    try Construction.advance(state: &s, seconds: 1)
    XCTAssertEqual(s.buildings[0].level, 1)
    for target in 2...5 {
      try Construction.upgrade(.woodshed, state: &s)
      try Construction.advance(state: &s, seconds: Double(60 * target))
      XCTAssertEqual(s.buildings[0].level, target)
    }
    XCTAssertThrowsError(try Construction.upgrade(.woodshed, state: &s))
    s.buildings[0].condition = 25
    let money = s.money
    try Construction.repair(.woodshed, state: &s)
    XCTAssertEqual(s.money, money - 2)
    try Construction.advance(state: &s, seconds: 20)
    XCTAssertEqual(s.buildings[0].condition, 100)
  }
  func testTimeSplittingMatchesWorkCompletionProductionAndDowngrades() throws {
    var whole = funded()
    try Construction.start(.woodshed, state: &whole)
    var parts = whole
    try Construction.advance(state: &whole, seconds: 3600)
    for _ in 0..<360 { try Construction.advance(state: &parts, seconds: 10) }
    XCTAssertEqual(whole.money, parts.money)
    XCTAssertEqual(whole.buildings[0].condition, parts.buildings[0].condition, accuracy: 0.00001)
    XCTAssertEqual(whole.buildings[0].production, parts.buildings[0].production, accuracy: 0.00001)
    whole.buildings[0].level = 5
    whole.buildings[0].condition = 4
    parts = whole
    try Construction.advance(state: &whole, seconds: 86400)
    for _ in 0..<24 { try Construction.advance(state: &parts, seconds: 3600) }
    XCTAssertEqual(whole.buildings[0].level, 3)
    XCTAssertEqual(whole.money, parts.money)
    XCTAssertEqual(whole.buildings[0].condition, parts.buildings[0].condition, accuracy: 0.00001)
    whole.buildings[0].level = 1
    whole.buildings[0].condition = 1
    try Construction.advance(state: &whole, seconds: 3600)
    let money = whole.money
    try Construction.advance(state: &whole, seconds: 3600)
    XCTAssertEqual(whole.buildings[0].level, 1)
    XCTAssertEqual(whole.buildings[0].condition, 0)
    XCTAssertEqual(whole.money, money)
  }
  func testClockCapRollbackAndReservedMoney() throws {
    var s = funded()
    try Construction.start(.woodshed, state: &s)
    Construction.catchUp(state: &s, now: 100000)
    Construction.catchUp(state: &s, now: 100030)
    XCTAssertEqual(s.buildings[0].level, 1)
    let before = s
    Construction.catchUp(state: &s, now: 99900)
    XCTAssertEqual(s, before)
    Construction.catchUp(state: &s, now: 1_000_000)
    XCTAssertEqual(s.buildings[0].condition, 4, accuracy: 0.00001)
    let completed = s
    Construction.catchUp(state: &s, now: 1_000_000)
    XCTAssertEqual(s, completed)
    s.phase = .work
    s.money = 4
    s.assignments["ion"] = .supplies
    let original = s
    XCTAssertThrowsError(try Construction.start(.cellar, state: &s))
    XCTAssertEqual(s, original)
    XCTAssertThrowsError(try Construction.advance(state: &s, seconds: -.infinity))
  }
}

extension BuildingProgressionTests {
  func testAllTenBuildingsRoundTripEveryUpgradeAndRejectBadTimers() throws {
    var s = funded()
    for id in BuildingID.allCases {
      let position = try XCTUnwrap(Settlement.firstAvailable(id, in: s.layout))
      s.layout.buildings.append(.init(id: id, position: position))
      try Construction.start(id, state: &s)
      XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(s)), s)
    }
    try Construction.advance(state: &s, seconds: 90)
    for level in 2...5 {
      for id in BuildingID.allCases { try Construction.upgrade(id, state: &s) }
      XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(s)), s)
      try Construction.advance(state: &s, seconds: Double(60 * level))
      XCTAssertTrue(s.buildings.allSatisfy { $0.level == level })
      XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(s)), s)
    }
    for badLevel in [-1, 6, Int.max] {
      var bad = s
      bad.buildings[0].level = badLevel
      XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(bad)))
    }
    var bad = s
    bad.buildings[0].condition = -1
    XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(bad)))
    bad = s
    bad.buildings[0].work = BuildingWork(kind: .upgrade, duration: 360)
    XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(bad)))
    bad = s
    bad.buildings[0].production = 60
    XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(bad)))
    bad = s
    bad.buildingClock = -1
    XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(bad)))
  }
  func testV3CompletedBuildingMigratesWithoutAcceptingNewFields() throws {
    var original = Rules.newGame()
    original.buildings = [.init(id: .woodshed, completedSeason: 0, debugPlaced: true)]
    original.layout.buildings = [.init(id: .woodshed, position: .init(x: 1, y: 1))]
    var object =
      try JSONSerialization.jsonObject(with: SaveCodec.encode(original)) as! [String: Any]
    object["version"] = 3
    var records = object["buildings"] as! [[String: Any]]
    for key in ["level", "condition", "production", "realtime"] {
      records[0].removeValue(forKey: key)
    }
    object["buildings"] = records
    let migrated = try SaveCodec.decode(JSONSerialization.data(withJSONObject: object))
    XCTAssertEqual(migrated, original)
    records[0]["level"] = 5
    object["buildings"] = records
    XCTAssertThrowsError(try SaveCodec.decode(JSONSerialization.data(withJSONObject: object)))
  }
}

extension BuildingProgressionTests {
  func testSplitAtLastFractionOfConditionKeepsFinalProductionPayout() throws {
    var whole = Rules.newGame()
    whole.buildings = [.init(id: .woodshed, completedSeason: 0, debugPlaced: true, condition: 1)]
    var split = whole
    try Construction.advance(state: &whole, seconds: 900)
    try Construction.advance(state: &split, seconds: 899.9996)
    try Construction.advance(state: &split, seconds: 0.0004)
    XCTAssertEqual(whole.money, 27)
    XCTAssertEqual(split.money, whole.money)
    XCTAssertEqual(split.buildings[0].condition, 0, accuracy: 0.000000001)
  }
  func testSeasonalBenefitBeginsSeasonAfterTimedCompletion() throws {
    var s = funded()
    try Construction.start(.cellar, state: &s)
    s.season = 1
    try Construction.advance(state: &s, seconds: 40)
    XCTAssertEqual(s.buildings[0].completedSeason, 1)
    XCTAssertFalse(Construction.active(.cellar, state: s))
    s.season = 2
    XCTAssertTrue(Construction.active(.cellar, state: s))
  }
  func testSeasonalEarningsAndEventGainsAtResourceCapRemainLoadable() throws {
    var s = Rules.newGame()
    s = try Rules.dispatch(
      s, action: .init(type: "choose", revision: s.revision, event: "spring-ox", choice: "borrow"))
    s.food = 100000
    s.money = 100000
    s = try Rules.dispatch(
      s, action: .init(type: "assign", revision: s.revision, worker: .ion, task: .paid))
    s = try Rules.dispatch(
      s, action: .init(type: "assign", revision: s.revision, worker: .ana, task: .supplies))
    XCTAssertEqual(Rules.preview(s).moneyAfter, 100000)
    XCTAssertEqual(Rules.preview(s).foodAfter, 99991)
    s = try Rules.dispatch(s, action: .init(type: "resolve", revision: s.revision))
    XCTAssertEqual(s.money, 100000)
    XCTAssertEqual(s.food, 100000)
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(s)), s)
    s = try Rules.dispatch(
      s, action: .init(type: "choose", revision: s.revision, event: "spring-table", choice: "share")
    )
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(s)), s)
  }
}
