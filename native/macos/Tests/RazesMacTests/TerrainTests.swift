import RazesCore
import SpriteKit
import XCTest

@testable import RazesMac

final class TerrainTests: XCTestCase {
  @MainActor func testTerrainUsesReusableProjectedMaterialTilesAndSeasonalTextures() throws {
    let scene = HomesteadScene()
    var state = Rules.newGame()
    scene.update(state: state, reducedMotion: true)
    let ground = try XCTUnwrap(scene.childNode(withName: "//isometric-ground"))
    XCTAssertFalse(ground is SKSpriteNode)
    let tile = try XCTUnwrap(ground.childNode(withName: "tile-0-0") as? SKSpriteNode)
    XCTAssertEqual(tile.position, IsometricLayout.point(column: -0.25, row: -0.25))
    XCTAssertNotNil(tile.warpGeometry)
    XCTAssertNotNil(tile.texture)
    XCTAssertEqual(ground.children.filter { $0.name?.hasPrefix("tile-") == true }.count, 1024)
    let grass = tile.texture
    state.season = 3
    scene.update(state: state, reducedMotion: true)
    XCTAssertTrue(ground.childNode(withName: "tile-0-0") === tile)
    XCTAssertFalse(tile.texture === grass)
    XCTAssertNil(scene.resourceWarning)
  }
  @MainActor func testConstructionChangesOnlyItsTerrainPatchAndCancelRestoresGrass() throws {
    let scene = HomesteadScene()
    var state = Rules.newGame()
    scene.update(state: state, reducedMotion: true)
    let patch = try XCTUnwrap(scene.childNode(withName: "//tile-3-3") as? SKSpriteNode)
    let grass = patch.texture
    let remote = try XCTUnwrap(scene.childNode(withName: "//tile-0-0") as? SKSpriteNode)
    let remoteGrass = remote.texture
    state.layout.buildings = [.init(id: .woodshed, position: .init(x: 1, y: 1))]
    state.assignments["ana"] = .buildWoodshed
    scene.update(state: state, reducedMotion: true)
    XCTAssertFalse(patch.texture === grass)
    XCTAssertTrue(remote.texture === remoteGrass)
    state.assignments["ana"] = .rest
    scene.update(state: state, reducedMotion: true)
    XCTAssertTrue(patch.texture === grass)
  }
}
