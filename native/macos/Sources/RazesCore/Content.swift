import Foundation

public struct Person: Sendable { public var name, role, line, color: String }
public struct Balance: Sendable {
  public struct Initial: Sendable { public var food, money, house: Int }
  public var initial: Initial
  public var consumption, repairCost, repairGain, wages, supplyCost, supplyGain: Int
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
      consumption: 1, repairCost: 3, repairGain: 20, wages: 1, supplyCost: 4,
      supplyGain: 7, wear: [6, 5, 8, 14], coldThreshold: 40, coldFood: 1, survivalHouse: 20,
      harvest: 20, tendedBonus: 8),
    tasks: [
      "rest": Task(
        id: .rest, name: "Rest",
        description: "Recover 35 energy (25 in winter exposure). Safe rest also heals 10 health.",
        icon: "sun", workers: 1,
        moneyCost: 0, foodCost: 0, foodGain: 0, moneyGain: 0, houseGain: 0),
      "plant": Task(
        id: .plant, name: "Sow the field",
        description: "Sow in spring using 4 grain seeds. The crop ripens after 24 growing weeks.",
        icon: "wheat",
        workers: 1, moneyCost: 0, foodCost: 0, foodGain: 0, moneyGain: 0, houseGain: 0),
      "tend": Task(
        id: .tend, name: "Tend the crop",
        description:
          "Tend once after 4 growing weeks, before ripening. Adds 8 food and 2 seeds at harvest.",
        icon: "wheat",
        workers: 1, moneyCost: 0, foodCost: 0, foodGain: 0, moneyGain: 0, houseGain: 0),
      "harvest": Task(
        id: .harvest, name: "Bring in the harvest",
        description:
          "Gather ripe grain before winter: 20 food and 4 seeds; tended crops give 28 food and 6 seeds.",
        icon: "wheat",
        workers: 1, moneyCost: 0, foodCost: 0, foodGain: 0, moneyGain: 0, houseGain: 0),
      "paid": Task(
        id: .paid, name: "Work for wages",
        description: "A week at the village mill earns 1 coin.", icon: "coin",
        workers: 1, moneyCost: 0, foodCost: 0, foodGain: 0, moneyGain: 1, houseGain: 0),
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
        name: "Ion", role: "Settler", line: "One assignment each week.", color: "#65734f")
    ]
  )
  public static let seasons = ["Spring", "Summer", "Autumn", "Winter"]
}
