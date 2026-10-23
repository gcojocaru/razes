import RazesCore
import SpriteKit
import XCTest

@testable import RazesMac

final class HarvestSceneTests: XCTestCase {
  @MainActor func testWeeklyCropStagesReuseFieldNodeAndShowSproutsDistinctly() throws {
    let scene = HomesteadScene()
    var field: SKNode?
    var growingHeight: CGFloat = 0
    for (age, stage) in [(1, "sown"), (3, "sprouting"), (8, "growing"), (24, "ripe")] {
      var state = Rules.newGame()
      state.layout.farmland = [.init(x: 1, y: 1)]
      state.planted = true
      state.cropWeeks = age
      state.season = age == 24 ? 2 : 0
      state.week = age == 24 ? 0 : age
      XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(state)), state)
      scene.update(state: state, reducedMotion: true)
      XCTAssertEqual(Presentation(state: state).field, stage)
      let node = try XCTUnwrap(scene.childNode(withName: "//farm:1:1"))
      let crop = try XCTUnwrap(node.childNode(withName: "crop") as? SKShapeNode)
      XCTAssertNil(scene.childNode(withName: "//field"))
      XCTAssertNil(scene.resourceWarning)
      if let field { XCTAssertTrue(node === field) } else { field = node }
      XCTAssertEqual(node.userData?["field"] as? String, stage)
      if stage == "sprouting" { XCTAssertEqual(crop.lineWidth, 2) }
      if stage == "growing" { growingHeight = crop.frame.height }
      if stage == "ripe" { XCTAssertGreaterThan(crop.frame.height, growingHeight) }
      let center = IsometricLayout.point(column: 1, row: 1)
      XCTAssertEqual(scene.selection(at: center), .hotspot(.field))
    }
  }
}
