import Foundation

public struct Person: Sendable { public var name, role, line, color: String }
public struct Balance: Sendable {
  public struct Initial: Sendable { public var food, money, house: Int }
  public var initial: Initial
  public var consumption, seed, repairCost, repairGain, wages, supplyCost, supplyGain: Int
  public var wear: [Int]
  public var coldThreshold, coldFood, survivalHouse, harvest, tendedBonus: Int
}
public struct Content: Sendable {
  public var balance: Balance
  public var tasks: [String: Task]
  public var people: [String: Person]
  // Native settlement rules are independent of the browser's authored story export.
  public static let shared = Content(
    balance: Balance(
      initial: .init(food: 18, money: 12, house: 55),
      consumption: 3, seed: 4, repairCost: 3, repairGain: 20, wages: 6, supplyCost: 4,
      supplyGain: 7, wear: [6, 5, 8, 14], coldThreshold: 40, coldFood: 1, survivalHouse: 20,
      harvest: 20, tendedBonus: 8),
    tasks: [
      "rest": Task(
        id: .rest, name: "Unassigned",
        description: "Leave Ion free. Unused work does not carry over.", icon: "sun", workers: 1,
        moneyCost: 0, foodCost: 0, foodGain: 0, moneyGain: 0, houseGain: 0),
      "plant": Task(
        id: .plant, name: "Sow the field",
        description: "Plant this year’s crop. Ion can harvest it in autumn.", icon: "wheat",
        workers: 1, moneyCost: 0, foodCost: 4, foodGain: 0, moneyGain: 0, houseGain: 0),
      "tend": Task(
        id: .tend, name: "Tend the crop",
        description: "Keep weeds down. Add 8 food to the autumn harvest.", icon: "wheat",
        workers: 1, moneyCost: 0, foodCost: 0, foodGain: 0, moneyGain: 0, houseGain: 0),
      "harvest": Task(
        id: .harvest, name: "Bring in the harvest",
        description: "Gather the entire crop with Ion’s seasonal assignment.", icon: "wheat",
        workers: 1, moneyCost: 0, foodCost: 0, foodGain: 0, moneyGain: 0, houseGain: 0),
      "paid": Task(
        id: .paid, name: "Work for wages",
        description: "A spell of work at the village mill earns a little money.", icon: "coin",
        workers: 1, moneyCost: 0, foodCost: 0, foodGain: 0, moneyGain: 6, houseGain: 0),
      "repair": Task(
        id: .repair, name: "Mend the house",
        description: "Replace tired thatch and patch the walls before the cold.", icon: "house",
        workers: 1, moneyCost: 3, foodCost: 0, foodGain: 0, moneyGain: 0, houseGain: 20),
      "supplies": Task(
        id: .supplies, name: "Buy provisions",
        description: "Bring home a modest, dependable supply of grain.", icon: "basket", workers: 1,
        moneyCost: 4, foodCost: 0, foodGain: 7, moneyGain: 0, houseGain: 0),
    ],
    people: [
      "ion": Person(
        name: "Ion", role: "Settler", line: "One assignment each season.", color: "#65734f")
    ]
  )
  public static let seasons = ["Spring", "Summer", "Autumn", "Winter"]
}
