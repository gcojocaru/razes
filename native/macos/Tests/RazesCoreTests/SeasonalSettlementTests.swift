import XCTest

@testable import RazesCore

final class SeasonalSettlementTests: XCTestCase {
  func testConstructionProductionAndWearFollowSeasons() throws {
    var s = Rules.newGame()
    s.money = 100
    s.materials = .init(wood: 20)
    try Construction.start(.woodshed, state: &s)
    XCTAssertEqual(s.buildings[0].level, 0)
    Construction.resolveSeason(state: &s)
    XCTAssertEqual(s.buildings[0].level, 1)
    XCTAssertEqual(s.money, 97)
    XCTAssertEqual(s.buildings[0].condition, 100)
    s.season = 1
    Construction.resolveSeason(state: &s)
    XCTAssertEqual(s.money, 98)
    XCTAssertEqual(s.buildings[0].condition, 80)
    s.houseLevel = 2
    s.character.buildingXP = 3
    try Construction.upgrade(.woodshed, state: &s)
    XCTAssertEqual(s.buildings[0].level, 2)
    XCTAssertEqual(s.buildings[0].condition, 100)
    XCTAssertEqual(s.money, 92)
    s.buildings[0].condition = 3
    try Construction.repair(.woodshed, state: &s)
    XCTAssertEqual(s.buildings[0].condition, 100)
    XCTAssertEqual(s.money, 90)
    s.buildings[0].condition = 10
    Construction.resolveSeason(state: &s)
    XCTAssertEqual(s.buildings[0].level, 1)
    XCTAssertEqual(s.buildings[0].condition, 60)
  }

  func testRoadAndFenceEdgesValidateAndRotate() throws {
    var s = Rules.newGame()
    s.layout.pavement = [.init(x: 1, y: 1)]
    s.layout.fences = [.init(position: .init(x: 1, y: 1), facing: 0)]
    s.layout.viewRotation = 3
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(s)), s)
    s.layout.fences.append(.init(position: .init(x: 1, y: 0), facing: 2))
    XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(s)))
    s.layout.fences.removeLast()
    s.layout.viewRotation = 4
    XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(s)))
    s.layout.viewRotation = 0
    s.layout.pavement = [.init(x: Int.max, y: 0)]
    XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(s)))
  }
  func testMixedSurfacesAndMalformedNewInfrastructureRejectWithoutRepairingTheSave() throws {
    var s = Rules.newGame()
    s.layout.dirtPaths = [.init(x: 1, y: 1)]
    s.layout.fences = [.init(position: .init(x: 1, y: 1), facing: 0, style: .wattle)]
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(s)), s)
    s.layout.pavement = [.init(x: 1, y: 1)]
    XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(s)))
    s.layout.pavement = []
    s.layout.dirtPaths = [.init(x: Int.min, y: 1)]
    XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(s)))
    s.layout.dirtPaths = []
    var object = try JSONSerialization.jsonObject(with: SaveCodec.encode(s)) as! [String: Any]
    var layout = object["layout"] as! [String: Any]
    var fences = layout["fences"] as! [[String: Any]]
    fences[0]["style"] = "unknown"
    layout["fences"] = fences
    object["layout"] = layout
    XCTAssertThrowsError(try SaveCodec.decode(JSONSerialization.data(withJSONObject: object)))
  }
}
