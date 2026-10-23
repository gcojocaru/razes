import Foundation

public enum Rules {
  private static let b = Content.shared.balance
  public static func newGame() -> GameState {
    var s = GameState()
    s.food = b.initial.food
    s.money = b.initial.money
    s.house = b.initial.house
    return s
  }
  public static func task(_ id: TaskID) -> Task {
    if let gathering = Materials.gatheringTask(id) { return gathering }
    if let building = Construction.building(for: id) {
      let definition = Construction.definition(building)
      return Task(
        id: id, name: "Build \(definition.title.lowercased())", description: definition.benefit,
        icon: "hammer", workers: 1, moneyCost: definition.cost, foodCost: 0, foodGain: 0,
        moneyGain: 0, houseGain: 0)
    }
    return Content.shared.tasks[id.rawValue]!
  }
  public static func consumption(_ state: GameState, house: Int) -> Int {
    guard state.season == 3 && state.isMonthEnd else { return b.consumption }
    return b.consumption + (house < b.coldThreshold ? b.coldFood : 0)
      - (Construction.active(.woodshed, state: state) ? 1 : 0)
  }
  public static func task(_ id: TaskID, in state: GameState) -> Task {
    var value = task(id)
    switch id {
    case .harvest:
      value.foodGain = Farming.foodYield(state)
      value.description =
        "Gather ripe grain before winter: \(value.foodGain) food and \(Farming.seedYield(state)) seeds."
    case .repair:
      value.houseGain = b.repairGain + 5 * (state.character.level(.building) - 1)
      value.description = "Restore up to \(value.houseGain) shelter for \(value.moneyCost) coins."
    case .supplies:
      value.foodGain = suppliesGain(state)
      value.description = "Bring home \(value.foodGain) food before this week’s meal."
    case .gatherWood, .gatherStone:
      let material = id == .gatherWood ? "wood" : "stone"
      value.description =
        "Bring home up to \(Materials.gatheringYield(id, state: state)) \(material), limited by shared storage."
    default: break
    }
    return value
  }
  public static func weathering(_ state: GameState) -> Int {
    guard state.isSeasonEnd else { return 0 }
    return state.season == 3 && Construction.active(.woodshed, state: state)
      ? 6 : b.wear[state.season]
  }
  public static func suppliesGain(_ state: GameState) -> Int {
    Construction.active(.cellar, state: state) ? 10 : b.supplyGain
  }
  public static func taskOptions(_ s: GameState) -> [Task] {
    guard s.phase == .work else { return [] }
    var tasks: [TaskID] = []
    // shortcut: all farmland shares one crop cycle and yield; split crops when area affects production.
    if s.season == 0 && !s.planted && !s.layout.farmland.isEmpty { tasks.append(.plant) }
    if Farming.canTend(s) { tasks.append(.tend) }
    if Farming.canHarvest(s) { tasks.append(.harvest) }
    let construction = Construction.definitions.filter {
      Construction.unavailable($0.id, state: s) == nil
    }.compactMap { $0.task }
    return
      (tasks
      + [TaskID.repair, .paid, .supplies, .gatherWood, .gatherStone, .rest]
      + construction).map { task($0, in: s) }
  }
  public static func preview(_ s: GameState) -> Projection {
    var p = Projection()
    p.consumption = consumption(s, house: s.house)
    p.wear = weathering(s)
    let assigned = WorkerID.allCases.compactMap { s.assignments[$0.rawValue] }
    for id in assigned {
      let task = task(id, in: s)
      p.foodCost += task.foodCost
      p.moneyCost += task.moneyCost
      p.foodGain += task.foodGain
      p.moneyGain += task.moneyGain
      p.houseGain += task.houseGain
    }
    if s.isSeasonEnd {
      let buildingYield = Construction.seasonalYield(s)
      p.foodGain += buildingYield.food
      p.moneyGain += buildingYield.money
    }
    let harvesters = assigned.filter { $0 == .harvest }.count
    if assigned.contains(.plant) { p.seedCost = Farming.seedCost }
    if harvesters == 1 {
      p.seedGain = Farming.seedYield(s)
    }
    p.seedsAfter = min(100000, s.seeds - p.seedCost + p.seedGain)
    if p.moneyCost > s.money {
      p.errors.append("Work costs \(p.moneyCost) money; only \(s.money) is available now.")
    }
    if p.seedCost > s.seeds {
      p.errors.append(
        "Sowing needs \(p.seedCost) grain seeds; only \(s.seeds) are available. Buy seeds first.")
    }
    let materialCost = Materials.reserved(s)
    if !s.materials.contains(materialCost) {
      p.errors.append("Building work needs \(materialCost.text) already in storage.")
    }
    let haul = Materials.forecast(s)
    if haul.gained != haul.expected {
      p.warnings.append(
        "Limited storage: bring home \(haul.gained.text). Free storage limits Ion’s haul.")
    }
    let repaired = min(100, s.house + p.houseGain)
    p.consumption = consumption(s, house: repaired)
    p.foodAfter = min(100000, s.food - p.foodCost + p.foodGain) - p.consumption
    p.moneyAfter = min(100000, s.money - p.moneyCost + p.moneyGain)
    p.houseAfter = max(0, repaired - p.wear)
    let work = s.assignments["ion"] ?? .rest
    p.character = CharacterSimulation.week(
      s, task: work, deficit: max(0, -p.foodAfter), shelter: repaired, haul: haul.gained)
    if p.character.energyCost > s.character.energy {
      p.errors.append(
        "Ion needs \(p.character.energyCost) energy; he has \(s.character.energy). Assign Rest first."
      )
    }
    if p.character.starvationDamage > 0 {
      p.warnings.append(
        "Starvation: Ion will lose \(p.character.starvationDamage) health. Buy provisions or harvest food."
      )
    }
    if p.character.exposureDamage > 0 {
      p.warnings.append(
        "Winter exposure: Ion will lose \(p.character.exposureDamage) health. Mend the house to reach 40 shelter."
      )
    }
    if p.character.fatal {
      p.warnings.append(
        "This week will kill Ion: \(p.character.deathCause!). Review his needs and supplies before confirming."
      )
    }
    if p.foodAfter < 0 {
      p.warnings.append(
        "Expected food shortfall: \(-p.foodAfter). Food will fall to zero; the shortfall appears in the week’s report."
      )
    }
    if p.seedsAfter < Farming.seedCost {
      p.warnings.append("Fewer than 4 seeds remain. Harvest or buy seeds before the next sowing.")
    }
    if p.houseAfter < b.coldThreshold {
      p.warnings.append("The house will be vulnerable. Cold winter shelter needs extra food.")
    }
    if s.season == 0 && s.isSeasonEnd && !s.planted && !assigned.contains(.plant) {
      p.warnings.append("Without planting now, there will be no autumn harvest.")
    }
    if s.season == 2 && s.isSeasonEnd && s.planted && !s.harvested && harvesters == 0 {
      p.warnings.append("The unharvested crop will be lost when winter comes.")
    }
    return p
  }
  public static func assignmentProblem(_ s: GameState, worker: WorkerID, task: TaskID) -> String? {
    if s.phase == .dead { return "Ion has died. Start a fresh household to play again." }
    if task == .plant, let reason = Farming.plantingProblem(s) { return reason }
    if s.phase != .work { return "Continue to the next week before assigning work." }
    if !taskOptions(s).contains(where: { $0.id == task }) {
      return "That task is unavailable this week."
    }
    var candidate = s
    candidate.assignments[worker.rawValue] = task
    return preview(candidate).errors.first
  }
  public static func dispatch(_ state: GameState, action a: Action) throws -> GameState {
    guard state.phase != .dead else {
      throw GameError("Ion has died. Start a fresh household to play again.")
    }
    guard a.revision == state.revision else {
      throw GameError("This choice has already changed. Please use the current controls.")
    }
    var s = state
    switch a.type {
    case "assign":
      guard let worker = a.worker, let task = a.task else {
        throw GameError("Unknown work assignment.")
      }
      if let problem = assignmentProblem(s, worker: worker, task: task) { throw GameError(problem) }
      if let id = Construction.building(for: task),
        Settlement.position(for: id, in: s.layout) == nil
      {
        guard let point = Settlement.firstAvailable(id, in: s.layout) else {
          throw GameError("There is no free space for that building.")
        }
        s.layout.buildings.append(.init(id: id, position: point))
      }
      s.assignments[worker.rawValue] = task
    case "resolve":
      guard s.phase == .work else { throw GameError("Work has already been resolved.") }
      if let task = s.assignments[WorkerID.ion.rawValue],
        let problem = assignmentProblem(s, worker: .ion, task: task)
      {
        throw GameError(problem)
      }
      let p = preview(s)
      if let problem = p.errors.first { throw GameError(problem) }
      s.report = SeasonReport(
        foodBefore: s.food, foodAfter: 0, moneyBefore: s.money, moneyAfter: 0, houseBefore: s.house,
        houseAfter: 0, consumption: p.consumption, wear: p.wear, deficit: 0,
        tasks: WorkerID.allCases.map {
          "\(Content.shared.people[$0.rawValue]!.name): \(task(s.assignments[$0.rawValue]!).name)"
        }, seedsBefore: s.seeds, seedsAfter: p.seedsAfter, character: p.character)
      s.food = min(100000, s.food - p.foodCost + p.foodGain)
      s.money = min(100000, s.money - p.moneyCost + p.moneyGain)
      s.house = min(100, s.house + p.houseGain)
      s.seeds = p.seedsAfter
      Materials.collect(state: &s)
      let tasks = Array(s.assignments.values)
      for definition in Construction.definitions where definition.task.map(tasks.contains) == true {
        s.buildings.append(BuildingRecord(id: definition.id, completedSeason: s.turn, level: 0))
      }
      if tasks.contains(.plant) { s.planted = true }
      if tasks.contains(.tend) { s.tended = true }
      if tasks.contains(.harvest) { s.harvested = true }
      if s.planted && !s.harvested && s.season != 3 {
        s.cropWeeks = min(Farming.growingWeeks, s.cropWeeks + 1)
      }
      let deficit = max(0, p.consumption - s.food)
      s.food = max(0, s.food - p.consumption)
      s.house = max(0, s.house - p.wear)
      s.report?.foodAfter = s.food
      s.report?.moneyAfter = s.money
      s.report?.houseAfter = s.house
      s.report?.deficit = deficit
      if s.isSeasonEnd { Construction.resolveSeason(state: &s, produce: false) }
      s.character = p.character.after
      s.phase = p.character.fatal ? .dead : .summary
    case "continue":
      guard s.phase == .summary else { throw GameError("Finish this week before continuing.") }
      guard s.turn < 400003 || !s.isSeasonEnd else {
        throw GameError("This settlement has reached its calendar limit.")
      }
      if s.isSeasonEnd {
        s.week = 0
        if s.season == 3 {
          s.year += 1
          s.season = 0
          s.planted = false
          s.tended = false
          s.harvested = false
          s.cropWeeks = 0
        } else {
          s.season += 1
        }
      } else {
        s.week += 1
      }
      s.phase = .work
      s.assignments = newGame().assignments
      s.report = nil
      s.lastMaterialHaul = nil
    default: throw GameError("Unknown action.")
    }
    s.revision += 1
    return s
  }
  public static func fieldLabel(_ s: GameState) -> String {
    Farming.label(s)
  }
}
