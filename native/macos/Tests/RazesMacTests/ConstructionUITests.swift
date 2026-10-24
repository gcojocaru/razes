import RazesCore
import SwiftUI
import XCTest

@testable import RazesMac

final class ConstructionUITests: XCTestCase {
  func testCatalogueStatusIncludesLocksSuppliesFoundationsAndDamage() {
    var state = Rules.newGame()
    XCTAssertEqual(ConstructionPresentation.status(.bakery, state: state), "Locked")
    XCTAssertEqual(ConstructionPresentation.status(.woodshed, state: state), "Ready to build")
    state.materials.wood = 0
    XCTAssertEqual(ConstructionPresentation.status(.woodshed, state: state), "Missing supplies")
    state.buildings = [.init(id: .woodshed, completedSeason: 0, level: 0)]
    XCTAssertEqual(ConstructionPresentation.status(.woodshed, state: state), "Under construction")
    state.buildings[0].level = 1
    XCTAssertEqual(
      ConstructionPresentation.status(.woodshed, state: state), "Operational · level 1")
    state.buildings[0].condition = 0
    XCTAssertEqual(
      ConstructionPresentation.status(.woodshed, state: state), "Needs repair · level 1")
  }

  func testConstructionDatesDistinguishCompletionAndFirstPayout() {
    var state = Rules.newGame()
    state.week = 10
    XCTAssertEqual(
      ConstructionPresentation.completion(state),
      "Completes Spring 1495 · Month 3 · Week 4 · 2 week(s)")
    state.buildings = [.init(id: .woodshed, completedSeason: 0, level: 0)]
    XCTAssertTrue(ConstructionPresentation.payout(.woodshed, state: state).contains("Summer 1495"))
    XCTAssertTrue(ConstructionPresentation.payout(.woodshed, state: state).contains("14 week(s)"))
    state.buildings[0].condition = 0
    XCTAssertEqual(
      ConstructionPresentation.payout(.woodshed, state: state), "Next seasonal payout: repair first"
    )
  }

  func testSummaryCountdownStartsAfterResolvedWeekAndSeason() {
    var state = Rules.newGame()
    state.week = 11
    state.phase = .summary
    state.buildings = [.init(id: .woodshed, completedSeason: 0, level: 0)]
    XCTAssertEqual(
      ConstructionPresentation.completion(state),
      "Completes Summer 1495 · Month 3 · Week 4 · 12 week(s)")
    XCTAssertTrue(ConstructionPresentation.payout(.woodshed, state: state).contains("Autumn 1495"))
    XCTAssertTrue(ConstructionPresentation.payout(.woodshed, state: state).contains("24 week(s)"))
    state.buildings[0].level = 1
    XCTAssertTrue(ConstructionPresentation.payout(.woodshed, state: state).contains("Summer 1495"))
    XCTAssertTrue(ConstructionPresentation.payout(.woodshed, state: state).contains("12 week(s)"))
  }

  @MainActor func testCatalogueAndWorkshopRenderAtBothSupportedViewports() throws {
    let session = GameSession(store: nil)
    let position = try XCTUnwrap(Settlement.firstAvailable(.workshop, in: session.state.layout))
    XCTAssertTrue(session.placeBuilding(.workshop, at: position, instant: true))
    for (width, height) in [(1000, 700), (1280, 850)] {
      for selected in [BuildingID?.none, .some(.bakery), .some(.workshop)] {
        let panel = BuildPanel(
          session: session, state: session.state, infrastructure: { _ in },
          beginPlacement: { _ in }, close: {}, initialSelection: selected
        )
        .frame(width: CGFloat(width), height: CGFloat(height)).background(GamePalette.ink)
        let hosting = NSHostingView(rootView: panel)
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        XCTAssertGreaterThanOrEqual(bitmap.pixelsWide, width)
        XCTAssertGreaterThanOrEqual(bitmap.pixelsHigh, height)
        if let path = ProcessInfo.processInfo.environment["RAZES_CONSTRUCTION_ARTIFACTS"] {
          let output = URL(fileURLWithPath: path)
          try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
          try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            .write(
              to: output.appendingPathComponent(
                "catalogue-\(selected?.rawValue ?? "house")-\(width)x\(height).png"))
        }
      }
    }
  }
  @MainActor func testMapInspectorRendersPrerequisitesAndDamagedWorkshopAtPanelWidth() throws {
    let session = GameSession(store: nil)
    var state = session.state
    state.buildings = [.init(id: .workshop, completedSeason: 0, condition: 0)]
    for id in [BuildingID.granary, .workshop] {
      let inspector = GamePanel {
        ScrollView {
          BuildingInspector(session: session, state: state, id: id, beginPlacement: { _ in })
        }
      }.frame(width: 300, height: 500).background(GamePalette.ink)
        .environment(\.colorScheme, .dark)
      let hosting = NSHostingView(rootView: inspector)
      hosting.frame = NSRect(x: 0, y: 0, width: 300, height: 500)
      hosting.layoutSubtreeIfNeeded()
      let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
      hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
      XCTAssertGreaterThanOrEqual(bitmap.pixelsWide, 300)
      if let path = ProcessInfo.processInfo.environment["RAZES_CONSTRUCTION_ARTIFACTS"] {
        try FileManager.default.createDirectory(
          at: URL(fileURLWithPath: path), withIntermediateDirectories: true)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
          .write(
            to: URL(fileURLWithPath: path).appendingPathComponent(
              "map-inspector-\(id.rawValue)-300.png"))
      }
    }
  }

}
