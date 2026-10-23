import XCTest

@testable import RazesCore

final class ConstructionTests: XCTestCase {
  func work() throws -> GameState {
    try Rules.dispatch(
      Rules.newGame(),
      action: Action(type: "choose", revision: 0, event: "spring-ox", choice: "borrow"))
  }
  func assign(_ state: GameState, _ worker: WorkerID, _ task: TaskID) throws -> GameState {
    try Rules.dispatch(
      state, action: Action(type: "assign", revision: state.revision, worker: worker, task: task))
  }
  func testDraftCancelCompletionAndDuplicateConstruction() throws {
    let original = try work()
    let draft = try assign(original, .ion, .buildWoodshed)
    XCTAssertEqual(draft.money, original.money)
    XCTAssertTrue(draft.buildings.isEmpty)
    XCTAssertThrowsError(try assign(draft, .ana, .buildWoodshed))
    let cancelled = try assign(draft, .ion, .rest)
    XCTAssertEqual(Rules.preview(cancelled).moneyCost, 0)
    let both = try assign(draft, .ana, .buildCellar)
    XCTAssertEqual(Rules.preview(both).moneyCost, 7)
    let done = try Rules.dispatch(both, action: Action(type: "resolve", revision: both.revision))
    XCTAssertEqual(done.money, original.money - 7)
    XCTAssertEqual(Set(done.buildings.map(\.id)), [.woodshed, .cellar])
    XCTAssertEqual(done.buildings.map(\.completedSeason), [0, 0])
    XCTAssertThrowsError(
      try Rules.dispatch(done, action: Action(type: "resolve", revision: done.revision)))
  }
  func testCostsCannotUseFutureWagesAndWinterOrReservedWorkersCannotBuild() throws {
    var state = try work()
    state.money = 2
    let wages = try assign(state, .ana, .paid)
    XCTAssertThrowsError(try assign(wages, .ion, .buildWoodshed))
    state.money = 12
    state.season = 3
    XCTAssertThrowsError(try assign(state, .ion, .buildCellar))
    state.season = 2
    state.reservedWorker = "petru"
    XCTAssertThrowsError(try assign(state, .petru, .buildCellar))
    state.buildings = [BuildingRecord(id: .woodshed, completedSeason: 0)]
    XCTAssertThrowsError(try assign(state, .ion, .buildWoodshed))
  }
  func testCellarBeginsFollowingSeasonAndAppliesToEveryPurchase() throws {
    var state = try work()
    state = try assign(state, .ion, .buildCellar)
    state = try assign(state, .ana, .supplies)
    XCTAssertEqual(Rules.preview(state).foodGain, 7)
    let done = try Rules.dispatch(state, action: Action(type: "resolve", revision: state.revision))
    XCTAssertEqual(done.food, state.food + 7)
    state = done
    state.phase = .work
    state.season = 1
    state.assignments = ["ion": .supplies, "ana": .supplies, "petru": .paid]
    state.money = 12
    XCTAssertEqual(Rules.preview(state).foodGain, 20)
    XCTAssertEqual(Rules.suppliesGain(state), 10)
  }
  func testWoodshedWinterForecastMatchesEveningSettlement() throws {
    for sheltered in [false, true] {
      var state = try work()
      state.season = 3
      state.food = 30
      state.house = sheltered ? 40 : 39
      state.buildings = [BuildingRecord(id: .woodshed, completedSeason: 1)]
      let forecast = Rules.preview(state)
      XCTAssertEqual(forecast.consumption, sheltered ? 6 : 9)
      XCTAssertEqual(forecast.wear, 6)
      let resolved = try Rules.dispatch(
        state, action: Action(type: "resolve", revision: state.revision))
      let event = Rules.currentEvent(resolved)
      let summary = try Rules.dispatch(
        resolved,
        action: Action(
          type: "choose", revision: resolved.revision, event: event.id, choice: "together"))
      XCTAssertEqual(summary.food, forecast.foodAfter)
      XCTAssertEqual(summary.house, forecast.houseAfter)
      XCTAssertEqual(summary.report?.consumption, forecast.consumption)
      XCTAssertEqual(summary.report?.wear, forecast.wear)
      state.buildings = []
      XCTAssertEqual(Rules.preview(state).consumption, sheltered ? 9 : 12)
      XCTAssertEqual(Rules.weathering(state), 14)
    }
  }
}

extension ConstructionTests {
  func testCompleteConstructionYearsSaveEveryAcceptedStep() throws {
    for route in ["borrow", "pay", "decline"] {
      var state = Rules.newGame()
      func act(
        _ type: String, event: String? = nil, choice: String? = nil, worker: WorkerID? = nil,
        task: TaskID? = nil
      ) throws {
        state = try Rules.dispatch(
          state,
          action: Action(
            type: type, revision: state.revision, event: event, choice: choice, worker: worker,
            task: task))
        XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(state)), state)
      }
      for season in 0..<4 {
        let opening = Rules.currentEvent(state)
        let choice =
          season == 0
          ? route
          : season == 1
            ? "listen"
            : season == 2 && route == "borrow" ? "honour" : season == 3 ? "ask" : "prepare"
        try act("choose", event: opening.id, choice: choice)
        let tasks: [TaskID] =
          season == 0
          ? [.plant, .buildWoodshed, .paid]
          : season == 1
            ? [.tend, .buildCellar, .supplies]
            : season == 2 ? [.harvest, .harvest, .paid] : [.repair, .supplies, .paid]
        for (worker, task) in zip(WorkerID.allCases, tasks)
        where state.reservedWorker != worker.rawValue {
          try act("assign", worker: worker, task: task)
        }
        let forecast = Rules.preview(state)
        XCTAssertTrue(forecast.errors.isEmpty)
        try act("resolve")
        let evening = Rules.currentEvent(state)
        let response =
          evening.choices.first { $0.effect.food == nil && $0.effect.money == nil }
          ?? evening.choices[0]
        try act("choose", event: evening.id, choice: response.id)
        XCTAssertEqual(state.house, forecast.houseAfter)
        try act("continue")
      }
      XCTAssertEqual(state.phase, .ending)
      XCTAssertEqual(state.buildings.count, 2)
      XCTAssertEqual(state.report?.wear, 6)
      XCTAssertEqual(state.report?.consumption, 6)
    }
  }
}
