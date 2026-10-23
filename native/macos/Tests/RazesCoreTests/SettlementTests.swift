import XCTest

@testable import RazesCore

final class SettlementTests: XCTestCase {
  func testFootprintsRejectBoundsAndOccupiedCells() {
    var layout = SettlementLayout()
    XCTAssertNotNil(
      Settlement.problem(.building(.woodshed), at: .init(x: -1, y: 0), layout: layout))
    XCTAssertNotNil(
      Settlement.problem(.building(.woodshed), at: .init(x: 15, y: 15), layout: layout))
    XCTAssertNotNil(Settlement.problem(.building(.woodshed), at: .init(x: 6, y: 6), layout: layout))
    XCTAssertNotNil(
      Settlement.problem(.building(.woodshed), at: .init(x: 5, y: 10), layout: layout))
    XCTAssertNil(Settlement.problem(.building(.woodshed), at: .init(x: 1, y: 1), layout: layout))
    layout.scenery = [.init(kind: .well, position: .init(x: 1, y: 1))]
    XCTAssertNotNil(Settlement.problem(.building(.woodshed), at: .init(x: 1, y: 1), layout: layout))
  }
  func testOutOfRangeLaterStructureIsRejectedBeforeOccupancyMath() throws {
    var state = Rules.newGame()
    state.layout.buildings = [.init(id: .woodshed, position: .init(x: 1, y: 1))]
    state.layout.scenery = [.init(kind: .barn, position: .init(x: Int.max, y: Int.max))]
    XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(state)))
    state.layout.scenery[0].position = .init(x: Int.min, y: Int.min)
    XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(state)))
  }
  func testLayoutAndDebugCompletionRoundTrip() throws {
    var state = Rules.newGame()
    XCTAssertTrue(state.layout.scenery.isEmpty)
    state.layout.buildings = [.init(id: .woodshed, position: .init(x: 1, y: 1))]
    state.buildings = [.init(id: .woodshed, completedSeason: 0, debugPlaced: true)]
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(state)), state)
    XCTAssertFalse(Construction.active(.woodshed, state: state))
    var invalid = state
    invalid.layout.buildings.append(.init(id: .cellar, position: .init(x: 1, y: 1)))
    XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(invalid)))
    invalid = state
    invalid.layout.buildings = []
    XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(invalid)))
  }

  func testWinterDebugCompletionDoesNotRewritePastConsumption() throws {
    var state = Rules.newGame()
    state.season = 3
    XCTAssertEqual(state.season, 3)
    state.layout.buildings = [.init(id: .woodshed, position: .init(x: 1, y: 1))]
    state.buildings = [.init(id: .woodshed, completedSeason: 3, debugPlaced: true)]
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(state)), state)
    XCTAssertFalse(Construction.active(.woodshed, state: state))
  }
}
