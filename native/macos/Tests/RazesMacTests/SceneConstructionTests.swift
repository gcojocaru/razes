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
    state.buildings[0].level = 0
    scene.update(state: state, reducedMotion: true)
    XCTAssertNotNil(node.childNode(withName: "work-progress"))
    XCTAssertEqual(scene.completionEffectCount, 0)
  }
}

extension SceneConstructionTests {
  @MainActor func testDirectionalArtAndInfrastructurePersistAcrossRotationAndSeasonPreview() throws
  {
    var s = Rules.newGame()
    for id in BuildingID.allCases {
      s.layout.buildings.append(
        .init(id: id, position: try XCTUnwrap(Settlement.firstAvailable(id, in: s.layout))))
      s.buildings.append(.init(id: id, completedSeason: 0, debugPlaced: true))
    }
    s.layout.pavement = [.init(x: 10, y: 14)]
    s.layout.fences = [.init(position: .init(x: 10, y: 14), facing: 0)]
    let scene = HomesteadScene()
    var pavement: SKNode?
    var fenceChildCount: Int?
    for rotation in 0..<4 {
      s.layout.viewRotation = rotation
      s.debugSeason = rotation
      scene.update(state: s, reducedMotion: true)
      XCTAssertNil(scene.resourceWarning)
      for id in BuildingID.allCases {
        let node = try XCTUnwrap(
          scene.childNode(withName: "//plot-\(id.rawValue)") as? SKSpriteNode)
        XCTAssertNotNil(node.texture)
        XCTAssertEqual(node.childNode(withName: "level-badge")?.xScale, 1)
      }
      let road = try XCTUnwrap(scene.childNode(withName: "//p:10:14"))
      if let pavement { XCTAssertTrue(road === pavement) } else { pavement = road }
      XCTAssertEqual(road.position, IsometricLayout.point(column: 10, row: 14, rotation: rotation))
      let fence = try XCTUnwrap(scene.childNode(withName: "//f:h:10:14"))
      XCTAssertGreaterThan(fence.children.count, 0)
      if let fenceChildCount {
        XCTAssertEqual(fence.children.count, fenceChildCount)
      } else {
        fenceChildCount = fence.children.count
      }
      scene.enumerateChildNodes(withName: "//*") { node, _ in XCTAssertFalse(node.hasActions()) }
    }
    s.layout.pavement = []
    s.layout.fences = []
    scene.update(state: s, reducedMotion: true)
    XCTAssertNil(scene.childNode(withName: "//p:10:14"))
    XCTAssertNil(scene.childNode(withName: "//f:h:10:14"))
  }
  @MainActor func testPaintingFillsSkippedCellsInRotatedViewsWithoutDoubleCharging() {
    for rotation in 0..<4 {
      let session = GameSession(store: nil)
      session.rotateView(rotation)
      let scene = HomesteadScene()
      scene.update(state: session.state, reducedMotion: true)
      scene.onPlacement = { tool, point in
        if case .infrastructure(let kind) = tool {
          session.placeInfrastructure(kind, at: point)
          scene.update(state: session.state, reducedMotion: true)
        }
      }
      scene.setPlacement(.infrastructure(.pavement))
      scene.paintInfrastructure(IsometricLayout.point(column: 1, row: 1, rotation: rotation))
      scene.paintInfrastructure(IsometricLayout.point(column: 4, row: 3, rotation: rotation))
      scene.paintInfrastructure(IsometricLayout.point(column: 4, row: 3, rotation: rotation))
      XCTAssertEqual(session.state.layout.pavement.count, 6)
      XCTAssertEqual(session.state.money, 6)
    }
  }
}
