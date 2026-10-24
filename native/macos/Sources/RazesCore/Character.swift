import Foundation

public enum SkillID: String, Codable, CaseIterable, Sendable {
  case farming, gathering, building, strength, endurance
  public var title: String { rawValue.capitalized }
}

public struct CharacterState: Codable, Equatable, Sendable {
  public var health = 100, energy = 100, hunger = 0
  public var farmingXP = 0, gatheringXP = 0, buildingXP = 0
  public var strengthXP = 0, enduranceXP = 0
  public init() {}

  public subscript(_ skill: SkillID) -> Int {
    get {
      switch skill {
      case .farming: farmingXP
      case .gathering: gatheringXP
      case .building: buildingXP
      case .strength: strengthXP
      case .endurance: enduranceXP
      }
    }
    set {
      switch skill {
      case .farming: farmingXP = newValue
      case .gathering: gatheringXP = newValue
      case .building: buildingXP = newValue
      case .strength: strengthXP = newValue
      case .endurance: enduranceXP = newValue
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
    let base = task == .paid || task == .supplies ? 10 : 20
    return max(5, base - 2 * (character.level(.endurance) - 1))
      + (character.health < 25 ? 10 : 0)
  }

  public static func restEnergy(character: CharacterState, exposed: Bool) -> Int {
    (exposed ? 25 : 35) + 2 * (character.level(.endurance) - 1)
  }

  public static func week(
    _ state: GameState, task: TaskID, deficit: Int, shelter: Int, haul: MaterialStock
  ) -> CharacterWeek {
    var result = CharacterWeek(before: state.character, after: state.character)
    let exposed = state.season == 3 && shelter < Content.shared.balance.coldThreshold
    result.energyCost = energyCost(task, character: state.character)
    result.after.energy = min(
      100,
      max(
        0,
        state.character.energy
          + (task == .rest
            ? restEnergy(character: state.character, exposed: exposed) : -result.energyCost)))
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
    default: skill = nil
    }
    if let skill { result.after[skill] = min(12, result.after[skill] + 1) }
    let gathering = (task == .gatherWood || task == .gatherStone) && haul.total > 0
    if task == .paid || gathering { result.after.strengthXP = min(12, result.after.strengthXP + 1) }
    if skill != nil || task == .paid || Construction.building(for: task) != nil {
      result.after.enduranceXP = min(12, result.after.enduranceXP + 1)
    }
    if state.isSeasonEnd {
      let foundations =
        state.buildings.filter { $0.level == 0 && $0.debugPlaced != true }.count
        + (Construction.building(for: task) == nil ? 0 : 1)
      result.after.buildingXP = min(12, result.after.buildingXP + foundations)
    }
    return result
  }
}
