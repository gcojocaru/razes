import Foundation

public enum CropStage: String, Sendable {
  case bare, sown, sprouting, growing, ripe, harvested, snow
}

public enum Farming {
  public static let seedCost = 4
  public static let growingWeeks = 24

  public static func plantingProblem(_ s: GameState) -> String? {
    if s.planted {
      return s.harvested
        ? "This year’s harvest is complete. Plant again next Spring."
        : "This field is already planted. Plant again next Spring."
    }
    if s.season != 0 || (s.phase == .summary && s.isSeasonEnd) {
      return "Planting is closed. Plant grain seeds next Spring."
    }
    if s.phase != .work { return "Continue to the next week to assign planting." }
    if s.layout.farmland.isEmpty { return "Paint farmland in Construction before planting." }
    if s.seeds < seedCost {
      return "Planting needs \(seedCost) grain seeds; you have \(s.seeds). Buy seeds first."
    }
    return nil
  }

  public static func stage(_ s: GameState) -> CropStage {
    if s.season == 3 { return .snow }
    if s.harvested { return .harvested }
    if !s.planted { return .bare }
    if s.cropWeeks < 3 { return .sown }
    if s.cropWeeks < 5 { return .sprouting }
    return s.cropWeeks < growingWeeks ? .growing : .ripe
  }
  public static func canTend(_ s: GameState) -> Bool {
    s.season != 3 && s.planted && !s.tended && !s.harvested
      && (4..<growingWeeks).contains(s.cropWeeks)
  }
  public static func canHarvest(_ s: GameState) -> Bool {
    s.season == 2 && s.planted && !s.harvested && s.cropWeeks == growingWeeks
  }
  public static func foodYield(_ s: GameState) -> Int {
    Content.shared.balance.harvest + (s.tended ? Content.shared.balance.tendedBonus : 0)
      + 2 * (s.character.level(.farming) - 1)
  }
  public static func seedYield(_ s: GameState) -> Int { s.tended ? 6 : 4 }
  public static func buySeeds(quantity: Int, state: inout GameState) throws {
    guard (1...100000).contains(quantity), state.seeds <= 100000 - quantity else {
      throw GameError("Choose a positive seed quantity that fits in seed storage (100000 maximum).")
    }
    try Construction.spend(quantity, state: &state)
    state.seeds += quantity
  }
  public static func label(_ s: GameState) -> String {
    switch stage(s) {
    case .bare: return "Waiting to be sown · needs \(seedCost) grain seeds"
    case .snow:
      return s.planted && !s.harvested
        ? "Winter frost has lost the unharvested crop" : "Field resting beneath the snow"
    case .harvested: return "Harvest safely gathered · sow again next spring"
    case .ripe: return "Ripe grain · ready for harvest"
    case .sown, .sprouting, .growing:
      return
        "\(stage(s).rawValue.capitalized) · \(s.cropWeeks)/\(growingWeeks) growing weeks · \(growingWeeks - s.cropWeeks) weeks until ripe"
    }
  }
}
