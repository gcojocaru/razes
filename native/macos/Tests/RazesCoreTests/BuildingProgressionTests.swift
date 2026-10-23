import XCTest

@testable import RazesCore

final class BuildingProgressionTests: XCTestCase {

  func testCatalogAndAllFiveInstantLevelsRoundTrip() throws {
    XCTAssertEqual(BuildingID.allCases.count, 11)
    var s = Rules.newGame()
    s.money = 10000
    s.materials = .init(wood: 1000, stone: 1000, planks: 1000)
    for id in BuildingID.allCases {
      s.layout.buildings.append(
        .init(id: id, position: try XCTUnwrap(Settlement.firstAvailable(id, in: s.layout))))
      try Construction.start(id, state: &s)
    }
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(s)), s)
    Construction.resolveSeason(state: &s)
    for level in 2...5 {
      for id in BuildingID.allCases { try Construction.upgrade(id, state: &s) }
      XCTAssertTrue(s.buildings.allSatisfy { $0.level == level })
      XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(s)), s)
    }
    XCTAssertThrowsError(try Construction.upgrade(.woodshed, state: &s))
    var bad = s
    bad.buildings[0].level = 6
    XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(bad)))
  }

  func testSeasonalResourceCapsAndMoneyReservedForWorkers() throws {
    var s = try ConstructionTests().work()
    s.money = 4
    s.assignments["ion"] = .supplies
    let before = s
    XCTAssertThrowsError(try Construction.start(.cellar, state: &s))
    XCTAssertEqual(s, before)
    s.money = 100000
    s.food = 100000
    s.assignments["ion"] = .paid
    XCTAssertEqual(Rules.preview(s).moneyAfter, 100000)
    s = try Rules.dispatch(s, action: .init(type: "resolve", revision: s.revision))
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(s)), s)
  }
}
