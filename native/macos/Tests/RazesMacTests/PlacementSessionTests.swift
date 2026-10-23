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
    XCTAssertEqual(session.state.money, 9)
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

extension PlacementSessionTests {
  @MainActor func testRealTimePlacementUpgradeAndSavedClockSurviveRelaunch() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = SaveStore(url: directory.appendingPathComponent("save.json"))
    let session = GameSession(store: store)
    session.tick(now: 1000)
    XCTAssertTrue(session.placeBuilding(.workshop, at: .init(x: 1, y: 1)))
    XCTAssertEqual(session.state.money, 7)
    XCTAssertEqual(session.state.buildings.first?.level, 0)
    session.tick(now: 1050)
    XCTAssertEqual(session.state.buildings.first?.level, 1)
    let resumed = GameSession(store: store)
    XCTAssertEqual(resumed.state, session.state)
    resumed.tick(now: 1110)
    XCTAssertEqual(resumed.state.money, 9)
    let before = resumed.state
    resumed.upgradeBuilding(.workshop)
    XCTAssertNotNil(resumed.error)
    XCTAssertEqual(resumed.state, before)
    resumed.debugResources()
    resumed.upgradeBuilding(.workshop)
    resumed.tick(now: 1230)
    XCTAssertEqual(resumed.state.buildings.first?.level, 2)
    XCTAssertEqual(try store.load(), resumed.state)
    resumed.debugSetBuilding(.workshop, level: 5, condition: 4)
    resumed.debugAdvance(3600)
    XCTAssertEqual(resumed.state.buildings.first?.level, 4)
    XCTAssertEqual(resumed.state.buildings.first?.condition, 60)
    resumed.repairBuilding(.workshop)
    resumed.tick(now: 1250)
    XCTAssertEqual(resumed.state.buildings.first?.condition, 100)
    XCTAssertEqual(try store.load(), resumed.state)
  }
}

extension PlacementSessionTests {
  @MainActor func testDebugFinishUsesCurrentCompletionSeason() {
    let session = GameSession(store: nil)
    session.send(.init(type: "choose", revision: 0, event: "spring-ox", choice: "borrow"))
    session.placeBuilding(.cellar, at: .init(x: 1, y: 1))
    session.send(.init(type: "resolve", revision: session.state.revision))
    session.send(
      .init(type: "choose", revision: session.state.revision, event: "spring-table", choice: "keep")
    )
    session.send(.init(type: "continue", revision: session.state.revision))
    XCTAssertEqual(session.state.season, 1)
    session.finishConstruction(.cellar)
    XCTAssertEqual(session.state.buildings.first?.completedSeason, 1)
    XCTAssertFalse(Construction.active(.cellar, state: session.state))
  }
}
