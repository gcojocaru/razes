import RazesCore
import SwiftUI
import XCTest

@testable import RazesMac

final class GameUIStateTests: XCTestCase {
  @MainActor func testSurvivalPanelsRenderInMinimumViewport() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = SaveStore(url: directory.appendingPathComponent("save.json"))
    var endangered = Rules.newGame()
    endangered.character.health = 15
    endangered.character.hunger = 75
    endangered.food = 0
    let dead = try Rules.dispatch(endangered, action: .init(type: "resolve", revision: 0))
    for (name, state) in [("planning", Rules.newGame()), ("fatal", endangered), ("death", dead)] {
      try store.save(state)
      let session = GameSession(store: store)
      session.reduceMotion = true
      // Render the controls independently of SpriteKit's onscreen Metal surface.
      let controls = VStack(spacing: 0) {
        Spacer()
        GamePanel {
          GameScroll(maximumHeight: 322) {
            PhaseOverlay(session: session, state: state, close: {})
          }
        }.frame(maxWidth: 760).frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 18).padding(.bottom, 12)
        GameHUD(
          state: state, selection: nil, buildMode: false, choose: { _ in }, build: {}, primary: {})
      }.foregroundStyle(GamePalette.paper).tint(GamePalette.gold).preferredColorScheme(.dark)
        .frame(width: 1000, height: 700).background(GamePalette.ink)
      let view = NSHostingView(rootView: controls)
      view.frame = NSRect(x: 0, y: 0, width: 1000, height: 700)
      view.layoutSubtreeIfNeeded()
      let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
      view.cacheDisplay(in: view.bounds, to: bitmap)
      XCTAssertGreaterThanOrEqual(bitmap.pixelsWide, 1000)
      XCTAssertGreaterThanOrEqual(bitmap.pixelsHigh, 700)
      if let path = ProcessInfo.processInfo.environment["RAZES_SURVIVAL_ARTIFACTS"] {
        let output = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
          .write(to: output.appendingPathComponent("minimum-\(name).png"))
      }
    }
  }

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
