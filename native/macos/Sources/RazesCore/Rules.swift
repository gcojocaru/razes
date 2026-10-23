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
    let winter = state.season == 3
    let base = winter && Construction.active(.woodshed, state: state) ? 2 : b.consumption
    return base + (winter && house < b.coldThreshold ? b.coldFood : 0)
  }
  public static func weathering(_ state: GameState) -> Int {
    state.season == 3 && Construction.active(.woodshed, state: state) ? 6 : b.wear[state.season]
  }
  public static func suppliesGain(_ state: GameState) -> Int {
    Construction.active(.cellar, state: state) ? 10 : b.supplyGain
  }
  public static func taskOptions(_ s: GameState) -> [Task] {
    let t = Content.shared.tasks
    var tasks: [Task] = []
    // shortcut: all farmland shares one crop cycle and yield; split crops when area affects production.
    if s.season == 0 && !s.planted && !s.layout.farmland.isEmpty { tasks.append(t["plant"]!) }
    if s.season == 1 && s.planted && !s.tended { tasks.append(t["tend"]!) }
    if s.season == 2 && s.planted && !s.harvested {
      var harvest = t["harvest"]!
      harvest.foodGain = b.harvest + (s.tended ? b.tendedBonus : 0)
      tasks.append(harvest)
    }
    let construction = Construction.definitions.filter {
      Construction.unavailable($0.id, state: s) == nil
    }.compactMap { $0.task.map(task) }
    return tasks
      + [TaskID.repair, .paid, .supplies, .gatherWood, .gatherStone, .rest].map { id in
        var value = task(id)
        if id == .supplies { value.foodGain = suppliesGain(s) }
        return value
      } + construction
  }
  public static func preview(_ s: GameState) -> Projection {
    var p = Projection()
    p.consumption = consumption(s, house: s.house)
    p.wear = weathering(s)
    let assigned = WorkerID.allCases.compactMap { s.assignments[$0.rawValue] }
    for id in assigned {
      let task = task(id)
      p.foodCost += task.foodCost
      p.moneyCost += task.moneyCost
      p.foodGain += id == .supplies ? suppliesGain(s) : task.foodGain
      p.moneyGain += task.moneyGain
      p.houseGain += task.houseGain
    }
    let buildingYield = Construction.seasonalYield(s)
    p.foodGain += buildingYield.food
    p.moneyGain += buildingYield.money
    let harvesters = assigned.filter { $0 == .harvest }.count
    if harvesters == 1 { p.foodGain += b.harvest + (s.tended ? b.tendedBonus : 0) }
    if p.moneyCost > s.money {
      p.errors.append("Work costs \(p.moneyCost) money; only \(s.money) is available now.")
    }
    if p.foodCost > s.food {
      p.errors.append("Planting needs \(p.foodCost) food for seed; only \(s.food) is available.")
    }
    let materialCost = Materials.reserved(s)
    if !s.materials.contains(materialCost) {
      p.errors.append("Seasonal building work needs \(materialCost.text) already in storage.")
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
    if p.foodAfter < 0 {
      p.warnings.append(
        "Expected food shortfall: \(-p.foodAfter). Food will fall to zero; the shortfall appears in the season report."
      )
    } else if p.foodAfter < b.seed {
      p.warnings.append(
        "Only \(p.foodAfter) food after consumption. Next spring needs \(b.seed) for seed.")
    }
    if p.houseAfter < b.coldThreshold {
      p.warnings.append("The house will be vulnerable. Cold winter shelter needs extra food.")
    }
    if s.season == 0 && !assigned.contains(.plant) {
      p.warnings.append("Without planting now, there will be no autumn harvest.")
    }
    if s.season == 2 && s.planted && harvesters == 0 {
      p.warnings.append("The unharvested crop will be lost when winter comes.")
    }
    return p
  }
  public static func assignmentProblem(_ s: GameState, worker: WorkerID, task: TaskID) -> String? {
    if s.phase != .work { return "Continue to the next season before assigning work." }
    if task == .plant && s.layout.farmland.isEmpty {
      return "Paint farmland in Construction before sowing."
    }
    if !taskOptions(s).contains(where: { $0.id == task }) {
      return "That task is unavailable this season."
    }
    var candidate = s
    candidate.assignments[worker.rawValue] = task
    return preview(candidate).errors.first
  }
  public static func dispatch(_ state: GameState, action a: Action) throws -> GameState {
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
      let p = preview(s)
      if let problem = p.errors.first { throw GameError(problem) }
      s.report = SeasonReport(
        foodBefore: s.food, foodAfter: 0, moneyBefore: s.money, moneyAfter: 0, houseBefore: s.house,
        houseAfter: 0, consumption: p.consumption, wear: p.wear, deficit: 0,
        tasks: WorkerID.allCases.map {
          "\(Content.shared.people[$0.rawValue]!.name): \(task(s.assignments[$0.rawValue]!).name)"
        })
      s.food = min(100000, s.food - p.foodCost + p.foodGain)
      s.money = min(100000, s.money - p.moneyCost + p.moneyGain)
      s.house = min(100, s.house + p.houseGain)
      Materials.collect(state: &s)
      let tasks = Array(s.assignments.values)
      for definition in Construction.definitions where definition.task.map(tasks.contains) == true {
        s.buildings.append(BuildingRecord(id: definition.id, completedSeason: s.turn))
      }
      if tasks.contains(.plant) { s.planted = true }
      if tasks.contains(.tend) { s.tended = true }
      if tasks.contains(.harvest) { s.harvested = true }
      let deficit = max(0, p.consumption - s.food)
      s.food = max(0, s.food - p.consumption)
      s.house = max(0, s.house - p.wear)
      s.report?.foodAfter = s.food
      s.report?.moneyAfter = s.money
      s.report?.houseAfter = s.house
      s.report?.deficit = deficit
      Construction.resolveSeason(state: &s, produce: false)
      s.phase = .summary
    case "continue":
      guard s.phase == .summary else { throw GameError("Finish this season before continuing.") }
      guard s.turn < 400003 else {
        throw GameError("This settlement has reached its season limit.")
      }
      if s.season == 3 {
        s.year += 1
        s.season = 0
        s.planted = false
        s.tended = false
        s.harvested = false
      } else {
        s.season += 1
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
    if s.season == 3 { return "Resting beneath the snow" }
    if s.harvested { return "Harvest safely gathered" }
    if s.planted {
      return s.season == 0
        ? "Sown for the seasons ahead"
        : s.season == 1 ? "Growing through the summer" : "Ready for harvest"
    }
    return "Waiting to be sown"
  }
}
