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
  public static func currentEvent(_ s: GameState) -> GameEvent {
    precondition(s.phase == .opening || s.phase == .consequence)
    let opening = s.phase == .opening
    let id: String
    switch s.season {
    case 0: id = opening ? "spring-ox" : "spring-table"
    case 1: id = opening ? "summer-brother" : (s.tended ? "summer-tended" : "summer-dry")
    case 2:
      id = opening ? (s.ox == "borrowed" ? "autumn-promise" : "autumn-free") : "autumn-dispute"
    default:
      id =
        opening
        ? (s.ox == "broken" ? "winter-isolation" : "winter-friend")
        : (s.house < b.coldThreshold ? "winter-cold" : "winter-hearth")
    }
    return Content.shared.events[id]!
  }
  public static func task(_ id: TaskID) -> Task {
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
    let base = winter && Construction.active(.woodshed, state: state) ? 6 : b.consumption
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
    if s.season == 0 && !s.planted { tasks.append(t["plant"]!) }
    if s.season == 1 && s.planted && !s.tended { tasks.append(t["tend"]!) }
    if s.season == 2 && s.planted && !s.harvested {
      var harvest = t["harvest"]!
      harvest.foodGain = b.harvest + s.cropBonus + (s.tended ? b.tendedBonus : 0)
      tasks.append(harvest)
    }
    let construction = Construction.definitions.filter {
      Construction.unavailable($0.id, state: s) == nil
    }.compactMap { $0.task.map(task) }
    return tasks
      + [TaskID.repair, .paid, .help, .supplies, .rest].map { id in
        var value = task(id)
        if id == .supplies { value.foodGain = suppliesGain(s) }
        return value
      } + construction
  }
  public static func choiceProblem(_ s: GameState, choice c: Choice) -> String? {
    if s.money + (c.effect.money ?? 0) < 0 {
      return "Needs \(-(c.effect.money ?? 0)) money; you have \(s.money)."
    }
    if s.food + (c.effect.food ?? 0) < 0 {
      return "Needs \(-(c.effect.food ?? 0)) food; you have \(s.food)."
    }
    return nil
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
    if s.season == 2 && s.fairShare { p.foodGain += b.fairShareFood }
    let harvesters = assigned.filter { $0 == .harvest }.count
    if harvesters == 1 {
      p.errors.append("Harvest needs two adults. Assign one more, or choose different work.")
    }
    if harvesters > 2 {
      p.errors.append("Harvest needs only two adults. Give the third adult different work.")
    }
    if harvesters == 2 { p.foodGain += b.harvest + s.cropBonus + (s.tended ? b.tendedBonus : 0) }
    if p.moneyCost > s.money {
      p.errors.append("Work costs \(p.moneyCost) money; only \(s.money) is available now.")
    }
    if p.foodCost > s.food {
      p.errors.append("Planting needs \(p.foodCost) food for seed; only \(s.food) is available.")
    }
    let repaired = min(100, s.house + p.houseGain)
    p.consumption = consumption(s, house: repaired)
    p.foodAfter = min(100000, s.food - p.foodCost + p.foodGain) - p.consumption
    p.moneyAfter = min(100000, s.money - p.moneyCost + p.moneyGain)
    p.houseAfter = max(0, repaired - p.wear)
    if p.foodAfter < 0 {
      p.warnings.append(
        "Expected food shortfall: \(-p.foodAfter). This will be recorded as hardship unless the evening event provides relief."
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
    if s.phase != .work { return "Choose the seasonal event before assigning work." }
    if s.reservedWorker == worker.rawValue {
      return "This adult is reserved for your promise to Vasile."
    }
    if !taskOptions(s).contains(where: { $0.id == task }) {
      return "That task is unavailable this season."
    }
    var candidate = s
    candidate.assignments[worker.rawValue] = task
    for exclusive in [TaskID.plant, .tend, .buildWoodshed, .buildCellar] {
      if candidate.assignments.values.filter({ $0 == exclusive }).count > 1 {
        return "Only one adult is needed for that task."
      }
    }
    return preview(candidate).errors.first { !$0.hasPrefix("Harvest needs two") }
  }
  public static func dispatch(_ state: GameState, action a: Action) throws -> GameState {
    guard a.revision == state.revision else {
      throw GameError("This choice has already changed. Please use the current controls.")
    }
    guard state.phase != .ending else {
      throw GameError("This year is complete. Begin a new household to play again.")
    }
    var s = state
    switch a.type {
    case "choose":
      guard s.phase == .opening || s.phase == .consequence else {
        throw GameError("There is no event to choose right now.")
      }
      let event = currentEvent(s)
      guard a.event == event.id, !s.history.contains(where: { $0.event == event.id }) else {
        throw GameError("This event is no longer available.")
      }
      guard let c = event.choices.first(where: { $0.id == a.choice }) else {
        throw GameError("That choice is not available.")
      }
      if let problem = choiceProblem(s, choice: c) { throw GameError(problem) }
      let e = c.effect
      s.food = min(100000, s.food + (e.food ?? 0))
      s.money = min(100000, s.money + (e.money ?? 0))
      s.house = max(0, min(100, s.house + (e.house ?? 0)))
      s.trust = max(-5, min(5, s.trust + (e.trust ?? 0)))
      if let ox = e.ox { s.ox = ox }
      if let share = e.fairShare { s.fairShare = share }
      if e.reserve == true {
        s.reservedWorker = "petru"
        s.assignments["petru"] = .help
      }
      if let m = c.memory {
        s.memories.append(
          Memory(
            id: "\(event.id):\(c.id)", title: m.title, detail: m.detail, season: s.season,
            tone: m.tone))
      }
      s.history.append(
        HistoryEntry(
          event: event.id, choice: c.id, title: c.label, detail: c.memory?.detail ?? c.detail,
          season: s.season))
      if s.phase == .opening {
        s.phase = .work
      } else {
        let consumption = consumption(s, house: s.house)
        let deficit = max(0, consumption - s.food)
        s.food = max(0, s.food - consumption)
        let appliedWear = weathering(s)
        s.house = max(0, s.house - appliedWear)
        s.report?.wear = appliedWear
        if deficit > 0 {
          s.hardship.append(Hardship(season: s.season, kind: "food", amount: deficit))
        }
        if s.house < b.survivalHouse {
          s.hardship.append(
            Hardship(season: s.season, kind: "shelter", amount: b.survivalHouse - s.house))
        }
        s.report?.foodAfter = s.food
        s.report?.moneyAfter = s.money
        s.report?.houseAfter = s.house
        s.report?.consumption = consumption
        s.report?.deficit = deficit
        s.phase = .summary
      }
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
      let tasks = Array(s.assignments.values)
      for definition in Construction.definitions where definition.task.map(tasks.contains) == true {
        s.buildings.append(BuildingRecord(id: definition.id, completedSeason: s.season))
      }
      if tasks.contains(.plant) {
        s.planted = true
        s.cropBonus = ["borrowed", "paid"].contains(s.ox) ? b.oxBonus : 0
      }
      if tasks.contains(.tend) { s.tended = true }
      if tasks.contains(.harvest) { s.harvested = true }
      if tasks.contains(.help) {
        s.trust = min(5, s.trust + 1)
        s.memories.append(
          Memory(
            id: "help-\(s.season)", title: "A hand across the fence",
            detail: s.reservedWorker != nil
              ? "Petru spent his assignment fulfilling the autumn promise. Vasile shared a meal in thanks."
              : "Your household made time for Vasile’s work. A shared meal and a warmer friendship came home with you.",
            season: s.season, tone: "good"))
      }
      s.phase = .consequence
    case "continue":
      guard s.phase == .summary else { throw GameError("Finish this season before continuing.") }
      if s.season == 3 {
        s.phase = .ending
      } else {
        s.season += 1
        s.phase = .opening
        s.assignments = newGame().assignments
        s.reservedWorker = nil
        s.report = nil
      }
    default: throw GameError("Unknown action.")
    }
    s.revision += 1
    return s
  }
  public static func ending(_ s: GameState) -> Ending {
    let crisis = s.house < b.survivalHouse || s.hardship.contains { $0.kind == "food" }
    let secure = !crisis && s.hardship.isEmpty && s.food >= b.seed && s.house >= b.coldThreshold
    let decisions = [
      s.history.first { $0.event == "autumn-promise" }
        ?? s.history.first { $0.event == "spring-ox" },
      s.history.first { $0.event == "summer-brother" },
      s.history.first { $0.event == "autumn-dispute" },
    ].compactMap { $0 }
    return Ending(
      category: crisis ? "crisis" : secure ? "secure" : "cost",
      title: crisis
        ? "A home in need of help"
        : secure ? "A home worth keeping" : "Through the winter, together",
      text: crisis
        ? "You reached the end of the year, but hunger or unsafe shelter has left the household needing outside support. The story is not a failure of care. It is a measure of what three people could carry."
        : secure
          ? "There is grain for the next sowing, a roof against the rain, and room to think beyond tomorrow. The year asked much of you. You have given this home another spring."
          : "You have made it through, though the year has left its mark. Before the next sowing, seed or shelter will need attention. What you have kept together is worth the work ahead.",
      decisions: decisions)
  }
  public static func seasonSubtitle(_ s: GameState) -> String {
    [
      "The earth wakes. So does possibility.", "Long days. More work than hands.",
      "What we planted. What we promised.", "A little warmth against the world.",
    ][s.season]
  }
  public static func fieldLabel(_ s: GameState) -> String {
    if s.season == 3 { return "Resting beneath the snow" }
    if s.harvested { return "Harvest safely gathered" }
    if s.planted {
      return s.season == 0
        ? "Sown for the seasons ahead"
        : s.season == 1 ? "Growing through the summer" : "Ready for two pairs of hands"
    }
    return "Waiting to be sown"
  }
}
