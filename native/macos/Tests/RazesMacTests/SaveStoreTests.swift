import RazesCore
import XCTest

@testable import RazesMac

final class SaveStoreTests: XCTestCase {
  func testSaveResumeAndRecoveryPreserveOriginal() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("household-v1.json")
    let store = SaveStore(url: url)
    XCTAssertNil(try store.load())
    try store.save(Rules.newGame())
    XCTAssertEqual(try store.load(), Rules.newGame())
    let bad = Data("damaged save".utf8)
    try bad.write(to: url)
    XCTAssertThrowsError(try store.load())
    XCTAssertEqual(try Data(contentsOf: url), bad)
    try store.startFresh(Rules.newGame())
    let backups = try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil
    ).filter { $0.lastPathComponent.contains("recovery") }
    XCTAssertEqual(backups.count, 1)
    XCTAssertEqual(try Data(contentsOf: backups[0]), bad)
    XCTAssertEqual(try store.load(), Rules.newGame())
  }
  func testFailedWritesAndBackupDoNotDestroyExistingData() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let blocker = directory.appendingPathComponent("file")
    let bytes = Data("original".utf8)
    try bytes.write(to: blocker)
    XCTAssertThrowsError(
      try SaveStore(url: blocker.appendingPathComponent("save.json")).save(Rules.newGame()))
    let store = SaveStore(
      url: blocker, preserveOriginal: { _, _ in throw CocoaError(.fileWriteNoPermission) })
    XCTAssertThrowsError(try store.startFresh(Rules.newGame()))
    XCTAssertEqual(try Data(contentsOf: blocker), bytes)
  }
}

extension SaveStoreTests {
  func testV2PlacementMigrationPreservesOriginalBackup() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("save.json")
    var object =
      try JSONSerialization.jsonObject(with: SaveCodec.encode(Rules.newGame())) as! [String: Any]
    object["version"] = 2
    object.removeValue(forKey: "layout")
    let bytes = try JSONSerialization.data(withJSONObject: object)
    try bytes.write(to: url)
    let store = SaveStore(url: url)
    let migrated = try XCTUnwrap(store.load())
    XCTAssertEqual(migrated.layout.scenery.count, 4)
    try store.save(migrated)
    try store.save(migrated)
    let backups = try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil
    ).filter { $0.lastPathComponent.contains("migration") }
    XCTAssertEqual(backups.count, 1)
    XCTAssertEqual(try Data(contentsOf: XCTUnwrap(backups.first)), bytes)
  }
  func testMigrationBacksUpOriginalOnceAndFailedPreservationRetainsBytes() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("save.json")
    var object =
      try JSONSerialization.jsonObject(with: SaveCodec.encode(Rules.newGame())) as! [String: Any]
    object["version"] = 1
    object.removeValue(forKey: "buildings")
    object.removeValue(forKey: "layout")
    let original = try JSONSerialization.data(withJSONObject: object)
    try original.write(to: url)
    let store = SaveStore(url: url)
    let migrated = try XCTUnwrap(store.load())
    XCTAssertEqual(migrated.version, 4)
    XCTAssertEqual(try Data(contentsOf: url), original)
    let blocked = SaveStore(
      url: url, preserveOriginal: { _, _ in throw CocoaError(.fileWriteNoPermission) })
    XCTAssertThrowsError(try blocked.save(migrated))
    XCTAssertEqual(try Data(contentsOf: url), original)
    try store.save(migrated)
    try store.save(migrated)
    let backups = try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil
    ).filter { $0.lastPathComponent.contains("migration") }
    XCTAssertEqual(backups.count, 1)
    XCTAssertEqual(try Data(contentsOf: XCTUnwrap(backups.first)), original)
  }
}

extension SaveStoreTests {
  func testInvalidReplacementDoesNotPoisonAValidSave() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("save.json")
    let store = SaveStore(url: url)
    try store.save(Rules.newGame())
    let bytes = try Data(contentsOf: url)
    var bad = Rules.newGame()
    bad.money = 100001
    XCTAssertThrowsError(try store.save(bad))
    XCTAssertEqual(try Data(contentsOf: url), bytes)
  }
  func testV3MigrationPreservesOriginalBytesOnce() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("save.json")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var object =
      try JSONSerialization.jsonObject(with: SaveCodec.encode(Rules.newGame())) as! [String: Any]
    object["version"] = 3
    let original = try JSONSerialization.data(withJSONObject: object)
    try original.write(to: url)
    let store = SaveStore(url: url)
    let loaded = try XCTUnwrap(store.load())
    XCTAssertEqual(loaded.version, 4)
    try store.save(loaded)
    try store.save(loaded)
    let backups = try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil
    ).filter { $0.lastPathComponent.contains("migration") }
    XCTAssertEqual(backups.count, 1)
    XCTAssertEqual(try Data(contentsOf: XCTUnwrap(backups.first)), original)
  }
}
