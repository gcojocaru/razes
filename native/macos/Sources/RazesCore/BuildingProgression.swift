import Foundation

extension Construction {
  public static func spend(_ cost: Int, state: inout GameState) throws {
    let reserved = state.phase == .work ? Rules.preview(state).moneyCost : 0
    guard state.money - reserved >= cost else {
      throw GameError("Needs \(cost) free coins. Money reserved for seasonal work cannot be spent.")
    }
    state.money -= cost
  }
  public static func start(_ id: BuildingID, state: inout GameState) throws {
    guard stage(id, state: state) == .empty else {
      throw GameError("This building already exists or has a seasonal builder.")
    }
    try spend(definition(id).cost, state: &state)
    state.buildings.append(
      .init(id: id, completedSeason: state.turn, legacyAssignment: false, level: 0))
  }
  public static func upgrade(_ id: BuildingID, state: inout GameState) throws {
    guard let index = state.buildings.firstIndex(where: { $0.id == id }),
      (1...4).contains(state.buildings[index].level)
    else { throw GameError("An upgrade needs a completed building below level 5.") }
    try spend(upgradeCost(state.buildings[index]), state: &state)
    state.buildings[index].level += 1
    state.buildings[index].condition = 100
  }
  public static func repair(_ id: BuildingID, state: inout GameState) throws {
    guard let index = state.buildings.firstIndex(where: { $0.id == id }),
      state.buildings[index].level > 0,
      state.buildings[index].condition < 100
    else { throw GameError("Repairs need a completed, worn building.") }
    try spend(repairCost(id), state: &state)
    state.buildings[index].condition = 100
  }
  public static func seasonalYield(_ state: GameState) -> (food: Int, money: Int) {
    var food = 0
    var money = 0
    for r in state.buildings where r.level > 0 && r.condition > 0 && r.completedSeason < state.turn
    {
      let d = definition(r.id)
      food += d.food * r.level
      money += d.coins * r.level
    }
    return (food, money)
  }
  public static func resolveSeason(state: inout GameState, produce: Bool = true) {
    if produce {
      let yield = seasonalYield(state)
      state.food = min(100000, state.food + yield.food)
      state.money = min(100000, state.money + yield.money)
    }
    for index in state.buildings.indices {
      if state.buildings[index].level == 0 {
        state.buildings[index].level = 1
        state.buildings[index].completedSeason = state.turn
      } else if state.buildings[index].completedSeason < state.turn
        && state.buildings[index].condition > 0
      {
        state.buildings[index].condition = max(0, state.buildings[index].condition - 20)
        if state.buildings[index].condition == 0 && state.buildings[index].level > 1 {
          state.buildings[index].level -= 1
          state.buildings[index].condition = 60
        }
      }
    }
  }
}
