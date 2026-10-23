import XCTest

@testable import RazesCore

final class MaterialsTests: XCTestCase {
  func testGatheringAssignmentsExistAndArriveOnlyWhenWorkResolves() throws {
    let timber = try XCTUnwrap(TaskID(rawValue: "gatherWood"))
    var s = try ConstructionTests().work()
    s = try ConstructionTests().assign(s, .ion, timber)
    let before = try JSONSerialization.jsonObject(with: SaveCodec.encode(s)) as! [String: Any]
    s = try Rules.dispatch(s, action: .init(type: "resolve", revision: s.revision))
    let after = try JSONSerialization.jsonObject(with: SaveCodec.encode(s)) as! [String: Any]
    XCTAssertEqual((before["materials"] as? [String: Int])?["wood"], 6)
    XCTAssertEqual((after["materials"] as? [String: Int])?["wood"], 8)
  }

  func testStorehouseIsARealBuilding() {
    XCTAssertNotNil(BuildingID(rawValue: "storehouse"))
  }

  func testIonHaulUsesSharedRoomAndForecastMatchesResolution() throws {
    var s = try ConstructionTests().work()
    s.materials = .init(wood: 13, stone: 6)
    s = try ConstructionTests().assign(s, .ion, .gatherWood)
    let haul = Materials.forecast(s)
    XCTAssertEqual(haul.gained, .init(wood: 1))
    XCTAssertEqual(haul.expected, .init(wood: 2))
    XCTAssertFalse(Rules.preview(s).warnings.filter { $0.contains("Limited storage") }.isEmpty)
    s = try Rules.dispatch(s, action: .init(type: "resolve", revision: s.revision))
    XCTAssertEqual(s.materials, .init(wood: 14, stone: 6))
    XCTAssertEqual(s.lastMaterialHaul, haul.gained)
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(s)), s)
  }

  func testBuyingIsImmediateAtomicAndPreservesReservedCoins() throws {
    var s = try ConstructionTests().work()
    s.money = 5
    s = try ConstructionTests().assign(s, .ion, .supplies)
    try Materials.buy(.wood, quantity: 1, state: &s)
    XCTAssertEqual(s.money, 4)
    XCTAssertEqual(s.materials.wood, 7)
    let before = s
    for quantity in [0, -1, 100001, Int.max, 2] {
      XCTAssertThrowsError(try Materials.buy(.stone, quantity: quantity, state: &s))
      XCTAssertEqual(s, before)
    }
    s.money = 100
    s.materials = .init(stone: 20)
    let full = s
    XCTAssertThrowsError(try Materials.buy(.wood, quantity: 1, state: &s))
    XCTAssertEqual(s, full)
    XCTAssertEqual(s.assignments, before.assignments)
  }

  func testCraftingConsumesIngredientsFirstAndProtectsReservations() throws {
    var s = try ConstructionTests().work()
    s.materials = .init(wood: 20)
    try Materials.craftPlanks(quantity: 2, state: &s)
    XCTAssertEqual(s.materials, .init(wood: 16, planks: 2))
    XCTAssertEqual(s.money, 12)
    XCTAssertEqual(s.assignments["ion"], .rest)
    s.materials = .init(wood: 4)
    s = try ConstructionTests().assign(s, .ion, .buildWoodshed)
    let before = s
    XCTAssertThrowsError(try Materials.craftPlanks(quantity: 1, state: &s))
    XCTAssertEqual(s, before)
    XCTAssertThrowsError(try Construction.start(.apiary, state: &s))
    XCTAssertEqual(s, before)
    s.materials = .init(wood: 20, stone: 4)
    let overfull = s
    XCTAssertThrowsError(try Materials.craftPlanks(quantity: 1, state: &s))
    XCTAssertEqual(s, overfull)
    XCTAssertThrowsError(try Materials.craftPlanks(quantity: Int.max, state: &s))
  }

  func testSeasonalBuildersReserveAndSpendMaterialsWithoutUsingFutureGathering() throws {
    var s = try ConstructionTests().work()
    s.materials = .init(wood: 4)
    s = try ConstructionTests().assign(s, .ion, .buildWoodshed)
    XCTAssertEqual(Materials.available(s), .init())
    XCTAssertEqual(Materials.forecast(s).gained, .init())
    s = try Rules.dispatch(s, action: .init(type: "resolve", revision: s.revision))
    XCTAssertEqual(s.materials, .init())
    var future = try ConstructionTests().work()
    future.materials = .init()
    future = try ConstructionTests().assign(future, .ion, .gatherWood)
    XCTAssertThrowsError(try ConstructionTests().assign(future, .ion, .buildWoodshed))
    XCTAssertThrowsError(try Construction.start(.woodshed, state: &future))
  }

  func testHouseAndStorehouseExpandStorageAndDowngradeNeverDestroysStock() throws {
    var s = Rules.newGame()
    s.money = 100
    s.materials = .init(wood: 6, stone: 2, planks: 2)
    XCTAssertLessThanOrEqual(Construction.materialCost(.storehouse).total, Materials.capacity(s))
    try Construction.start(.storehouse, state: &s)
    XCTAssertEqual(s.materials, .init())
    XCTAssertEqual(Materials.capacity(s), 20)
    Construction.resolveSeason(state: &s)
    XCTAssertEqual(Materials.capacity(s), 60)
    s.materials = .init(wood: 4, stone: 4, planks: 2)
    try Materials.upgradeHouse(state: &s)
    XCTAssertEqual(s.houseLevel, 2)
    XCTAssertEqual(s.house, 55)
    XCTAssertEqual(Materials.capacity(s), 70)
    s.buildings[0].level = 2
    s.buildings[0].condition = 1
    s.materials = .init(stone: 100)
    s.season = 1
    Construction.resolveSeason(state: &s)
    XCTAssertEqual(Materials.capacity(s), 70)
    XCTAssertEqual(s.materials.stone, 100)
    XCTAssertThrowsError(try Materials.buy(.wood, quantity: 1, state: &s))
    XCTAssertEqual(Materials.forecast(s).gained, .init())
    s.buildings[0].condition = 0
    XCTAssertEqual(Materials.capacity(s), 70)
  }

  func testConstructionFailuresLeaveCoinsAndMaterialsUntouched() throws {
    var s = Rules.newGame()
    s.materials = .init()
    let before = s
    XCTAssertThrowsError(try Construction.start(.woodshed, state: &s))
    XCTAssertEqual(s, before)
    s.materials = Materials.starter
    s.money = 0
    let noMoney = s
    XCTAssertThrowsError(try Construction.start(.woodshed, state: &s))
    XCTAssertEqual(s, noMoney)
    s.buildings = [.init(id: .woodshed, completedSeason: 0, legacyAssignment: false, condition: 10)]
    let worn = s
    XCTAssertThrowsError(try Construction.upgrade(.woodshed, state: &s))
    XCTAssertEqual(s, worn)
    XCTAssertThrowsError(try Construction.repair(.woodshed, state: &s))
    XCTAssertEqual(s, worn)
    s.materials = .init(wood: 2, stone: 2, planks: 1)
    let house = s
    XCTAssertThrowsError(try Materials.upgradeHouse(state: &s))
    XCTAssertEqual(s, house)
  }

  func testCurrentMaterialSchemaValidation() throws {
    var s = try ConstructionTests().work()
    s = try ConstructionTests().assign(s, .ion, .buildWoodshed)
    var object = try JSONSerialization.jsonObject(with: SaveCodec.encode(s)) as! [String: Any]
    for value: Any in [-1, 100001, true, "2", 1.5] {
      object["materials"] = ["wood": value, "stone": 0, "planks": 0]
      XCTAssertThrowsError(try SaveCodec.decode(JSONSerialization.data(withJSONObject: object)))
    }
    object["materials"] = ["wood": 0, "stone": 0, "planks": 0]
    XCTAssertThrowsError(try SaveCodec.decode(JSONSerialization.data(withJSONObject: object)))
    object["materials"] = ["wood": 6, "stone": 4, "planks": 0]
    for level in [0, 6] {
      object["houseLevel"] = level
      XCTAssertThrowsError(try SaveCodec.decode(JSONSerialization.data(withJSONObject: object)))
    }
    object.removeValue(forKey: "materials")
    XCTAssertThrowsError(try SaveCodec.decode(JSONSerialization.data(withJSONObject: object)))
  }

  func testDiscardFreesSharedSpaceButCannotStealReservedMaterials() throws {
    var s = try ConstructionTests().work()
    s.materials = .init(stone: 20)
    try Materials.discard(.stone, quantity: 1, state: &s)
    try Materials.buy(.wood, quantity: 1, state: &s)
    XCTAssertEqual(s.materials, .init(wood: 1, stone: 19))
    XCTAssertEqual(s.money, 11)
    s.materials = .init(wood: 4)
    s = try ConstructionTests().assign(s, .ion, .buildWoodshed)
    let before = s
    for quantity in [1, 0, -1, Int.max] {
      XCTAssertThrowsError(try Materials.discard(.wood, quantity: quantity, state: &s))
      XCTAssertEqual(s, before)
    }
  }
}
