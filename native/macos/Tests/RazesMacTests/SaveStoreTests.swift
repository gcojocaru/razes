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

}

extension SaveStoreTests {
  func testFreshFilenameLeavesLegacyHouseholdUntouched() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let legacy = directory.appendingPathComponent("settlement-v9.json")
    let bytes = Data("original settlement save".utf8)
    try bytes.write(to: legacy)
    XCTAssertEqual(try SaveStore.applicationStore().url.lastPathComponent, SaveStore.filename)
    XCTAssertNotEqual(SaveStore.filename, legacy.lastPathComponent)
    let store = SaveStore(url: directory.appendingPathComponent(SaveStore.filename))
    XCTAssertNil(try store.load())
    try store.save(Rules.newGame())
    XCTAssertEqual(try store.load(), Rules.newGame())
    XCTAssertEqual(try Data(contentsOf: legacy), bytes)
  }
}
