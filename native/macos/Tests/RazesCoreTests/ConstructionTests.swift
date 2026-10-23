import XCTest

@testable import RazesCore

final class ConstructionTests: XCTestCase {
  func work() throws -> GameState { Rules.newGame() }
  func assign(_ state: GameState, _ worker: WorkerID, _ task: TaskID) throws -> GameState {
    try Rules.dispatch(
      state, action: .init(type: "assign", revision: state.revision, worker: worker, task: task))
  }
  func testDraftCancelCompletionAndDuplicateConstruction() throws {
    let original = Rules.newGame()
    let draft = try assign(original, .ion, .buildWoodshed)
    XCTAssertEqual(draft.money, original.money)
    XCTAssertTrue(draft.buildings.isEmpty)
    let cancelled = try assign(draft, .ion, .rest)
    XCTAssertEqual(Rules.preview(cancelled).moneyCost, 0)
    XCTAssertEqual(Materials.reserved(cancelled), .init())
    var done = try Rules.dispatch(draft, action: .init(type: "resolve", revision: draft.revision))
    XCTAssertEqual(done.money, 9)
    XCTAssertEqual(done.materials, .init(wood: 2, stone: 4))
    XCTAssertEqual(done.buildings.map(\.id), [.woodshed])
    XCTAssertEqual(done.character.buildingXP, 1)
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(done)), done)
    done = try Rules.dispatch(done, action: .init(type: "continue", revision: done.revision))
    XCTAssertThrowsError(try assign(done, .ion, .buildWoodshed))
  }
  func testCostsCannotUseFutureWagesAndWinterWorkerConstructionIsUnavailable() throws {
    var s = Rules.newGame()
    s.money = 2
    s = try assign(s, .ion, .paid)
    XCTAssertThrowsError(try assign(s, .ion, .buildWoodshed))
    XCTAssertThrowsError(try Construction.start(.woodshed, state: &s))
    s.money = 12
    s.season = 3
    XCTAssertThrowsError(try assign(s, .ion, .buildCellar))
    try Construction.start(.woodshed, state: &s)
    XCTAssertEqual(s.buildings.first?.level, 0)
  }
  func testCellarBenefitBeginsFollowingSeason() throws {
    var initial = Rules.newGame()
    initial.week = 11
    var s = try assign(initial, .ion, .buildCellar)
    XCTAssertEqual(Rules.suppliesGain(s), 7)
    s = try Rules.dispatch(s, action: .init(type: "resolve", revision: s.revision))
    XCTAssertEqual(Rules.suppliesGain(s), 7)
    s = try Rules.dispatch(s, action: .init(type: "continue", revision: s.revision))
    s = try assign(s, .ion, .supplies)
    XCTAssertEqual(Rules.suppliesGain(s), 10)
    XCTAssertEqual(Rules.preview(s).foodGain, 10)
  }
  func testWinterConsumptionAndWeatheringMatchForecastEvenWhenWoodshedWearsOut() throws {
    for woodshed in [false, true] {
      for house in [39, 40] {
        var s = Rules.newGame()
        s.season = 3
        s.week = 11
        s.food = 30
        s.house = house
        if woodshed {
          s.buildings = [.init(id: .woodshed, completedSeason: 1, condition: 10)]
          s.layout.buildings = [.init(id: .woodshed, position: .init(x: 1, y: 1))]
        }
        let p = Rules.preview(s)
        XCTAssertEqual(p.consumption, (woodshed ? 0 : 1) + (house < 40 ? 1 : 0))
        XCTAssertEqual(p.wear, woodshed ? 6 : 14)
        s = try Rules.dispatch(s, action: .init(type: "resolve", revision: s.revision))
        XCTAssertEqual(s.food, p.foodAfter)
        XCTAssertEqual(s.house, p.houseAfter)
        XCTAssertEqual(s.money, p.moneyAfter)
        XCTAssertEqual(s.report?.consumption, p.consumption)
        XCTAssertEqual(s.report?.wear, p.wear)
        XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(s)), s)
      }
    }
  }
}
