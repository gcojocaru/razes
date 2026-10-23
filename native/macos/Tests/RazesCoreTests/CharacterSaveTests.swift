import XCTest

@testable import RazesCore

final class CharacterSaveTests: XCTestCase {
  func testCharacterFieldsAreRequiredAndBoundedBeforeForecasting() throws {
    let original =
      try JSONSerialization.jsonObject(with: SaveCodec.encode(Rules.newGame())) as! [String: Any]
    XCTAssertEqual(original["version"] as? Int, 10)
    for key in ["health", "energy", "hunger", "farmingXP", "gatheringXP", "buildingXP"] {
      for value in [-1, key.hasSuffix("XP") ? 13 : 101, Int.max, Int.min] {
        var object = original
        var character = object["character"] as! [String: Any]
        character[key] = value
        object["character"] = character
        XCTAssertThrowsError(
          try SaveCodec.decode(JSONSerialization.data(withJSONObject: object)), "\(key)=\(value)")
      }
      var object = original
      var character = object["character"] as! [String: Any]
      character.removeValue(forKey: key)
      object["character"] = character
      XCTAssertThrowsError(try SaveCodec.decode(JSONSerialization.data(withJSONObject: object)))
    }
    var absent = original
    absent.removeValue(forKey: "character")
    XCTAssertThrowsError(try SaveCodec.decode(JSONSerialization.data(withJSONObject: absent)))
    var deadPlanning = Rules.newGame()
    deadPlanning.character.health = 0
    XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(deadPlanning)))
  }

  func testDeathAndSkilledHaulRoundTripWithConsistentReport() throws {
    var s = Rules.newGame()
    s.character.health = 15
    s.character.hunger = 75
    s.food = 0
    let dead = try SurvivalTests().resolve(s)
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(dead)), dead)
    var inconsistent = dead
    inconsistent.report?.character.starvationDamage = 0
    XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(inconsistent)))
    inconsistent = dead
    inconsistent.character.energy = 99
    XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(inconsistent)))
    inconsistent = dead
    inconsistent.phase = .summary
    XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(inconsistent)))
    s = Rules.newGame()
    s.character.gatheringXP = 12
    s.materials = .init()
    let skilled = try SurvivalTests().resolve(s, .gatherWood)
    XCTAssertEqual(skilled.lastMaterialHaul?.wood, 6)
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(skilled)), skilled)
  }

  func testResolvedCharacterReportIsRequiredAndCannotInventEnergyOrExperience() throws {
    let summary = try SurvivalTests().resolve(Rules.newGame(), .paid)
    let original =
      try JSONSerialization.jsonObject(with: SaveCodec.encode(summary)) as! [String: Any]
    for key in ["before", "after", "energyCost", "starvationDamage", "exposureDamage"] {
      var object = original
      var report = object["report"] as! [String: Any]
      var week = report["character"] as! [String: Any]
      week.removeValue(forKey: key)
      report["character"] = week
      object["report"] = report
      XCTAssertThrowsError(try SaveCodec.decode(JSONSerialization.data(withJSONObject: object)))
    }
    var bad = summary
    bad.report?.character.before.energy = 0
    XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(bad)))
    bad = summary
    bad.character.farmingXP = 1
    bad.report?.character.after = bad.character
    XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(bad)))
  }
}
