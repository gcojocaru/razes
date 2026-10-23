import Foundation

public enum SkillID: String, Codable, CaseIterable, Sendable {
  case farming, gathering, building
  public var title: String { rawValue.capitalized }
}

public struct CharacterState: Codable, Equatable, Sendable {
  public var health = 100, energy = 100, hunger = 0
  public var farmingXP = 0, gatheringXP = 0, buildingXP = 0
  public init() {}

  public subscript(_ skill: SkillID) -> Int {
    get {
      switch skill {
      case .farming: farmingXP
      case .gathering: gatheringXP
      case .building: buildingXP
      }
    }
    set {
      switch skill {
      case .farming: farmingXP = newValue
      case .gathering: gatheringXP = newValue
      case .building: buildingXP = newValue
      }
    }
  }
  public func level(_ skill: SkillID) -> Int { min(5, 1 + self[skill] / 3) }
}

public struct CharacterWeek: Codable, Equatable, Sendable {
  public var before = CharacterState(), after = CharacterState()
  public var energyCost = 0, starvationDamage = 0, exposureDamage = 0
  public var fatal: Bool { after.health == 0 }
  public var deathCause: String? {
    guard fatal else { return nil }
    if starvationDamage > 0 && exposureDamage > 0 { return "Starvation and winter exposure" }
    return starvationDamage > 0 ? "Starvation" : "Winter exposure"
  }
}

public enum CharacterSimulation {
  public static func energyCost(_ task: TaskID, character: CharacterState) -> Int {
    guard task != .rest else { return 0 }
    return (task == .paid || task == .supplies ? 10 : 20) + (character.health < 25 ? 10 : 0)
  }

  public static func week(
    _ state: GameState, task: TaskID, deficit: Int, shelter: Int, haul: MaterialStock
  ) -> CharacterWeek {
    var result = CharacterWeek(before: state.character, after: state.character)
    let exposed = state.season == 3 && shelter < Content.shared.balance.coldThreshold
    result.energyCost = energyCost(task, character: state.character)
    result.after.energy = min(
      100,
      max(0, state.character.energy + (task == .rest ? (exposed ? 25 : 35) : -result.energyCost)))
    result.after.hunger = min(
      100, max(0, state.character.hunger + (deficit > 0 ? 25 * deficit : -25)))
    result.starvationDamage = result.after.hunger >= 75 ? 15 : 0
    result.exposureDamage = exposed ? 10 : 0
    let damage = result.starvationDamage + result.exposureDamage
    let healing = task == .rest && damage == 0 ? 10 : 0
    result.after.health = min(100, max(0, state.character.health - damage + healing))
    let skill: SkillID?
    switch task {
    case .plant, .tend, .harvest: skill = .farming
    case .gatherWood, .gatherStone: skill = haul.total > 0 ? .gathering : nil
    case .repair: skill = shelter > state.house ? .building : nil
    case .buildWoodshed, .buildCellar: skill = .building
    default: skill = nil
    }
    if let skill { result.after[skill] = min(12, result.after[skill] + 1) }
    return result
  }
}
