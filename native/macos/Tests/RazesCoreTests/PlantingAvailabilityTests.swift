import XCTest

@testable import RazesCore

final class PlantingAvailabilityTests: XCTestCase {
  func testClosedSeasonsExplainThatPlantingReopensInSpring() throws {
    for season in 1...3 {
      var state = Rules.newGame()
      state.season = season
      let reason = try XCTUnwrap(Rules.assignmentProblem(state, worker: .ion, task: .plant))
      XCTAssertTrue(reason.contains("Spring"), reason)
      XCTAssertTrue(reason.contains("next"), reason)
      XCTAssertThrowsError(
        try Rules.dispatch(
          state, action: .init(type: "assign", revision: state.revision, worker: .ion, task: .plant)
        ))
    }
  }

  func testAlreadyPlantedExplainsNextSpringInsteadOfSuggestingNextWeek() throws {
    var state = Rules.newGame()
    state = try HarvestCalendarTests().advance(state, task: .plant)
    let reason = try XCTUnwrap(Rules.assignmentProblem(state, worker: .ion, task: .plant))
    XCTAssertTrue(reason.contains("already planted"), reason)
    XCTAssertTrue(reason.contains("next Spring"), reason)
  }

  func testLastSpringReportDoesNotPromisePlantingNextWeek() throws {
    var state = Rules.newGame()
    state.week = 11
    state = try Rules.dispatch(state, action: .init(type: "resolve", revision: state.revision))
    let reason = try XCTUnwrap(Rules.assignmentProblem(state, worker: .ion, task: .plant))
    XCTAssertTrue(reason.contains("next Spring"), reason)
  }

  func testEverySpringWeekAllowsPlantingWhenRequirementsAreMet() throws {
    for week in 0..<12 {
      var state = Rules.newGame()
      state.week = week
      XCTAssertNil(Rules.assignmentProblem(state, worker: .ion, task: .plant))
    }
    var state = Rules.newGame()
    state.layout.farmland = []
    XCTAssertTrue(
      try XCTUnwrap(Rules.assignmentProblem(state, worker: .ion, task: .plant)).contains("farmland")
    )
    state = Rules.newGame()
    state.seeds = 3
    let reason = try XCTUnwrap(Rules.assignmentProblem(state, worker: .ion, task: .plant))
    XCTAssertTrue(reason.contains("4"), reason)
    XCTAssertTrue(reason.contains("seeds"), reason)
  }
}
