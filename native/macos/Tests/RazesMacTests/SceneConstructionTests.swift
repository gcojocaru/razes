import AppKit
import RazesCore
import SpriteKit
import XCTest

@testable import RazesMac

final class SceneConstructionTests: XCTestCase {
  @MainActor func testSelectionAndAssignmentPreserveWeatherAndLoadDoesNotReplayCompletion() throws {
    let scene = HomesteadScene()
    let state = Rules.newGame()
    scene.update(state: state, reducedMotion: false)
    let weather = try XCTUnwrap(scene.childNode(withName: "weather"))
    scene.select(.building(.woodshed), buildMode: true)
    XCTAssertTrue(scene.childNode(withName: "weather") === weather)
    var completed = state
    completed.buildings = [BuildingRecord(id: .woodshed, completedSeason: 0)]
    completed.phase = .consequence
    scene.update(state: completed, reducedMotion: false)
    XCTAssertEqual(scene.completionEffectCount, 1)
    scene.update(state: completed, reducedMotion: false)
    XCTAssertEqual(scene.completionEffectCount, 1)
    let resumed = HomesteadScene()
    resumed.update(state: completed, reducedMotion: false)
    XCTAssertEqual(resumed.completionEffectCount, 0)
    XCTAssertNil(resumed.resourceWarning)
    for id in BuildingID.allCases {
      XCTAssertNotNil(resumed.childNode(withName: "//plot-\(id.rawValue)"))
    }
  }
  @MainActor func testReducedMotionAndSameRevisionSelectionDoNotReplayEffects() {
    let scene = HomesteadScene()
    let state = Rules.newGame()
    scene.update(state: state, reducedMotion: true)
    scene.select(.worker(.ion), buildMode: false)
    scene.enumerateChildNodes(withName: "//*") { node, _ in
      XCTAssertFalse(node.hasActions(), node.name ?? "unnamed node")
    }
    XCTAssertEqual(scene.completionEffectCount, 0)
  }
}
