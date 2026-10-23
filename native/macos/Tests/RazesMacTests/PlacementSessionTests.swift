import RazesCore
import XCTest

@testable import RazesMac

final class PlacementSessionTests: XCTestCase {
  @MainActor func testPlacedDraftAndSceneryPersistAndInvalidPlacementPreservesRevision() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = SaveStore(url: directory.appendingPathComponent("save.json"))
    let session = GameSession(store: store)
    session.send(.init(type: "choose", revision: 0, event: "spring-ox", choice: "borrow"))
    session.placeBuilding(.woodshed, at: .init(x: 1, y: 1))
    session.placeScenery(.well, at: .init(x: 12, y: 12))
    let before = session.state
    session.placeBuilding(.cellar, at: .init(x: 1, y: 1))
    XCTAssertNotNil(session.error)
    XCTAssertEqual(session.state, before)
    XCTAssertEqual(GameSession(store: store).state, before)
    XCTAssertEqual(session.state.money, 12)
  }
  @MainActor func testDebugFinishesWithoutResolvingSeasonOrChargingAndRemovePlanCancelsBuilder()
    throws
  {
    let session = GameSession(store: nil)
    session.send(.init(type: "choose", revision: 0, event: "spring-ox", choice: "borrow"))
    session.send(.init(type: "assign", revision: 1, worker: .ana, task: .buildWoodshed))
    session.finishConstruction(.woodshed)
    XCTAssertEqual(session.state.phase, .work)
    XCTAssertEqual(session.state.money, 12)
    XCTAssertEqual(session.state.assignments["ana"], .rest)
    XCTAssertEqual(session.state.buildings.first?.debugPlaced, true)
    XCTAssertFalse(Construction.active(.woodshed, state: session.state))
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(session.state)), session.state)
    session.send(
      .init(type: "assign", revision: session.state.revision, worker: .ion, task: .buildCellar))
    session.removePlan(.cellar)
    XCTAssertEqual(session.state.assignments["ion"], .rest)
    XCTAssertNil(Settlement.position(for: .cellar, in: session.state.layout))
  }
}
