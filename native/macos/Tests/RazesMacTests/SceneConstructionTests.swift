import AppKit
import RazesCore
import SpriteKit
import XCTest

@testable import RazesMac

final class SceneConstructionTests: XCTestCase {
  @MainActor func testDeathStopsWorkerAndToolAnimationInEveryMotionMode() throws {
    var state = Rules.newGame()
    state.assignments["ion"] = .repair
    for reduced in [false, true] {
      let scene = HomesteadScene()
      scene.update(state: state, reducedMotion: reduced)
      var dead = state
      dead.phase = .dead
      dead.character.health = 0
      scene.update(state: dead, reducedMotion: reduced)
      let worker = try XCTUnwrap(scene.childNode(withName: "//worker-ion"))
      XCTAssertFalse(worker.hasActions())
      XCTAssertNil(scene.childNode(withName: "//tool-ion"))
      scene.update(state: dead, reducedMotion: !reduced)
      XCTAssertFalse(worker.hasActions())
    }
  }

  @MainActor func testSelectionAndAssignmentPreserveWeatherAndLoadDoesNotReplayCompletion() throws {
    let scene = HomesteadScene()
    let state = Rules.newGame()
    scene.update(state: state, reducedMotion: false)
    let weather = try XCTUnwrap(scene.childNode(withName: "weather"))
    scene.select(.building(.woodshed), buildMode: true)
    XCTAssertTrue(scene.childNode(withName: "weather") === weather)
    var completed = state
    completed.buildings = [BuildingRecord(id: .woodshed, completedSeason: 0)]
    completed.phase = .summary
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
  @MainActor func testEveryCompletedBuildingHasWinterArtInEveryFacing() throws {
    let scene = HomesteadScene()
    for id in BuildingID.allCases {
      for facing in 0..<4 {
        let summer = try XCTUnwrap(
          scene.buildingTexture(id, level: 1, planned: false, winter: false, facing: facing))
        let winter = try XCTUnwrap(
          scene.buildingTexture(id, level: 1, planned: false, winter: true, facing: facing))
        XCTAssertFalse(summer === winter, "\(id) facing \(facing) needs snowy artwork")
        if id != .woodshed && id != .cellar { XCTAssertEqual(summer.size(), winter.size()) }
      }
    }
    XCTAssertNil(scene.resourceWarning)
  }
  @MainActor func testRotatingFoundationsDoesNotShowACompletedRearFacade() throws {
    let scene = HomesteadScene()
    for id in [BuildingID.woodshed, .cellar] {
      let front = try XCTUnwrap(
        scene.buildingTexture(id, level: 0, planned: true, winter: false, facing: 0))
      let rear = try XCTUnwrap(
        scene.buildingTexture(id, level: 0, planned: true, winter: true, facing: 2))
      XCTAssertTrue(front === rear)
    }
  }
  @MainActor func testDirectionalArtAndInfrastructurePersistAcrossRotationAndSeasonPreview() throws
  {
    var s = Rules.newGame()
    for id in BuildingID.allCases {
      s.layout.buildings.append(
        .init(id: id, position: try XCTUnwrap(Settlement.firstAvailable(id, in: s.layout))))
      s.buildings.append(.init(id: id, completedSeason: 0, debugPlaced: true))
    }
    s.layout.pavement = [.init(x: 10, y: 14)]
    s.layout.dirtPaths = [.init(x: 11, y: 14)]
    s.layout.fences = [
      .init(position: .init(x: 10, y: 14), facing: 0),
      .init(position: .init(x: 11, y: 14), facing: 0, style: .wattle),
    ]
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
      let dirt = try XCTUnwrap(scene.childNode(withName: "//d:11:14") as? SKSpriteNode)
      XCTAssertEqual(dirt.position, IsometricLayout.point(column: 11, row: 14, rotation: rotation))
      XCTAssertEqual(dirt.colorBlendFactor, rotation == 3 ? 0.65 : 0, accuracy: 0.0001)
      XCTAssertNotNil(scene.childNode(withName: "//f:h:11:14/woven-0"))
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
    s.layout.dirtPaths = []
    s.layout.fences = []
    scene.update(state: s, reducedMotion: true)
    XCTAssertNil(scene.childNode(withName: "//p:10:14"))
    XCTAssertNil(scene.childNode(withName: "//d:11:14"))
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
  @MainActor func testFenceRotationPaintsEachEdgeAtTheSamePointerInEveryMapView() throws {
    for rotation in 0..<4 {
      for kind in [InfrastructureKind.fence, .wattleFence] {
        let session = GameSession(store: nil)
        session.rotateView(rotation)
        let scene = HomesteadScene()
        scene.update(state: session.state, reducedMotion: true)
        scene.onPlacement = { tool, point in
          if case .infrastructure(let material) = tool {
            session.placeInfrastructure(material, at: point, facing: scene.placementFacing)
            scene.update(state: session.state, reducedMotion: true)
          }
        }
        scene.setPlacement(.infrastructure(kind))
        let pointer = IsometricLayout.point(column: 1, row: 1, rotation: rotation)
        for facing in 0..<4 {
          scene.placementFacing = facing
          scene.updatePlacement(at: pointer)
          let ghost = try XCTUnwrap(scene.placementOverlay.childNode(withName: "fence-preview"))
          let previewPosition = ghost.position
          scene.paintInfrastructure(pointer)
          let edge = ["h:1:1", "v:2:1", "h:1:2", "v:1:1"][facing]
          let placed = try XCTUnwrap(scene.childNode(withName: "//f:" + edge))
          XCTAssertEqual(placed.position, previewPosition)
          XCTAssertEqual(placed.childNode(withName: "woven-0") != nil, kind == .wattleFence)
        }
        XCTAssertEqual(session.state.layout.fences.count, 4)
        XCTAssertEqual(session.state.money, 8)
      }
    }
  }
}

extension SceneConstructionTests {
  @MainActor func testFarmlandPaintingFillsSkippedCellsAndAvoidsDoubleChargingInEveryView() {
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
      scene.setPlacement(.infrastructure(.farmland))
      scene.paintInfrastructure(IsometricLayout.point(column: 1, row: 1, rotation: rotation))
      scene.paintInfrastructure(IsometricLayout.point(column: 4, row: 3, rotation: rotation))
      scene.paintInfrastructure(IsometricLayout.point(column: 4, row: 3, rotation: rotation))
      XCTAssertEqual(session.state.layout.farmland.count, 15)
      XCTAssertEqual(session.state.money, 6)
    }
  }
  @MainActor func testFarmlandMovesCropArtSelectionTerrainAndWorkerToPaintedTiles() throws {
    var state = Rules.newGame()
    state.layout.farmland = [.init(x: 1, y: 1)]
    let scene = HomesteadScene()
    for rotation in 0..<4 {
      state.layout.viewRotation = rotation
      scene.update(state: state, reducedMotion: true)
      let tile = try XCTUnwrap(scene.childNode(withName: "//farm:1:1"))
      let center = IsometricLayout.point(column: 1, row: 1, rotation: rotation)
      XCTAssertEqual(tile.position, center)
      XCTAssertEqual(scene.selection(at: center), .hotspot(.field))
      XCTAssertNil(scene.childNode(withName: "//field"))
      scene.select(.hotspot(.field), buildMode: false)
      let patch = try XCTUnwrap(scene.childNode(withName: "//tile-2-2") as? SKSpriteNode)
      XCTAssertEqual(patch.colorBlendFactor, 0.12, accuracy: 0.001)
    }
    XCTAssertEqual(IsometricLayout.worker(.plant, state: state), CGPoint(x: 630, y: 549))
    state.planted = true
    state.season = 1
    scene.update(state: state, reducedMotion: true)
    let tile = try XCTUnwrap(scene.childNode(withName: "//farm:1:1"))
    XCTAssertNotNil(tile.childNode(withName: "crop"))
    state.season = 3
    scene.update(state: state, reducedMotion: true)
    XCTAssertNil(tile.childNode(withName: "crop"))
    state.layout.farmland = []
    scene.update(state: state, reducedMotion: true)
    XCTAssertNil(scene.childNode(withName: "//farm:1:1"))
  }
  @MainActor func testCropProtectionAppearsInPlacementPreviewAndBlocksCommit() throws {
    var state = Rules.newGame()
    state.assignments["ion"] = .plant
    let scene = HomesteadScene()
    scene.update(state: state, reducedMotion: true)
    var commits = 0
    scene.onPlacement = { _, _ in commits += 1 }
    scene.setPlacement(.infrastructure(.farmland))
    scene.updatePlacement(at: IsometricLayout.point(column: 1, row: 1))
    let label = try XCTUnwrap(
      scene.placementOverlay.children.compactMap { $0 as? SKLabelNode }.first)
    XCTAssertTrue(label.text?.contains("Cancel the farming assignment") == true)
    scene.commitPlacement(at: IsometricLayout.point(column: 1, row: 1))
    XCTAssertEqual(commits, 0)
  }
}
