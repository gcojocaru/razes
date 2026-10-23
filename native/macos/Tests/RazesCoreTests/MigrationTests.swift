import XCTest

@testable import RazesCore

final class MigrationTests: XCTestCase {
  func legacy(_ state: GameState) throws -> Data {
    var object = try JSONSerialization.jsonObject(with: SaveCodec.encode(state)) as! [String: Any]
    object["version"] = 1
    object.removeValue(forKey: "buildings")
    object.removeValue(forKey: "layout")
    return try JSONSerialization.data(withJSONObject: object)
  }
  func testLegacyHouseholdsMigrateAtEveryPhase() throws {
    for run in try Reference.load().runs {
      for step in run.steps {
        let raw = try legacy(step.state)
        let migrated = try SaveCodec.decode(raw)
        var expected = step.state
        expected.layout = Settlement.legacyLayout(for: expected)
        XCTAssertEqual(migrated, expected)
        XCTAssertEqual(migrated.version, 3)
        XCTAssertTrue(migrated.buildings.isEmpty)
      }
    }
  }
  func testMalformedVersionDoesNotBecomeLegacyMigration() throws {
    var object = try JSONSerialization.jsonObject(with: legacy(Rules.newGame())) as! [String: Any]
    for version: Any in [true, false, "1", 1.5, NSNull()] {
      object["version"] = version
      XCTAssertThrowsError(try SaveCodec.decode(JSONSerialization.data(withJSONObject: object)))
    }
  }
  func testV2RequiresRecordsAndRejectsImpossibleBuildings() throws {
    let original = Rules.newGame()
    XCTAssertEqual(original.version, 3)
    var object =
      try JSONSerialization.jsonObject(with: SaveCodec.encode(original)) as! [String: Any]
    object.removeValue(forKey: "buildings")
    XCTAssertThrowsError(try SaveCodec.decode(JSONSerialization.data(withJSONObject: object)))
    for records: [[String: Any]] in [
      [["id": "unknown", "completedSeason": 0]],
      [["id": "woodshed", "completedSeason": 3]],
      [["id": "woodshed", "completedSeason": 0]],
      [["id": "woodshed", "completedSeason": -1]],
      [["id": "woodshed", "completedSeason": 0], ["id": "woodshed", "completedSeason": 0]],
    ] {
      object["buildings"] = records
      XCTAssertThrowsError(try SaveCodec.decode(JSONSerialization.data(withJSONObject: object)))
    }
  }
  func testConstructionDraftAndCompletionRoundTrip() throws {
    let helper = ConstructionTests()
    let draft = try helper.assign(helper.work(), .ion, .buildWoodshed)
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(draft)), draft)
    let done = try Rules.dispatch(draft, action: Action(type: "resolve", revision: draft.revision))
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(done)), done)
    var contradictory = done
    contradictory.buildings = []
    XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(contradictory)))
    contradictory = done
    contradictory.assignments["ion"] = .rest
    XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(contradictory)))
    var wrong = draft
    wrong.assignments["ana"] = .buildWoodshed
    XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(wrong)))
    var legacyObject = try JSONSerialization.jsonObject(with: legacy(draft)) as! [String: Any]
    legacyObject["version"] = 1
    XCTAssertThrowsError(try SaveCodec.decode(JSONSerialization.data(withJSONObject: legacyObject)))
  }
}
