import AppKit
import CoreText
import RazesCore
import XCTest

@testable import RazesMac

final class ResourceTests: XCTestCase {
  @MainActor func testSceneLoadsBundledArtAndReducedMotionStopsActions() {
    let scene = HomesteadScene()
    scene.update(state: Rules.newGame(), reducedMotion: true)
    XCTAssertNil(scene.resourceWarning)
    XCTAssertGreaterThan(scene.children.count, 5)
    scene.enumerateChildNodes(withName: "//*") { node, _ in
      XCTAssertFalse(node.hasActions(), node.name ?? "unnamed node")
    }
    scene.update(state: Rules.newGame(), reducedMotion: false)
    var animating = false
    scene.enumerateChildNodes(withName: "//*") { node, _ in
      if node.hasActions() { animating = true }
    }
    XCTAssertTrue(animating)
    scene.update(state: Rules.newGame(), reducedMotion: true)
    scene.enumerateChildNodes(withName: "//*") { node, _ in
      XCTAssertFalse(node.hasActions(), node.name ?? "unnamed node")
    }
  }
  @MainActor func testOnlyIonAndNoVisitorAppearInAnySeason() throws {
    let scene = HomesteadScene()
    for season in 0..<4 {
      var s = Rules.newGame()
      s.season = season
      scene.update(state: s, reducedMotion: true)
      XCTAssertNotNil(scene.childNode(withName: "//worker-ion"))
      for name in ["worker-ana", "worker-petru", "visitor"] {
        XCTAssertNil(scene.childNode(withName: "//" + name))
      }
    }
    XCTAssertEqual(Set(Content.shared.people.keys), ["ion"])
  }
  @MainActor func testMissingArtReportsWarningWithoutBlockingRules() {
    let scene = HomesteadScene(artDirectory: URL(fileURLWithPath: "/missing-razes-test-art"))
    scene.update(state: Rules.newGame(), reducedMotion: true)
    XCTAssertNotNil(scene.resourceWarning)
    XCTAssertEqual(Rules.newGame().phase, .work)
  }
}
