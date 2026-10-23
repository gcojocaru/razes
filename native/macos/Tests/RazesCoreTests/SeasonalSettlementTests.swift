import XCTest

@testable import RazesCore

final class SeasonalSettlementTests: XCTestCase {
  func testConstructionProductionAndWearFollowSeasons() throws {
    var s = Rules.newGame()
    s.money = 100
    try Construction.start(.woodshed, state: &s)
    XCTAssertEqual(s.buildings[0].level, 0)
    Construction.resolveSeason(state: &s)
    XCTAssertEqual(s.buildings[0].level, 1)
    XCTAssertEqual(s.money, 97)
    XCTAssertEqual(s.buildings[0].condition, 100)
    s.season = 1
    Construction.resolveSeason(state: &s)
    XCTAssertEqual(s.money, 98)
    XCTAssertEqual(s.buildings[0].condition, 80)
    try Construction.upgrade(.woodshed, state: &s)
    XCTAssertEqual(s.buildings[0].level, 2)
    XCTAssertEqual(s.buildings[0].condition, 100)
    XCTAssertEqual(s.money, 92)
    s.buildings[0].condition = 3
    try Construction.repair(.woodshed, state: &s)
    XCTAssertEqual(s.buildings[0].condition, 100)
    XCTAssertEqual(s.money, 90)
    s.buildings[0].condition = 10
    Construction.resolveSeason(state: &s)
    XCTAssertEqual(s.buildings[0].level, 1)
    XCTAssertEqual(s.buildings[0].condition, 60)
  }
  func testPostStorySeasonsAndPreviewDoNotRewriteTheYear() throws {
    var s = try XCTUnwrap(Reference.load().runs.first?.steps.last?.state)
    let history = s.history
    let assignments = s.assignments
    s.layout.buildings = [.init(id: .workshop, position: .init(x: 1, y: 1))]
    s.buildings = [.init(id: .workshop, completedSeason: 0, debugPlaced: true)]
    s = try Rules.dispatch(s, action: .init(type: "settlement", revision: s.revision))
    XCTAssertEqual(s.settlementSeasons, 1)
    XCTAssertEqual(s.displaySeason, 0)
    XCTAssertEqual(s.history, history)
    XCTAssertEqual(s.assignments, assignments)
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(s)), s)
    s.debugSeason = 3
    XCTAssertEqual(s.displaySeason, 3)
    XCTAssertEqual(s.season, 3)
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(s)), s)
  }
  func testRoadAndFenceEdgesValidateAndRotate() throws {
    var s = Rules.newGame()
    s.layout.pavement = [.init(x: 1, y: 1)]
    s.layout.fences = [.init(position: .init(x: 1, y: 1), facing: 0)]
    s.layout.viewRotation = 3
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(s)), s)
    s.layout.fences.append(.init(position: .init(x: 1, y: 0), facing: 2))
    XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(s)))
    s.layout.fences.removeLast()
    s.layout.viewRotation = 4
    XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(s)))
    s.layout.viewRotation = 0
    s.layout.pavement = [.init(x: Int.max, y: 0)]
    XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(s)))
  }
}

extension SeasonalSettlementTests {
  func testStorySeasonProducesOnceAndWearCannotChangeItsForecast() throws {
    var s = try ConstructionTests().work()
    s.layout.buildings = [.init(id: .woodshed, position: .init(x: 1, y: 1))]
    s.buildings = [.init(id: .woodshed, completedSeason: 0, debugPlaced: true, condition: 10)]
    // The saved story must advance normally; use a full reference year at winter work.
    let step = try XCTUnwrap(
      Reference.load().runs.flatMap(\.steps).first {
        $0.state.season == 3 && $0.state.phase == .work
      })
    s = step.state
    s.layout.buildings = [.init(id: .woodshed, position: .init(x: 1, y: 1))]
    s.buildings = [.init(id: .woodshed, completedSeason: 0, debugPlaced: true, condition: 10)]
    let forecast = Rules.preview(s)
    s = try Rules.dispatch(s, action: .init(type: "resolve", revision: s.revision))
    let event = Rules.currentEvent(s)
    let choice = try XCTUnwrap(
      event.choices.first { $0.effect.food == nil && $0.effect.money == nil })
    s = try Rules.dispatch(
      s, action: .init(type: "choose", revision: s.revision, event: event.id, choice: choice.id))
    XCTAssertEqual(s.report?.wear, forecast.wear)
    XCTAssertEqual(s.buildings[0].condition, 0)
    XCTAssertEqual(s.money, forecast.moneyAfter)
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(s)), s)
    let original = s
    XCTAssertThrowsError(
      try Rules.dispatch(
        s, action: .init(type: "choose", revision: s.revision, event: event.id, choice: choice.id)))
    XCTAssertEqual(s, original)
  }
}

extension SeasonalSettlementTests {
  func testLaterBuildingIncomeCannotRewriteTheCompletedFirstYear() throws {
    var s = try XCTUnwrap(Reference.load().runs[8].steps.last?.state)
    let original = Rules.ending(s)
    XCTAssertEqual(original.category, "cost")
    s.layout.buildings = [.init(id: .cellar, position: .init(x: 1, y: 1))]
    s.buildings = [.init(id: .cellar, completedSeason: 0, debugPlaced: true)]
    let food = s.food
    s = try Rules.dispatch(s, action: .init(type: "settlement", revision: s.revision))
    XCTAssertEqual(s.food, food + 2)
    XCTAssertEqual(Rules.ending(s), original)
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(s)), s)
  }
}
