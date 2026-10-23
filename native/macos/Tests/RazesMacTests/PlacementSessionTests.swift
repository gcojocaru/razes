import RazesCore
import XCTest

@testable import RazesMac

final class PlacementSessionTests: XCTestCase {
  @MainActor func testPlacedDraftAndSceneryPersistAndInvalidPlacementPreservesRevision() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = SaveStore(url: directory.appendingPathComponent("save.json"))
    let session = GameSession(store: store)
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
    session.send(.init(type: "assign", revision: 0, worker: .ion, task: .buildWoodshed))
    session.finishConstruction(.woodshed)
    XCTAssertEqual(session.state.phase, .work)
    XCTAssertEqual(session.state.money, 12)
    XCTAssertEqual(session.state.assignments["ion"], .rest)
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
  @MainActor func testSeasonalFoundationCompletesInSpringWithoutAClock() {
    let session = GameSession(store: nil)
    session.placeBuilding(.cellar, at: .init(x: 1, y: 1))
    session.send(.init(type: "resolve", revision: session.state.revision))
    session.send(.init(type: "continue", revision: session.state.revision))
    XCTAssertEqual(session.state.season, 1)
    session.finishConstruction(.cellar)
    XCTAssertEqual(session.state.buildings.first?.completedSeason, 0)
    XCTAssertTrue(Construction.active(.cellar, state: session.state))
  }
}

extension PlacementSessionTests {
  @MainActor func testDirtAndWattleShareOccupancyCostsAndEraseWithExistingMaterials() throws {
    let dirt = try XCTUnwrap(InfrastructureKind(rawValue: "dirtPath"))
    let wattle = try XCTUnwrap(InfrastructureKind(rawValue: "wattleFence"))
    let session = GameSession(store: nil)
    XCTAssertTrue(session.placeInfrastructure(dirt, at: .init(x: 1, y: 1)))
    XCTAssertTrue(session.placeInfrastructure(wattle, at: .init(x: 1, y: 1), facing: 0))
    XCTAssertEqual(session.state.money, 10)
    let before = session.state
    XCTAssertFalse(session.placeInfrastructure(.pavement, at: .init(x: 1, y: 1)))
    XCTAssertFalse(session.placeInfrastructure(.fence, at: .init(x: 1, y: 0), facing: 2))
    XCTAssertFalse(session.placeBuilding(.woodshed, at: .init(x: 1, y: 1), instant: true))
    XCTAssertFalse(session.placeInfrastructure(dirt, at: Settlement.house))
    XCTAssertFalse(session.placeInfrastructure(wattle, at: .init(x: 16, y: 0)))
    XCTAssertEqual(session.state, before)
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(before)), before)
    XCTAssertTrue(session.placeInfrastructure(.erase, at: .init(x: 1, y: 1)))
    XCTAssertTrue(session.placeInfrastructure(.pavement, at: .init(x: 1, y: 1)))
    XCTAssertTrue(session.placeInfrastructure(.fence, at: .init(x: 1, y: 0), facing: 2))
    XCTAssertEqual(session.state.money, 8)
  }
  @MainActor func testInfrastructureCostsSharedEdgesEraseAndSeasonPreviewPersist() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let store = SaveStore(url: dir.appendingPathComponent("save.json"))
    let session = GameSession(store: store)
    XCTAssertTrue(session.placeInfrastructure(.pavement, at: .init(x: 1, y: 1)))
    XCTAssertTrue(session.placeInfrastructure(.fence, at: .init(x: 1, y: 1), facing: 0))
    XCTAssertEqual(session.state.money, 10)
    let before = session.state
    XCTAssertFalse(session.placeInfrastructure(.fence, at: .init(x: 1, y: 0), facing: 2))
    XCTAssertEqual(session.state, before)
    session.rotateView(1)
    session.previewSeason(3)
    XCTAssertEqual(session.state.season, 0)
    XCTAssertEqual(session.state.displaySeason, 3)
    XCTAssertEqual(session.state.assignments, before.assignments)
    XCTAssertEqual(session.state.layout.viewRotation, 1)
    XCTAssertEqual(try store.load(), session.state)
    XCTAssertTrue(session.placeInfrastructure(.erase, at: .init(x: 1, y: 1)))
    XCTAssertTrue(session.state.layout.pavement.isEmpty)
    XCTAssertTrue(session.state.layout.fences.isEmpty)
    session.placeBuilding(.woodshed, at: .init(x: 2, y: 2), instant: true, facing: 3)
    session.rotateBuilding(.woodshed)
    XCTAssertEqual(session.state.layout.buildings[0].facing, 0)
    XCTAssertEqual(try store.load(), session.state)
  }
}

extension PlacementSessionTests {
  @MainActor func testRotatedSceneryFootprintAgreesWithPreviewAndRejectsOutOfBoundsRotation() {
    let session = GameSession(store: nil)
    XCTAssertTrue(session.placeScenery(.fence, at: .init(x: 15, y: 14), facing: 1))
    let original = session.state
    session.rotateScenery(session.state.layout.scenery[0].id)
    XCTAssertEqual(session.state, original)
    let scene = HomesteadScene()
    session.rotateView(3)
    scene.update(state: session.state, reducedMotion: true)
    scene.placementFacing = 1
    let center = IsometricLayout.center(
      .init(x: 15, y: 14), kind: .scenery(.fence), facing: 1, rotation: 3)
    XCTAssertEqual(scene.placementPosition(at: center, kind: .scenery(.fence)), .init(x: 15, y: 14))
  }
}
