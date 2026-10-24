import XCTest

@testable import RazesCore

final class SaveTests: XCTestCase {
  func testFreshSaveRoundTripsAndRejectsOldSchemas() throws {
    let s = Rules.newGame()
    XCTAssertEqual(s.version, 11)
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(s)), s)
    for version in 1...9 {
      var object = try JSONSerialization.jsonObject(with: SaveCodec.encode(s)) as! [String: Any]
      object["version"] = version
      XCTAssertThrowsError(try SaveCodec.decode(JSONSerialization.data(withJSONObject: object)))
    }
  }
  func testMalformedWorkersPhasesTasksAndCropStateFailClosed() throws {
    let original =
      try JSONSerialization.jsonObject(with: SaveCodec.encode(Rules.newGame())) as! [String: Any]
    let changes: [[String: Any]] = [
      ["assignments": ["ion": "rest", "ana": "rest"]],
      ["assignments": ["petru": "rest"]], ["assignments": [:]],
      ["assignments": ["ion": "help"]], ["assignments": ["ion": "harvest"]],
      ["phase": "opening"], ["phase": "ending"], ["phase": "summary"],
      ["year": -1], ["year": 100001], ["season": 4], ["year": true],
      ["food": -1], ["food": 100001], ["money": "12"],
      ["planted": true], ["tended": true], ["harvested": true],
      ["houseLevel": 0], ["houseLevel": 6], ["house": 101],
    ]
    for change in changes {
      let object = original.merging(change) { _, new in new }
      XCTAssertThrowsError(
        try SaveCodec.decode(JSONSerialization.data(withJSONObject: object)), "\(change)")
    }
  }
  func testIncompleteOversizedAndMalformedSavesFailClosed() {
    for bytes in [
      Data(), Data("{}".utf8), Data("not JSON".utf8), Data(repeating: 32, count: 1_000_001),
    ] {
      XCTAssertThrowsError(try SaveCodec.decode(bytes))
    }
  }
}

extension SaveTests {
  func testExtremeBuildingLevelsRejectBeforeForecastArithmetic() throws {
    for id in [BuildingID.cellar, .storehouse] {
      var s = Rules.newGame()
      s.year = 1
      s.buildings = [.init(id: id, completedSeason: 0, legacyAssignment: false, level: Int.max)]
      s.layout.buildings = [.init(id: id, position: .init(x: 1, y: 1))]
      XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(s)))
    }
  }
}
