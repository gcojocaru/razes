import XCTest

@testable import RazesCore

final class ConstructionRequirementsTests: XCTestCase {
  func stocked() -> GameState {
    var state = Rules.newGame()
    state.money = 1000
    state.materials = .init(wood: 100, stone: 100, planks: 100)
    return state
  }

  func testLockedConstructionLeavesStateUntouched() {
    var state = stocked()
    let before = state
    XCTAssertThrowsError(try Construction.start(.barn, state: &state))
    XCTAssertEqual(state, before)
    state.buildings = [.init(id: .woodshed, completedSeason: 0)]
    let completed = state
    XCTAssertThrowsError(try Construction.upgrade(.woodshed, state: &state))
    XCTAssertEqual(state, completed)
  }

  func testCraftingNeedsCompletedUsableWorkshopAndSmithyChangesRecipe() throws {
    var state = Rules.newGame()
    let before = state
    XCTAssertThrowsError(try Materials.craftPlanks(quantity: 1, state: &state))
    XCTAssertEqual(state, before)
    state.buildings = [.init(id: .workshop, completedSeason: 0, level: 0)]
    XCTAssertThrowsError(try Materials.craftPlanks(quantity: 1, state: &state))
    state.buildings[0].level = 1
    state.buildings[0].condition = 0
    XCTAssertThrowsError(try Materials.craftPlanks(quantity: 1, state: &state))
    state.buildings[0].condition = 100
    try Materials.craftPlanks(quantity: 1, state: &state)
    XCTAssertEqual(state.materials, .init(wood: 4, stone: 4, planks: 1))
    state.buildings.append(.init(id: .smithy, completedSeason: 0))
    try Materials.craftPlanks(quantity: 1, state: &state)
    XCTAssertEqual(state.materials, .init(wood: 3, stone: 4, planks: 2))
    XCTAssertEqual(state.character, before.character)
    XCTAssertEqual(state.assignments, before.assignments)
  }

  func testCompletedWellAndGranaryImmediatelyBoostHarvestWhileRuinsDoNot() {
    var state = Rules.newGame()
    let food = Farming.foodYield(state)
    let seeds = Farming.seedYield(state)
    state.buildings = [
      .init(id: .well, completedSeason: state.turn, level: 2),
      .init(id: .granary, completedSeason: state.turn, level: 3),
    ]
    XCTAssertEqual(Farming.foodYield(state), food + 4)
    XCTAssertEqual(Farming.seedYield(state), seeds + 3)
    state.buildings[0].condition = 0
    state.buildings[1].condition = 0
    XCTAssertEqual(Farming.foodYield(state), food)
    XCTAssertEqual(Farming.seedYield(state), seeds)
  }

  func testRequirementsReportEveryLockAndEveryShortage() {
    var state = Rules.newGame()
    state.money = 1
    state.materials = .init()
    let requirements = Construction.requirements(.bakery, state: state)
    XCTAssertEqual(requirements.houseLevel, 3)
    XCTAssertEqual(requirements.buildingLevel, 3)
    XCTAssertEqual(requirements.prerequisite, .granary)
    XCTAssertEqual(requirements.locks.count, 3)
    XCTAssertEqual(requirements.shortages.count, 4)
    XCTAssertEqual(requirements.problems, requirements.locks + requirements.shortages)
    XCTAssertFalse(requirements.isMet)
  }

  func testAllBlueprintGatesAndUpgradeRequirements() {
    let gates: [(BuildingID, Int, BuildingID?)] = [
      (.woodshed, 1, nil), (.cellar, 1, nil), (.well, 1, nil), (.workshop, 1, nil),
      (.barn, 2, .well), (.granary, 2, .cellar), (.apiary, 2, .well),
      (.storehouse, 2, .workshop), (.bakery, 3, .granary), (.smithy, 3, .workshop),
      (.stable, 3, .barn),
    ]
    for (id, level, prerequisite) in gates {
      var state = stocked()
      state.houseLevel = level
      state.character.buildingXP = (level - 1) * 3
      let requirements = Construction.requirements(id, state: state)
      XCTAssertEqual(requirements.houseLevel, level)
      XCTAssertEqual(requirements.buildingLevel, level)
      XCTAssertEqual(requirements.prerequisite, prerequisite)
      if let prerequisite {
        XCTAssertFalse(requirements.isMet)
        state.buildings = [.init(id: prerequisite, completedSeason: 0, condition: 0)]
      }
      XCTAssertTrue(Construction.requirements(id, state: state).isMet, id.rawValue)
      state.buildings.append(.init(id: id, completedSeason: 0))
      XCTAssertFalse(Construction.requirements(id, state: state).isMet)
      let upgrade = Construction.requirements(id, state: state, level: 5)
      XCTAssertEqual(upgrade.houseLevel, 5)
      XCTAssertEqual(upgrade.buildingLevel, 5)
      XCTAssertEqual(upgrade.materials, Construction.materialCost(id).scaled(5))
    }
  }

  func testReservationsExcludeFutureIncomeAndProtectRepairAndHouseSupplies() throws {
    var state = Rules.newGame()
    state.money = 4
    state.materials = .init(wood: 4)
    state.assignments["ion"] = .buildWoodshed
    let requirements = Construction.requirements(.cellar, state: state)
    XCTAssertEqual(requirements.freeCoins, 1)
    XCTAssertEqual(requirements.freeMaterials, .init())
    XCTAssertTrue(Construction.unlockProblems(.woodshed, state: state).isEmpty)
    state.buildings = [.init(id: .well, completedSeason: 0, condition: 0)]
    let before = state
    XCTAssertFalse(Construction.repairRequirements(.well, state: state).isMet)
    XCTAssertThrowsError(try Construction.repair(.well, state: &state))
    XCTAssertEqual(state, before)
    XCTAssertFalse(Materials.houseUpgradeRequirements(state: state).isMet)
    XCTAssertThrowsError(try Materials.upgradeHouse(state: &state))
    XCTAssertEqual(state, before)
    state.assignments["ion"] = .paid
    XCTAssertEqual(Construction.requirements(.workshop, state: state).freeCoins, 4)
  }

  func testWorkshopIsReachableWithoutPlanksAndHouseHasNoSkillGate() throws {
    var state = Rules.newGame()
    XCTAssertEqual(Construction.materialCost(.workshop), .init(wood: 4, stone: 2))
    XCTAssertTrue(Construction.requirements(.workshop, state: state).isMet)
    try Construction.start(.workshop, state: &state)
    XCTAssertEqual(state.money, 7)
    XCTAssertEqual(state.materials, .init(wood: 2, stone: 2))
    state.money = 100
    state.materials = .init(wood: 10, stone: 10, planks: 5)
    for level in 2...5 {
      XCTAssertTrue(Materials.houseUpgradeRequirements(state: state).isMet)
      try Materials.upgradeHouse(state: &state)
      XCTAssertEqual(state.houseLevel, level)
    }
    XCTAssertFalse(Materials.houseUpgradeRequirements(state: state).isMet)
  }

  func testCraftingCalculationUsesFreeWoodAndActualRecipeCapacity() throws {
    var state = Rules.newGame()
    state.buildings = [.init(id: .workshop, completedSeason: 0)]
    state.materials = .init(wood: 5)
    state.assignments["ion"] = .buildWoodshed
    XCTAssertFalse(Materials.craftingProblems(quantity: 1, state: state).isEmpty)
    state.buildings.append(.init(id: .smithy, completedSeason: 0))
    XCTAssertEqual(Materials.plankWoodCost(state: state), 1)
    XCTAssertTrue(Materials.craftingProblems(quantity: 1, state: state).isEmpty)
    try Materials.craftPlanks(quantity: 1, state: &state)
    XCTAssertEqual(state.materials, .init(wood: 4, planks: 1))
    state.buildings[1].condition = 0
    XCTAssertEqual(Materials.plankWoodCost(state: state), 2)
    state.assignments["ion"] = .rest
    state.materials = .init(wood: 21)
    XCTAssertTrue(Materials.craftingProblems(quantity: 1, state: state).isEmpty)
    state.buildings[1].condition = 100
    XCTAssertFalse(Materials.craftingProblems(quantity: 1, state: state).isEmpty)
    let before = state
    XCTAssertThrowsError(try Materials.craftPlanks(quantity: Int.max, state: &state))
    XCTAssertEqual(state, before)
  }
}
