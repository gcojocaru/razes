import Foundation

public struct Presentation: Codable, Equatable, Sendable {
  public var field, house: String
  public var stores: Int
  public var weather: String
  public init(state s: GameState) {
    field =
      s.displaySeason == 3
      ? "snow"
      : s.harvested
        ? "harvested"
        : !s.planted
          ? "bare" : s.displaySeason == 0 ? "sown" : s.displaySeason == 1 ? "growing" : "ripe"
    house = s.house >= 65 ? "intact" : "damaged"
    stores = s.food < 9 ? 0 : s.food < 25 ? 1 : 2
    weather =
      s.displaySeason == 3
      ? "snow"
      : s.displaySeason == 2
        ? "leaves" : s.displaySeason == 1 ? "motes" : "blossom"
  }
}
