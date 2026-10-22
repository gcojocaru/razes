import Foundation

public struct Person: Codable, Sendable { public var name, role, line, color: String }
public struct Balance: Codable, Sendable {
  public struct Initial: Codable, Sendable { public var food, money, house: Int }
  public var initial: Initial
  public var consumption, seed, repairCost, repairGain, wages, supplyCost, supplyGain: Int
  public var wear: [Int]
  public var coldThreshold, coldFood, survivalHouse, harvest, oxBonus, tendedBonus, oxPrice,
    giftFood, neighbourFood, settlementCost, brotherShare, helpFood, fairShareFood, winterMeal: Int
}
public struct Content: Codable, Sendable {
  public var balance: Balance
  public var tasks: [String: Task]
  public var people: [String: Person]
  public var events: [String: GameEvent]
  public static let shared: Content = {
    // Packaged authored data is a build invariant; user saves never use this path.
    guard let url = Bundle.module.url(forResource: "content", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let value = try? JSONDecoder().decode(Content.self, from: data)
    else {
      fatalError("Bundled game content is missing or invalid")
    }
    return value
  }()
  public static let seasons = ["Spring", "Summer", "Autumn", "Winter"]
}
