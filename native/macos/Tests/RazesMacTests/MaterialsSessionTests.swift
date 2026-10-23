import RazesCore
import XCTest

@testable import RazesMac

final class MaterialsSessionTests: XCTestCase {
  @MainActor func testImmediateMarketCraftAndHouseUpgradePersistWithoutUsingWorkers() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let store = SaveStore(url: dir.appendingPathComponent("save.json"))
    let session = GameSession(store: store)
    let assignments = session.state.assignments
    session.buyMaterials(.wood, quantity: 1)
    XCTAssertNil(session.error)
    XCTAssertEqual(session.state.money, 11)
    session.craftPlanks(quantity: 1)
    XCTAssertEqual(session.state.materials, .init(wood: 5, stone: 4, planks: 1))
    session.upgradeHouseStorage()
    XCTAssertNil(session.error)
    XCTAssertEqual(session.state.houseLevel, 2)
    XCTAssertEqual(session.state.materials, .init(wood: 3, stone: 2))
    XCTAssertEqual(session.state.money, 3)
    XCTAssertEqual(session.state.assignments, assignments)
    XCTAssertEqual(session.state.phase, .opening)
    XCTAssertEqual(GameSession(store: store).state, session.state)
    let before = session.state
    session.buyMaterials(.planks, quantity: 100)
    XCTAssertNotNil(session.error)
    XCTAssertEqual(session.state, before)
    session.discardMaterials(.wood, quantity: 1)
    XCTAssertNil(session.error)
    XCTAssertEqual(session.state.materials.wood, 2)
    XCTAssertEqual(try store.load(), session.state)
  }

  func testV6MigrationPreservesOriginalBytesBeforeFirstReplacement() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("save.json")
    var object =
      try JSONSerialization.jsonObject(with: SaveCodec.encode(Rules.newGame())) as! [String: Any]
    object["version"] = 6
    for key in ["materials", "houseLevel", "gatheringAssignments"] {
      object.removeValue(forKey: key)
    }
    let bytes = try JSONSerialization.data(withJSONObject: object)
    try bytes.write(to: url)
    let store = SaveStore(url: url)
    let migrated = try XCTUnwrap(store.load())
    XCTAssertEqual(migrated.materials, Materials.starter)
    XCTAssertEqual(try Data(contentsOf: url), bytes)
    let blocked = SaveStore(
      url: url, preserveOriginal: { _, _ in throw CocoaError(.fileWriteNoPermission) })
    XCTAssertThrowsError(try blocked.save(migrated))
    XCTAssertEqual(try Data(contentsOf: url), bytes)
    try store.save(migrated)
    try store.save(migrated)
    let backups = try FileManager.default.contentsOfDirectory(
      at: dir, includingPropertiesForKeys: nil
    )
    .filter { $0.lastPathComponent.contains("migration") }
    XCTAssertEqual(backups.count, 1)
    XCTAssertEqual(try Data(contentsOf: XCTUnwrap(backups.first)), bytes)
  }
}
