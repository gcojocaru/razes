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

extension SceneConstructionTests {
  @MainActor func testTenBuildingTypesShowLevelsWearAndTimersWithoutGrowingNodes() throws {
    var state = Rules.newGame()
    for id in BuildingID.allCases {
      let position = try XCTUnwrap(Settlement.firstAvailable(id, in: state.layout))
      state.layout.buildings.append(.init(id: id, position: position))
      state.buildings.append(.init(id: id, completedSeason: 0, debugPlaced: true))
    }
    let scene = HomesteadScene()
    scene.update(state: state, reducedMotion: true)
    XCTAssertNil(scene.resourceWarning)
    for id in BuildingID.allCases {
      let node = try XCTUnwrap(scene.childNode(withName: "//plot-\(id.rawValue)") as? SKSpriteNode)
      XCTAssertFalse(node.isHidden)
      XCTAssertNotNil(node.texture)
      XCTAssertNotNil(node.childNode(withName: "level-badge"))
    }
    let node = try XCTUnwrap(scene.childNode(withName: "//plot-woodshed"))
    let count = node.children.count
    for level in 1...5 {
      state.buildings[0].level = level
      state.buildings[0].condition = Double(level * 10)
      scene.update(state: state, reducedMotion: true)
      let label = try XCTUnwrap(node.childNode(withName: "level-badge") as? SKLabelNode)
      XCTAssertTrue(label.text?.contains("\(level)") == true)
      XCTAssertEqual(node.children.count, count)
    }
    state.buildings[0].work = BuildingWork(kind: .repair, duration: 20)
    scene.update(state: state, reducedMotion: true)
    XCTAssertNotNil(node.childNode(withName: "work-progress"))
    XCTAssertEqual(scene.completionEffectCount, 0)
  }
}
