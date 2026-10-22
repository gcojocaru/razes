import Foundation
public struct Presentation: Codable, Equatable, Sendable {
    public var field, house: String
    public var stores: Int
    public var visitor: String?
    public var weather: String
    public init(state s: GameState) {
        let person = s.phase == .opening || s.phase == .consequence ? Rules.currentEvent(s).person : nil
        field = s.season == 3 ? "snow" : s.harvested ? "harvested" : !s.planted ? "bare" : s.season == 0 ? "sown" : s.season == 1 ? "growing" : "ripe"
        house = s.house >= 65 ? "intact" : "damaged"; stores = s.food < 9 ? 0 : s.food < 25 ? 1 : 2
        visitor = person == "vasile" || person == "dumitru" ? person : nil
        weather = s.season == 3 ? "snow" : s.season == 2 ? "leaves" : s.season == 1 ? "motes" : s.phase == .consequence ? "rain" : "blossom"
    }
}
