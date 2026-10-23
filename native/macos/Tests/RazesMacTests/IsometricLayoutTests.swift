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
  @MainActor func testOverlappingTargetsFollowVisibleDepth() {
    let scene = HomesteadScene()
    scene.update(state: Rules.newGame(), reducedMotion: true)
    XCTAssertEqual(scene.selection(at: CGPoint(x: 590, y: 486)), .hotspot(.field))
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
