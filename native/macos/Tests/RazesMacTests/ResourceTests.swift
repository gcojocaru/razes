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
    XCTAssertFalse(scene.children.contains { $0.hasActions() })
    scene.update(state: Rules.newGame(), reducedMotion: false)
    XCTAssertTrue(scene.children.contains { $0.hasActions() })
  }
  @MainActor func testMissingArtReportsWarningWithoutBlockingRules() {
    let scene = HomesteadScene(artDirectory: URL(fileURLWithPath: "/missing-razes-test-art"))
    scene.update(state: Rules.newGame(), reducedMotion: true)
    XCTAssertNotNil(scene.resourceWarning)
    XCTAssertEqual(Rules.newGame().phase, .opening)
  }
}
