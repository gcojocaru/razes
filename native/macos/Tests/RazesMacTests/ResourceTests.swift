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
  @MainActor func testMissingArtReportsWarningWithoutBlockingRules() {
    let scene = HomesteadScene(artDirectory: URL(fileURLWithPath: "/missing-razes-test-art"))
    scene.update(state: Rules.newGame(), reducedMotion: true)
    XCTAssertNotNil(scene.resourceWarning)
    XCTAssertEqual(Rules.newGame().phase, .opening)
  }
}
