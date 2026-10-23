import XCTest

@testable import RazesCore

final class BuildingProgressionTests: XCTestCase {
  func legacyV4(_ record: [String: Any]) throws -> [String: Any] {
    var object =
      try JSONSerialization.jsonObject(with: SaveCodec.encode(Rules.newGame())) as! [String: Any]
    object["version"] = 4
    object.removeValue(forKey: "settlementSeasons")
    object["buildingClock"] = 1000
    object["buildings"] = [record]
    object["layout"] = [
      "buildings": [["id": "woodshed", "position": ["x": 1, "y": 1]]], "scenery": [],
    ]
    return object
  }
  func testCatalogAndAllFiveInstantLevelsRoundTrip() throws {
    XCTAssertEqual(BuildingID.allCases.count, 10)
    var s = Rules.newGame()
    s.money = 1000
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
  func testPaidV4JobsMigrateOnceAndInvalidTimersFailClosed() throws {
    let base: [String: Any] = [
      "id": "woodshed", "completedSeason": 0, "realtime": true, "level": 1, "condition": 40,
      "production": 12,
    ]
    for (kind, duration, level) in [("upgrade", 120, 2), ("repair", 20, 1)] {
      var r = base
      r["work"] = ["kind": kind, "duration": duration, "remaining": 10]
      let raw = try JSONSerialization.data(withJSONObject: legacyV4(r))
      let migrated = try SaveCodec.decode(raw)
      XCTAssertEqual(migrated.buildings[0].level, level)
      XCTAssertEqual(migrated.buildings[0].condition, 100)
      XCTAssertEqual(migrated.money, 12)
      XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(migrated)), migrated)
      for remaining: Any in [0, -1, 9999, true, "10"] {
        r["work"] = ["kind": kind, "duration": duration, "remaining": remaining]
        XCTAssertThrowsError(
          try SaveCodec.decode(JSONSerialization.data(withJSONObject: legacyV4(r))))
      }
    }
    var foundation = base
    foundation["level"] = 0
    foundation["work"] = ["kind": "build", "duration": 30, "remaining": 15]
    var s = try SaveCodec.decode(JSONSerialization.data(withJSONObject: legacyV4(foundation)))
    XCTAssertEqual(s.buildings[0].level, 0)
    Construction.resolveSeason(state: &s)
    XCTAssertEqual(s.buildings[0].level, 1)
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
