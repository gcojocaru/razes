import RazesCore
import XCTest

@testable import RazesMac

final class GameSessionTests: XCTestCase {
  @MainActor func testActionsSaveAndRejectedActionsDoNotWrite() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let store = SaveStore(url: dir.appendingPathComponent("save.json"))
    let session = GameSession(store: SaveStore(url: dir.appendingPathComponent("save.json")))
    session.send(Action(type: "choose", revision: 0, event: "spring-ox", choice: "borrow"))
    session.send(Action(type: "assign", revision: 1, worker: .ion, task: .plant))
    XCTAssertEqual(try store.load(), session.state)
    let bytes = try Data(contentsOf: store.url)
    session.send(Action(type: "resolve", revision: 0))
    XCTAssertNotNil(session.error)
    XCTAssertEqual(try Data(contentsOf: store.url), bytes)
    XCTAssertEqual(GameSession(store: store).state.assignments["ion"], .plant)
  }
  @MainActor func testInvalidSaveBlocksActionsAndRetryResumes() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("save.json")
    let bad = Data("invalid".utf8)
    try bad.write(to: url)
    let store = SaveStore(url: url)
    let session = GameSession(store: SaveStore(url: url))
    XCTAssertTrue(session.needsRecovery)
    session.send(Action(type: "choose", revision: 0, event: "spring-ox", choice: "borrow"))
    XCTAssertEqual(try Data(contentsOf: url), bad)
    try SaveCodec.encode(Rules.newGame()).write(to: url)
    session.retryLoad()
    XCTAssertFalse(session.needsRecovery)
  }
  @MainActor func testWriteFailureRetainsLiveRunAndFailedRestartRetainsRecovery() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("save.json")
    let session = GameSession(store: SaveStore(url: url))
    try Data("blocker".utf8).write(to: dir.appendingPathComponent("block"))
    try FileManager.default.removeItem(at: dir)
    try Data("blocker".utf8).write(to: dir)
    session.send(Action(type: "choose", revision: 0, event: "spring-ox", choice: "borrow"))
    XCTAssertEqual(session.state.phase, .work)
    XCTAssertNotNil(session.storageWarning)
    let badStore = SaveStore(
      url: dir, preserveOriginal: { _, _ in throw CocoaError(.fileWriteNoPermission) })
    let blocked = GameSession(store: badStore)
    blocked.startFresh()
    XCTAssertTrue(blocked.needsRecovery)
    XCTAssertEqual(try Data(contentsOf: dir), Data("blocker".utf8))
  }
}
