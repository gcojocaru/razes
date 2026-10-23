import RazesCore
import SwiftUI
import XCTest

@testable import RazesMac

final class GameUIStateTests: XCTestCase {
  func testEscapeClearsOptionalCommandsAndPhaseChangeRestoresReview() {
    var ui = GameUIState(selection: .building(.cellar), buildMode: true, review: true)
    ui.dismissOptional()
    XCTAssertNil(ui.selection)
    XCTAssertFalse(ui.buildMode)
    XCTAssertFalse(ui.review)
    ui.changedPhase()
    XCTAssertTrue(ui.review)
  }
  @MainActor func testOutgoingPhaseOverlayCanReevaluateAfterSessionChanges() throws {
    let session = GameSession(store: nil)
    let state = session.state
    let overlay = PhaseOverlay(session: session, state: state, close: {}, restart: {}, journal: {})
    session.send(Action(type: "choose", revision: 0, event: "spring-ox", choice: "borrow"))
    _ = overlay.body
  }
}
