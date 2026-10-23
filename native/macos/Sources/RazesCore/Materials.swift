import Foundation

public enum MaterialID: String, Codable, CaseIterable, Sendable {
  case wood, stone, planks
  public var title: String { rawValue.capitalized }
  public var price: Int { self == .planks ? 3 : 1 }
}

public struct MaterialStock: Codable, Equatable, Sendable {
  public var wood: Int = 0
  public var stone: Int = 0
  public var planks: Int = 0
  public init(wood: Int = 0, stone: Int = 0, planks: Int = 0) {
    self.wood = wood
    self.stone = stone
    self.planks = planks
  }
  public subscript(_ id: MaterialID) -> Int {
    get {
      switch id {
      case .wood: wood
      case .stone: stone
      case .planks: planks
      }
    }
    set {
      switch id {
      case .wood: wood = newValue
      case .stone: stone = newValue
      case .planks: planks = newValue
      }
    }
  }
  public var total: Int { wood + stone + planks }
  public var text: String {
    let parts = MaterialID.allCases.filter { self[$0] > 0 }.map { "\(self[$0]) \($0.rawValue)" }
    return parts.isEmpty ? "no materials" : parts.joined(separator: " · ")
  }
  public func scaled(_ count: Int) -> Self {
    .init(wood: wood * count, stone: stone * count, planks: planks * count)
  }
  public func contains(_ cost: Self) -> Bool {
    MaterialID.allCases.allSatisfy { self[$0] >= cost[$0] }
  }
  public static func + (lhs: Self, rhs: Self) -> Self {
    .init(wood: lhs.wood + rhs.wood, stone: lhs.stone + rhs.stone, planks: lhs.planks + rhs.planks)
  }
  public static func - (lhs: Self, rhs: Self) -> Self {
    lhs + rhs.scaled(-1)
  }
}

public struct MaterialHaul: Equatable, Sendable {
  public var gained = MaterialStock()
  public var expected = MaterialStock()
  public var lines: [String] = []
}

public enum Materials {
  public static let starter = MaterialStock(wood: 6, stone: 4)
  public static let houseUpgradeMaterials = MaterialStock(wood: 2, stone: 2, planks: 1)
  public static func capacity(_ s: GameState) -> Int {
    // Storage wear never discards stock; over-capacity households can still spend supplies.
    20 + (s.houseLevel - 1) * 10 + 40 * (s.buildings.first { $0.id == .storehouse }?.level ?? 0)
  }
  public static func reserved(_ s: GameState) -> MaterialStock {
    guard s.phase == .work else { return .init() }
    return s.assignments.values.compactMap { Construction.building(for: $0) }
      .reduce(MaterialStock()) { $0 + Construction.materialCost($1) }
  }
  public static func available(_ s: GameState) -> MaterialStock { s.materials - reserved(s) }
  public static func assignments(_ s: GameState) -> [String: TaskID] {
    s.assignments
  }
  public static func gatheringTask(_ id: TaskID) -> Task? {
    guard id == .gatherWood || id == .gatherStone else { return nil }
    return Task(
      id: id, name: id == .gatherWood ? "Gather timber" : "Gather stone",
      description: id == .gatherWood
        ? "Bring home up to 2 wood at week end, limited by shared storage."
        : "Bring home up to 1 stone at week end, limited by shared storage.",
      icon: "hammer", workers: 1, moneyCost: 0, foodCost: 0, foodGain: 0, moneyGain: 0, houseGain: 0
    )
  }
  public static func forecast(_ s: GameState) -> MaterialHaul {
    var haul = MaterialHaul()
    var room = max(0, capacity(s) - (s.materials - reserved(s)).total)
    for worker in WorkerID.allCases {
      let task = assignments(s)[worker.rawValue]
      guard task == .gatherWood || task == .gatherStone else { continue }
      let id: MaterialID = task == .gatherWood ? .wood : .stone
      let expected = id == .wood ? 2 : 1
      let received = min(expected, room)
      haul.expected[id] += expected
      haul.gained[id] += received
      room -= received
      haul.lines.append(
        "\(Content.shared.people[worker.rawValue]!.name): \(received)/\(expected) \(id.rawValue)")
    }
    return haul
  }
  public static func collect(state: inout GameState) {
    let haul = forecast(state)
    state.materials = state.materials - reserved(state) + haul.gained
    state.lastMaterialHaul = haul.expected.total > 0 ? haul.gained : nil
  }
  public static func spend(_ cost: MaterialStock, state: inout GameState) throws {
    guard available(state).contains(cost) else {
      throw GameError(
        "Needs \(cost.text) free. Supplies reserved for seasonal building work cannot be spent.")
    }
    state.materials = state.materials - cost
  }
  public static func buy(_ id: MaterialID, quantity: Int, state: inout GameState) throws {
    guard (1...100000).contains(quantity), state.materials.total + quantity <= capacity(state)
    else {
      throw GameError("Choose a positive quantity that fits in shared storage.")
    }
    try Construction.spend(quantity * id.price, state: &state)
    state.materials[id] += quantity
  }
  public static func craftPlanks(quantity: Int, state: inout GameState) throws {
    guard (1...100000).contains(quantity) else {
      throw GameError("Choose a positive plank quantity.")
    }
    let cost = MaterialStock(wood: quantity * 2)
    guard available(state).contains(cost) else { throw GameError("Each plank needs 2 free wood.") }
    guard state.materials.total - cost.total + quantity <= capacity(state) else {
      throw GameError(
        "The crafted planks must fit in shared storage after using their ingredients.")
    }
    state.materials = state.materials - cost + .init(planks: quantity)
  }
  public static func discard(_ id: MaterialID, quantity: Int, state: inout GameState) throws {
    guard (1...100000).contains(quantity), available(state)[id] >= quantity else {
      throw GameError("Choose a positive quantity of free supplies to discard.")
    }
    state.materials[id] -= quantity
  }
  public static func upgradeHouse(state: inout GameState) throws {
    guard state.houseLevel < 5 else { throw GameError("House storage is already at level 5.") }
    var next = state
    try spend(houseUpgradeMaterials, state: &next)
    try Construction.spend(4 * (state.houseLevel + 1), state: &next)
    next.houseLevel += 1
    state = next
  }
}
