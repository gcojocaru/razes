import RazesCore
import XCTest

@testable import RazesMac

final class MaterialsSessionTests: XCTestCase {
  @MainActor func testSeedPurchasePersistsAndCannotSpendReservedCoins() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let store = SaveStore(url: dir.appendingPathComponent("save.json"))
    let session = GameSession(store: store)
    session.send(.init(type: "assign", revision: 0, worker: .ion, task: .supplies))
    session.buySeeds(quantity: 8)
    XCTAssertNil(session.error)
    XCTAssertEqual(session.state.seeds, 16)
    XCTAssertEqual(session.state.money, 4)
    XCTAssertEqual(session.state.week, 0)
    XCTAssertEqual(session.state.assignments["ion"], .supplies)
    XCTAssertEqual(GameSession(store: store).state, session.state)
    let before = session.state
    let bytes = try Data(contentsOf: store.url)
    session.buySeeds(quantity: 1)
    XCTAssertNotNil(session.error)
    XCTAssertEqual(session.state, before)
    XCTAssertEqual(try Data(contentsOf: store.url), bytes)
  }
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
    XCTAssertEqual(session.state.phase, .work)
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

}
