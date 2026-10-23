import XCTest

@testable import RazesCore

final class RulesTests: XCTestCase {
  func testStaleActionsAndDuplicateResolutionDoNotApply() throws {
    let s = Rules.newGame()
    XCTAssertThrowsError(try Rules.dispatch(s, action: .init(type: "resolve", revision: 1)))
    XCTAssertThrowsError(try Rules.dispatch(s, action: .init(type: "choose", revision: 0)))
    XCTAssertThrowsError(try Rules.dispatch(s, action: .init(type: "settlement", revision: 0)))
    let summary = try Rules.dispatch(s, action: .init(type: "resolve", revision: 0))
    XCTAssertThrowsError(
      try Rules.dispatch(summary, action: .init(type: "resolve", revision: summary.revision)))
    XCTAssertThrowsError(
      try Rules.dispatch(
        summary,
        action: .init(type: "assign", revision: summary.revision, worker: .ion, task: .paid)))
  }
  func testNeglectedSettlementMatchesForecastsAndRoundTripsUntilDeath() throws {
    var s = Rules.newGame()
    for week in 0..<288 {
      let task: TaskID =
        week < 144 && s.week == 0 ? [.plant, .tend, .harvest, .repair][s.season] : .rest
      s = try ConstructionTests().assign(s, .ion, task)
      XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(s)), s)
      let p = Rules.preview(s)
      s = try Rules.dispatch(s, action: .init(type: "resolve", revision: s.revision))
      XCTAssertEqual(s.food, max(0, p.foodAfter))
      XCTAssertEqual(s.money, p.moneyAfter)
      XCTAssertEqual(s.house, p.houseAfter)
      XCTAssertEqual(s.report?.deficit, max(0, -p.foodAfter))
      XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(s)), s)
      if s.phase == .dead { break }
      s = try Rules.dispatch(s, action: .init(type: "continue", revision: s.revision))
      XCTAssertEqual(s.turn, (week + 1) / 12)
      XCTAssertEqual(s.assignments, ["ion": .rest])
      XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(s)), s)
    }
    XCTAssertEqual(s.phase, .dead)
    XCTAssertEqual(s.character.health, 0)
    XCTAssertThrowsError(
      try Rules.dispatch(s, action: .init(type: "continue", revision: s.revision)))
  }
  func testHarvestCountsOnceWithAndWithoutTending() throws {
    for tended in [false, true] {
      var s = Rules.newGame()
      s.season = 2
      s.planted = true
      s.cropWeeks = 24
      s.tended = tended
      s = try ConstructionTests().assign(s, .ion, .harvest)
      XCTAssertEqual(Rules.preview(s).foodGain, tended ? 28 : 20)
      XCTAssertEqual(Rules.taskOptions(s).first { $0.id == .harvest }?.workers, 1)
      let p = Rules.preview(s)
      s = try Rules.dispatch(s, action: .init(type: "resolve", revision: s.revision))
      XCTAssertEqual(s.food, p.foodAfter)
      XCTAssertTrue(s.harvested)
    }
  }
}
