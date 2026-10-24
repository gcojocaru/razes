import RazesCore
import XCTest

@testable import RazesMac

final class GameSessionTests: XCTestCase {
  @MainActor func testInstantActionsDoNotGrantExperienceOrAdvanceNeeds() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = SaveStore(url: directory.appendingPathComponent("save.json"))
    var state = Rules.newGame()
    state.houseLevel = 5
    state.character[.building] = 3
    state.materials = .init(wood: 15, stone: 10, planks: 10)
    try store.save(state)
    let session = GameSession(store: store)
    let original = session.state.character
    let workshopPosition = try XCTUnwrap(
      Settlement.firstAvailable(.workshop, in: session.state.layout))
    XCTAssertTrue(session.placeBuilding(.workshop, at: workshopPosition, instant: true))
    session.debugResources()
    session.buyMaterials(.wood, quantity: 4)
    session.craftPlanks(quantity: 1)
    session.discardMaterials(.stone, quantity: 1)
    let woodshedPosition = try XCTUnwrap(
      Settlement.firstAvailable(.woodshed, in: session.state.layout))
    XCTAssertTrue(session.placeBuilding(.woodshed, at: woodshedPosition, instant: true))
    session.upgradeBuilding(.woodshed)
    session.debugSetBuilding(.woodshed, level: 2, condition: 50)
    session.repairBuilding(.woodshed)
    session.buySeeds(quantity: 1)
    XCTAssertNil(session.error)
    XCTAssertEqual(session.state.character, original)
    XCTAssertEqual(session.state.week, 0)
  }

  @MainActor func testContinueExplainsFallbackAndKeepsCompletedAssignmentInReport() {
    let session = GameSession(store: nil)
    session.send(
      .init(type: "assign", revision: session.state.revision, worker: .ion, task: .plant))
    session.send(.init(type: "resolve", revision: session.state.revision))
    XCTAssertEqual(session.state.assignments["ion"], .plant)
    XCTAssertNil(session.assignmentNotice)
    session.send(.init(type: "continue", revision: session.state.revision))
    XCTAssertEqual(session.state.assignments["ion"], .rest)
    XCTAssertTrue(session.assignmentNotice?.contains("Ion rests instead of repeating") == true)
    XCTAssertTrue(session.assignmentNotice?.contains("already") == true)
    session.send(.init(type: "assign", revision: session.state.revision, worker: .ion, task: .rest))
    XCTAssertNil(session.assignmentNotice)
  }

  @MainActor func testDeadRunBlocksEditsButAllowsCameraAndSafeRestart() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = SaveStore(url: directory.appendingPathComponent("save.json"))
    var state = Rules.newGame()
    state.season = 3
    state.house = 0
    state.character.health = 10
    let dead = try Rules.dispatch(state, action: .init(type: "resolve", revision: state.revision))
    try store.save(dead)
    let session = GameSession(store: store)
    XCTAssertFalse(session.needsRecovery)
    XCTAssertEqual(session.state.phase, .dead)
    let bytes = try Data(contentsOf: store.url)
    session.debugResources()
    session.buySeeds(quantity: 1)
    session.buyMaterials(.wood, quantity: 1)
    session.craftPlanks(quantity: 1)
    session.discardMaterials(.wood, quantity: 1)
    session.upgradeHouseStorage()
    XCTAssertFalse(session.placeBuilding(.woodshed, at: .init(x: 1, y: 1), instant: true))
    XCTAssertFalse(session.placeInfrastructure(.pavement, at: .init(x: 1, y: 1)))
    session.send(.init(type: "continue", revision: session.state.revision))
    XCTAssertEqual(session.state, dead)
    XCTAssertEqual(try Data(contentsOf: store.url), bytes)
    session.rotateView(1)
    XCTAssertEqual(session.state.layout.viewRotation, 1)
    XCTAssertEqual(session.state.character.health, 0)
    XCTAssertEqual(GameSession(store: store).state.phase, .dead)
    session.startFresh()
    XCTAssertEqual(session.state, Rules.newGame())
    XCTAssertEqual(try store.load(), Rules.newGame())
    let backups = try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil
    )
    .filter { $0.lastPathComponent.contains("recovery") }
    XCTAssertEqual(backups.count, 1)
    XCTAssertEqual(try SaveCodec.decode(Data(contentsOf: backups[0])).phase, .dead)
  }

  @MainActor func testFailedRestartKeepsTheDeadRun() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("save.json")
    var state = Rules.newGame()
    state.character.health = 15
    state.character.hunger = 75
    state.food = 0
    let dead = try Rules.dispatch(state, action: .init(type: "resolve", revision: 0))
    try SaveStore(url: url).save(dead)
    let bytes = try Data(contentsOf: url)
    let session = GameSession(
      store: SaveStore(
        url: url,
        preserveOriginal: { _, _ in
          throw CocoaError(.fileWriteNoPermission)
        }))
    session.startFresh()
    XCTAssertEqual(session.state, dead)
    XCTAssertEqual(try Data(contentsOf: url), bytes)
    XCTAssertNotNil(session.error)
  }

  @MainActor func testActionsSaveAndRejectedActionsDoNotWrite() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let store = SaveStore(url: dir.appendingPathComponent("save.json"))
    let session = GameSession(store: SaveStore(url: dir.appendingPathComponent("save.json")))
    session.send(Action(type: "assign", revision: 0, worker: .ion, task: .plant))
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
    let session = GameSession(store: SaveStore(url: url))
    XCTAssertTrue(session.needsRecovery)
    session.send(.init(type: "assign", revision: 0, worker: .ion, task: .plant))
    XCTAssertEqual(session.state, Rules.newGame())
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
    session.send(Action(type: "assign", revision: 0, worker: .ion, task: .rest))
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

#if DEBUG
  extension GameSessionTests {
    @MainActor func testValidationLaunchUsesOnlyItsExplicitSaveFile() throws {
      let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
        UUID().uuidString)
      defer { try? FileManager.default.removeItem(at: directory) }
      let url = directory.appendingPathComponent("validation.json")
      let session = GameSession.applicationSession(arguments: [
        "RazesValidation", "--validation-save", url.path,
      ])
      session.send(Action(type: "assign", revision: 0, worker: .ion, task: .rest))
      XCTAssertEqual(try SaveStore(url: url).load()?.phase, .work)
    }
  }
#endif
