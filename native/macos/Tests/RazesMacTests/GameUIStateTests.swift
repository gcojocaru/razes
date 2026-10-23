import RazesCore
import SwiftUI
import XCTest

@testable import RazesMac

final class GameUIStateTests: XCTestCase {
  func testEscapeClearsOptionalCommandsAndPhaseChangeRestoresReview() {
    var ui = GameUIState(selection: .building(.cellar), buildMode: true, review: true)
    ui.debug = true
    ui.placement = .scenery(.barn)
    ui.dismissOptional()
    XCTAssertNil(ui.selection)
    XCTAssertNil(ui.placement)
    XCTAssertFalse(ui.debug)
    XCTAssertFalse(ui.buildMode)
    XCTAssertFalse(ui.review)
    ui.changedPhase()
    XCTAssertTrue(ui.review)
  }
  @MainActor func testSeasonReportRendersAfterResolvingWithoutConversation() throws {
    let session = GameSession(store: nil)
    session.send(.init(type: "resolve", revision: 0))
    XCTAssertEqual(session.state.phase, .summary)
    let view = PhaseOverlay(session: session, state: session.state, close: {})
    let hosting = NSHostingView(rootView: view)
    hosting.frame = NSRect(x: 0, y: 0, width: 760, height: 380)
    hosting.layoutSubtreeIfNeeded()
    XCTAssertGreaterThan(hosting.fittingSize.height, 0)
  }
}
