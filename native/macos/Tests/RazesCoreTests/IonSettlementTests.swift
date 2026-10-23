import XCTest

@testable import RazesCore

final class IonSettlementTests: XCTestCase {
  func testFreshGameStartsWithIonPlanningSpring() {
    let s = Rules.newGame()
    XCTAssertEqual(s.phase, .work)
    XCTAssertEqual(WorkerID.allCases.map(\.rawValue), ["ion"])
    XCTAssertEqual(s.assignments, ["ion": .rest])
    XCTAssertEqual(Rules.preview(s).consumption, 0)
  }

  func testSoloHarvestResolvesDirectlyToReportAndWinterRepeats() throws {
    var s = Rules.newGame()
    s.phase = .work
    for week in 0..<48 {
      let task: TaskID = week % 12 == 0 ? [.plant, .tend, .harvest, .repair][week / 12] : .rest
      s = try Rules.dispatch(
        s, action: .init(type: "assign", revision: s.revision, worker: .ion, task: task))
      let forecast = Rules.preview(s)
      XCTAssertTrue(forecast.errors.isEmpty)
      s = try Rules.dispatch(s, action: .init(type: "resolve", revision: s.revision))
      XCTAssertEqual(s.phase, .summary)
      XCTAssertEqual(s.food, max(0, forecast.foodAfter))
      XCTAssertEqual(s.house, forecast.houseAfter)
      XCTAssertEqual(s.money, forecast.moneyAfter)
      s = try Rules.dispatch(s, action: .init(type: "continue", revision: s.revision))
    }
    XCTAssertEqual(s.phase, .work)
    XCTAssertEqual(s.season, 0)
    XCTAssertEqual(s.turn, 4)
    XCTAssertFalse(s.planted)
    XCTAssertFalse(s.tended)
    XCTAssertFalse(s.harvested)
  }
}

extension IonSettlementTests {
  func testBuildingsAndGatheringResolveOnceAcrossYearBoundary() throws {
    var s = Rules.newGame()
    s.season = 3
    s.week = 11
    s.buildings = [.init(id: .workshop, completedSeason: 0, legacyAssignment: false)]
    s.layout.buildings = [.init(id: .workshop, position: .init(x: 1, y: 1))]
    try Construction.start(.woodshed, state: &s)
    s.layout.buildings.append(.init(id: .woodshed, position: .init(x: 3, y: 8)))
    s = try ConstructionTests().assign(s, .ion, .gatherStone)
    let p = Rules.preview(s)
    let haul = Materials.forecast(s)
    s = try Rules.dispatch(s, action: .init(type: "resolve", revision: s.revision))
    XCTAssertEqual(s.money, p.moneyAfter)
    XCTAssertEqual(s.food, max(0, p.foodAfter))
    XCTAssertEqual(s.buildings.first { $0.id == .workshop }?.condition, 80)
    XCTAssertEqual(s.buildings.first { $0.id == .woodshed }?.completedSeason, 3)
    XCTAssertEqual(s.lastMaterialHaul, haul.gained)
    XCTAssertFalse(Construction.active(.woodshed, state: s))
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(s)), s)
    let resolved = s
    s = try Rules.dispatch(s, action: .init(type: "continue", revision: s.revision))
    XCTAssertEqual(s.food, resolved.food)
    XCTAssertEqual(s.money, resolved.money)
    XCTAssertEqual(s.materials, resolved.materials)
    XCTAssertEqual(s.buildings, resolved.buildings)
    XCTAssertTrue(Construction.active(.woodshed, state: s))
    XCTAssertEqual(Rules.preview(s).moneyGain, 0)
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(s)), s)
    s = try ConstructionTests().assign(s, .ion, .buildCellar)
    s = try Rules.dispatch(s, action: .init(type: "resolve", revision: s.revision))
    XCTAssertEqual(s.buildings.first { $0.id == .cellar }?.completedSeason, 4)
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(s)), s)
  }
}
