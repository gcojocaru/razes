import RazesCore
import SwiftUI
import XCTest

@testable import RazesMac

final class ConversationTests: XCTestCase {
  @MainActor func testOutgoingConversationUsesItsOwnPhaseSnapshot() {
    let session = GameSession(store: nil)
    let view = ConversationView(session: session, state: session.state)
    session.send(Action(type: "choose", revision: 0, event: "spring-ox", choice: "borrow"))
    XCTAssertEqual(session.state.phase, .work)
    _ = view.body
  }
}
