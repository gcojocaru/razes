import XCTest

@testable import RazesCore

final class HarvestCalendarTests: XCTestCase {
  func advance(_ state: GameState, task: TaskID = .rest) throws -> GameState {
    let draft = try Rules.dispatch(
      state, action: .init(type: "assign", revision: state.revision, worker: .ion, task: task))
    let done = try Rules.dispatch(draft, action: .init(type: "resolve", revision: draft.revision))
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(done)), done)
    return try Rules.dispatch(done, action: .init(type: "continue", revision: done.revision))
  }

  func testSeasonHasTwelveWeeklyAssignmentsAndYearHasFortyEight() throws {
    var s = Rules.newGame()
    s.food = 60
    s.house = 100
    for week in 1...48 {
      s = try advance(s)
      XCTAssertEqual(s.season, (week / 12) % 4)
      XCTAssertEqual(s.year, week / 48)
      XCTAssertEqual(s.turn, week / 12)
      XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(s)), s)
    }
  }

  func testWeeklyConsumptionAndSeasonalProductionWearAndCompletion() throws {
    var s = Rules.newGame()
    s.season = 1
    s.buildings = [.init(id: .workshop, completedSeason: 0, legacyAssignment: false)]
    s.layout.buildings = [.init(id: .workshop, position: .init(x: 1, y: 1))]
    try Construction.start(.woodshed, state: &s)
    s.layout.buildings.append(.init(id: .woodshed, position: .init(x: 3, y: 8)))
    for week in 1...12 {
      let p = Rules.preview(s)
      XCTAssertEqual(p.consumption, 1)
      XCTAssertEqual(p.wear, week == 12 ? 5 : 0)
      XCTAssertEqual(p.moneyGain, week == 12 ? 2 : 0)
      s = try advance(s)
      XCTAssertEqual(s.food, 18 - week)
      XCTAssertEqual(s.buildings[0].condition, week == 12 ? 80 : 100)
      XCTAssertEqual(s.buildings[1].level, week == 12 ? 1 : 0)
      XCTAssertEqual(Construction.active(.woodshed, state: s), week == 12)
    }
    XCTAssertEqual(s.money, 11)
  }

  func testSowingUsesSeparateSeedsAndGrowthUnlocksASingleHarvest() throws {
    var s = Rules.newGame()
    s = try advance(s, task: .plant)
    XCTAssertEqual(s.food, 17)
    var json = try JSONSerialization.jsonObject(with: SaveCodec.encode(s)) as! [String: Any]
    XCTAssertEqual(json["seeds"] as? Int, 4)
    XCTAssertFalse(Rules.taskOptions(s).contains { $0.id == .plant })
    XCTAssertFalse(Rules.taskOptions(s).contains { $0.id == .harvest })
    for _ in 1..<4 { s = try advance(s) }
    s = try advance(s, task: .tend)
    XCTAssertFalse(Rules.taskOptions(s).contains { $0.id == .tend })
    for _ in 5..<24 { s = try advance(s) }
    XCTAssertEqual(s.season, 2)
    XCTAssertEqual(Presentation(state: s).field, "ripe")
    XCTAssertEqual(Rules.preview(try ConstructionTests().assign(s, .ion, .harvest)).foodGain, 28)
    s = try advance(s, task: .harvest)
    XCTAssertEqual(s.food, 27)
    json = try JSONSerialization.jsonObject(with: SaveCodec.encode(s)) as! [String: Any]
    XCTAssertEqual(json["seeds"] as? Int, 10)
    XCTAssertFalse(Rules.taskOptions(s).contains { $0.id == .harvest })
    XCTAssertEqual(Presentation(state: s).field, "harvested")
  }

  func testLateSpringSowingRipensInLastAutumnWeekAndUntendedHarvestReturnsSeeds() throws {
    var s = Rules.newGame()
    s.week = 11
    s = try advance(s, task: .plant)
    XCTAssertEqual(s.cropWeeks, 1)
    XCTAssertEqual(s.calendarLabel, "Summer · Month 1 · Week 1 · 1495")
    for _ in 1..<23 { s = try advance(s) }
    XCTAssertEqual(s.cropWeeks, 23)
    XCTAssertFalse(Farming.canHarvest(s))
    s = try advance(s)
    XCTAssertEqual(s.week, 11)
    XCTAssertEqual(s.cropWeeks, 24)
    XCTAssertTrue(Farming.canHarvest(s))
    XCTAssertEqual(s.nextWeekLabel, "Winter · Month 1 · Week 1 · 1495")
    s = try advance(s, task: .harvest)
    XCTAssertEqual(s.food, 19)
    XCTAssertEqual(s.seeds, 8)
    XCTAssertEqual(s.season, 3)
  }

  func testMissedHarvestIsLostInWinterAndSpringClearsTheField() throws {
    var s = Rules.newGame()
    s.food = 60
    s.house = 100
    s = try advance(s, task: .plant)
    XCTAssertFalse(Farming.canTend(s))
    for _ in 1..<36 { s = try advance(s) }
    XCTAssertEqual(s.season, 3)
    XCTAssertEqual(Farming.stage(s), .snow)
    XCTAssertTrue(Rules.fieldLabel(s).contains("lost"))
    XCTAssertFalse(Farming.canHarvest(s))
    XCTAssertFalse(Farming.canTend(s))
    XCTAssertThrowsError(try ConstructionTests().assign(s, .ion, .harvest))
    for _ in 0..<12 { s = try advance(s) }
    XCTAssertEqual(s.calendarLabel, "Spring · Month 1 · Week 1 · 1496")
    XCTAssertFalse(s.planted)
    XCTAssertEqual(s.cropWeeks, 0)
    XCTAssertEqual(s.seeds, 4)
  }

  func testSeedBuyingRejectsInvalidQuantitiesAndProtectsReservedCoins() throws {
    var s = Rules.newGame()
    s.money = 4
    s = try ConstructionTests().assign(s, .ion, .supplies)
    let reserved = s
    for quantity in [0, -1, 1, 100001, Int.max] {
      XCTAssertThrowsError(try Farming.buySeeds(quantity: quantity, state: &s))
      XCTAssertEqual(s, reserved)
    }
    s.money = 12
    s.seeds = 99999
    try Farming.buySeeds(quantity: 1, state: &s)
    XCTAssertEqual(s.seeds, 100000)
    XCTAssertEqual(s.money, 11)
    let full = s
    XCTAssertThrowsError(try Farming.buySeeds(quantity: 1, state: &s))
    XCTAssertEqual(s, full)
    s = Rules.newGame()
    s.seeds = 3
    XCTAssertNotNil(Rules.assignmentProblem(s, worker: .ion, task: .plant))
    XCTAssertEqual(s.food, 18)
  }

  func testCalendarAndCropSaveValidationRejectsImpossibleAndOverflowingValues() throws {
    let original =
      try JSONSerialization.jsonObject(with: SaveCodec.encode(Rules.newGame())) as! [String: Any]
    for change: [String: Any] in [
      ["week": -1], ["week": 12], ["week": Int.max], ["week": true],
      ["seeds": -1], ["seeds": 100001], ["seeds": true],
      ["cropWeeks": -1], ["cropWeeks": 25], ["cropWeeks": 1],
      ["planted": true, "cropWeeks": 24], ["tended": true], ["harvested": true],
    ] {
      XCTAssertThrowsError(
        try SaveCodec.decode(
          JSONSerialization.data(withJSONObject: original.merging(change) { _, new in new })))
    }
    for key in ["week", "seeds", "cropWeeks"] {
      var incomplete = original
      incomplete.removeValue(forKey: key)
      XCTAssertThrowsError(try SaveCodec.decode(JSONSerialization.data(withJSONObject: incomplete)))
    }
  }
}
