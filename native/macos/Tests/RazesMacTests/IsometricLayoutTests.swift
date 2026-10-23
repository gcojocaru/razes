import RazesCore
import XCTest

@testable import RazesMac

final class IsometricLayoutTests: XCTestCase {
  func testProjectionHasTwoToOneAxesAndRoundTrips() {
    let origin = IsometricLayout.point(column: 0, row: 0)
    let right = IsometricLayout.point(column: 1, row: 0)
    let left = IsometricLayout.point(column: 0, row: 1)
    XCTAssertEqual(right.x - origin.x, 66)
    XCTAssertEqual(origin.y - right.y, 33)
    XCTAssertEqual(origin.x - left.x, 66)
    XCTAssertEqual(origin.y - left.y, 33)
    for c in 0..<8 {
      for r in 0..<8 {
        let point = IsometricLayout.point(column: CGFloat(c), row: CGFloat(r))
        let grid = IsometricLayout.grid(at: point)
        XCTAssertEqual(grid.x, CGFloat(c), accuracy: 0.001)
        XCTAssertEqual(grid.y, CGFloat(r), accuracy: 0.001)
      }
    }
  }
  @MainActor func testRepairToolSharesWorkerDepthRatherThanHandHeight() throws {
    var state = Rules.newGame()
    state.assignments["ion"] = .repair
    state.phase = .work
    let scene = HomesteadScene()
    scene.update(state: state, reducedMotion: false)
    let tool = try XCTUnwrap(scene.childNode(withName: "//tool-ion"))
    let person = try XCTUnwrap(scene.childNode(withName: "//worker-ion"))
    let house = try XCTUnwrap(scene.childNode(withName: "//house"))
    XCTAssertGreaterThan(tool.zPosition, person.zPosition)
    XCTAssertGreaterThan(tool.zPosition, house.zPosition)
  }
  @MainActor func testMovingAssignedPlotMovesItsToolAndDust() throws {
    let session = GameSession(store: nil)
    session.send(.init(type: "assign", revision: 0, worker: .ion, task: .buildWoodshed))
    let scene = HomesteadScene()
    scene.update(state: session.state, reducedMotion: false)
    let old = try XCTUnwrap(scene.childNode(withName: "//tool-ion")?.position)
    session.placeBuilding(.woodshed, at: .init(x: 1, y: 1))
    scene.update(state: session.state, reducedMotion: false)
    let tool = try XCTUnwrap(scene.childNode(withName: "//tool-ion"))
    let worker = try XCTUnwrap(scene.childNode(withName: "//worker-ion"))
    XCTAssertNotEqual(tool.position, old)
    XCTAssertEqual(tool.position.x, worker.position.x + 15, accuracy: 0.001)
    XCTAssertGreaterThan(tool.zPosition, worker.zPosition)
  }
  @MainActor func testResourceFeedbackIsInsideTheCurrentCamera() throws {
    let scene = HomesteadScene()
    var state = Rules.newGame()
    scene.update(state: state, reducedMotion: false)
    scene.panCamera(x: 100, y: -100)
    scene.zoomCamera(0.8)
    state.revision += 1
    state.money += 2
    scene.update(state: state, reducedMotion: false)
    let feedback = try XCTUnwrap(scene.childNode(withName: "//resource-feedback"))
    XCTAssertLessThan(
      feedback.position.y,
      scene.cameraState.center.y + scene.size.height * scene.cameraState.scale / 2)
    XCTAssertGreaterThan(
      feedback.position.y,
      scene.cameraState.center.y - scene.size.height * scene.cameraState.scale / 2)
  }
  @MainActor func testDraggingDoesNotCommitAPlacement() throws {
    let scene = HomesteadScene()
    scene.update(state: Rules.newGame(), reducedMotion: true)
    scene.setPlacement(.scenery(.well))
    var placements = 0
    scene.onPlacement = { _, _ in placements += 1 }
    func event(_ type: NSEvent.EventType, _ point: CGPoint) throws -> NSEvent {
      try XCTUnwrap(
        NSEvent.mouseEvent(
          with: type, location: point, modifierFlags: [], timestamp: 0, windowNumber: 0,
          context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
    }
    let before = scene.cameraState.center
    scene.beginPan(try event(.leftMouseDown, .init(x: 600, y: 300)))
    scene.continuePan(try event(.leftMouseDragged, .init(x: 650, y: 350)))
    scene.finishPan(try event(.leftMouseUp, .init(x: 650, y: 350)))
    XCTAssertEqual(placements, 0)
    XCTAssertNotEqual(scene.cameraState.center, before)
    XCTAssertNil(scene.dragStart)
  }
  @MainActor func testOverlappingTargetsFollowVisibleDepth() {
    var state = Rules.newGame()
    state.layout.buildings = [.init(id: .woodshed, position: .init(x: 7, y: 4))]
    state.buildings = [.init(id: .woodshed, completedSeason: 0, debugPlaced: true)]
    let scene = HomesteadScene()
    scene.update(state: state, reducedMotion: true)
    XCTAssertEqual(scene.selection(at: CGPoint(x: 710, y: 300)), .hotspot(.house))
  }
  @MainActor func testNewSettlementHasOnlyHouseAndPlacementRejectsOccupiedGround() {
    let scene = HomesteadScene()
    var state = Rules.newGame()
    state.phase = .work
    scene.update(state: state, reducedMotion: true)
    XCTAssertNil(scene.childNode(withName: "//scenery-legacy-barn"))
    XCTAssertTrue(scene.childNode(withName: "//field")?.isHidden == true)
    var placed: GridPosition?
    scene.onPlacement = { _, point in placed = point }
    scene.setPlacement(.building(.woodshed, worker: nil, instant: false))
    scene.commitPlacement(at: IsometricLayout.center(.init(x: 6, y: 6), kind: .building(.woodshed)))
    XCTAssertNil(placed)
    scene.commitPlacement(at: IsometricLayout.center(.init(x: 1, y: 1), kind: .building(.woodshed)))
    XCTAssertEqual(placed, .init(x: 1, y: 1))
  }
  @MainActor func testHouseholdIsDepthSortedOnAnIsometricGroundPlane() {
    let scene = HomesteadScene()
    scene.update(state: Rules.newGame(), reducedMotion: true)
    for name in ["backdrop", "terrain", "world", "weather", "smoke", "selection", "feedback"] {
      XCTAssertNotNil(scene.childNode(withName: name))
    }
    let terrain = scene.childNode(withName: "terrain")
    let world = scene.childNode(withName: "world")
    scene.select(.building(.woodshed), buildMode: true)
    XCTAssertTrue(scene.childNode(withName: "terrain") === terrain)
    XCTAssertTrue(scene.childNode(withName: "world") === world)
    XCTAssertNotNil(scene.childNode(withName: "//isometric-ground"))
    let house = scene.childNode(withName: "//house")!
    let field = scene.childNode(withName: "//field")!
    XCTAssertGreaterThan(field.zPosition, house.zPosition)
    XCTAssertEqual(scene.childNode(withName: "//plot-woodshed")?.position, IsometricLayout.woodshed)
  }
}

extension IsometricLayoutTests {
  func testAllFourRotationsRoundTripEveryGridCorner() {
    for rotation in 0..<4 {
      for column in [-0.5, 0, 7.5, 15, 15.5] {
        for row in [-0.5, 0, 7.5, 15, 15.5] {
          let point = IsometricLayout.point(column: column, row: row, rotation: rotation)
          let grid = IsometricLayout.grid(at: point, rotation: rotation)
          XCTAssertEqual(grid.x, column, accuracy: 0.00001)
          XCTAssertEqual(grid.y, row, accuracy: 0.00001)
        }
      }
    }
  }
  @MainActor func testRotationMovesGroundBuildingsAndInversePlacementTogether() throws {
    let scene = HomesteadScene()
    var s = Rules.newGame()
    s.layout.buildings = [.init(id: .woodshed, position: .init(x: 1, y: 2), facing: 1)]
    s.buildings = [.init(id: .woodshed, completedSeason: 0, debugPlaced: true)]
    for rotation in 0..<4 {
      s.layout.viewRotation = rotation
      scene.update(state: s, reducedMotion: true)
      let building = try XCTUnwrap(scene.childNode(withName: "//plot-woodshed"))
      let expected = IsometricLayout.center(
        .init(x: 1, y: 2), width: 2, height: 2, rotation: rotation)
      XCTAssertEqual(building.position, expected)
      XCTAssertEqual(
        scene.placementPosition(at: expected, kind: .building(.woodshed)), .init(x: 1, y: 2))
      let tile = try XCTUnwrap(scene.childNode(withName: "//tile-0-0"))
      XCTAssertEqual(
        tile.position, IsometricLayout.point(column: -0.25, row: -0.25, rotation: rotation))
      XCTAssertEqual(building.zPosition, 1000 - expected.y)
    }
  }
}
