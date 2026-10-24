import XCTest

@testable import RazesCore

final class ProgressionLoopTests: XCTestCase {
  private func resolve(_ state: GameState, _ task: TaskID) throws -> GameState {
    try SurvivalTests().resolve(state, task)
  }
  private func advance(_ state: GameState) throws -> GameState {
    try Rules.dispatch(state, action: .init(type: "continue", revision: state.revision))
  }
  private func add(_ id: BuildingID, level: Int, condition: Double = 100, to s: inout GameState)
    throws
  {
    s.layout.buildings.append(
      .init(id: id, position: try XCTUnwrap(Settlement.firstAvailable(id, in: s.layout))))
    s.buildings.append(
      .init(
        id: id, completedSeason: s.turn, legacyAssignment: false, level: level, condition: condition
      ))
  }

  func testWagesAndEnergyUseStartingSkillsThenRepeatNextWeek() throws {
    var s = Rules.newGame()
    for _ in 0..<3 {
      let before = s.money
      let done = try resolve(s, .paid)
      XCTAssertEqual(done.money, before + 1)
      XCTAssertEqual(done.report?.character.energyCost, 10)
      s = try advance(done)
      XCTAssertEqual(s.assignments["ion"], .paid)
    }
    XCTAssertEqual(s.character.strengthXP, 3)
    XCTAssertEqual(s.character.enduranceXP, 3)
    let done = try resolve(s, .paid)
    XCTAssertEqual(done.money, s.money + 2)
    XCTAssertEqual(done.report?.character.energyCost, 8)
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(done)), done)
  }

  func testEnduranceFloorsPoorHealthAndRecovery() {
    var c = CharacterState()
    c.enduranceXP = 12
    XCTAssertEqual(CharacterSimulation.energyCost(.paid, character: c), 5)
    XCTAssertEqual(CharacterSimulation.energyCost(.gatherWood, character: c), 12)
    XCTAssertEqual(CharacterSimulation.restEnergy(character: c, exposed: false), 43)
    XCTAssertEqual(CharacterSimulation.restEnergy(character: c, exposed: true), 33)
    c.health = 24
    XCTAssertEqual(CharacterSimulation.energyCost(.paid, character: c), 15)
    XCTAssertEqual(CharacterSimulation.energyCost(.repair, character: c), 22)
    XCTAssertEqual(CharacterSimulation.energyCost(.rest, character: c), 0)
  }

  func testProductivityControlsPersonalExperience() throws {
    var s = Rules.newGame()
    let gathered = try resolve(s, .gatherWood)
    XCTAssertEqual(gathered.character.strengthXP, 1)
    XCTAssertEqual(gathered.character.enduranceXP, 1)
    XCTAssertEqual(gathered.character.gatheringXP, 1)
    s.materials = .init(wood: 20)
    let full = try resolve(s, .gatherWood)
    XCTAssertEqual(full.character.strengthXP, 0)
    XCTAssertEqual(full.character.enduranceXP, 0)
    s.house = 100
    XCTAssertEqual(try resolve(s, .repair).character.enduranceXP, 0)
    XCTAssertEqual(try resolve(s, .supplies).character.enduranceXP, 0)
    XCTAssertEqual(try resolve(s, .rest).character.enduranceXP, 0)
  }

  func testFoundationExperienceForecastAndHistoricalSnapshotSurviveSummaryEdits() throws {
    var s = Rules.newGame()
    s.week = 11
    s.houseLevel = 2
    s.money = 100
    s.materials = .init(wood: 14, stone: 2, planks: 1)
    for id in [BuildingID.woodshed, .cellar, .workshop] { try add(id, level: 0, to: &s) }
    let p = Rules.preview(s)
    XCTAssertEqual(p.character.after.buildingXP, 3)
    var done = try resolve(s, .rest)
    XCTAssertEqual(done.character, p.character.after)
    XCTAssertEqual(done.character.enduranceXP, 0)
    XCTAssertEqual(done.report?.buildingsBefore, s.buildings)
    try Construction.upgrade(.woodshed, state: &done)
    try Materials.craftPlanks(quantity: 1, state: &done)
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(done)), done)
    let next = try advance(done)
    XCTAssertEqual(Rules.preview(next).character.after.buildingXP, 3)
  }

  func testWorkerBuildEarnsBuildingExperienceAtCompletionOnly() throws {
    let early = try resolve(Rules.newGame(), .buildWoodshed)
    XCTAssertEqual(early.character.buildingXP, 0)
    XCTAssertEqual(early.character.enduranceXP, 1)
    var s = Rules.newGame()
    s.week = 11
    let final = try resolve(s, .buildWoodshed)
    XCTAssertEqual(final.character.buildingXP, 1)
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(final)), final)
    XCTAssertEqual(try advance(final).assignments["ion"], .rest)
  }

  func testTaskRetentionFallsBackForEnergyMoneyAndOneTimeWork() throws {
    var s = Rules.newGame()
    s.character.energy = 10
    XCTAssertEqual(try advance(resolve(s, .paid)).assignments["ion"], .rest)
    s = Rules.newGame()
    s.money = 4
    XCTAssertEqual(try advance(resolve(s, .supplies)).assignments["ion"], .rest)
    s = Rules.newGame()
    XCTAssertEqual(try advance(resolve(s, .plant)).assignments["ion"], .rest)
    s.week = 11
    let continued = try advance(resolve(s, .paid))
    XCTAssertEqual(continued.season, 1)
    XCTAssertEqual(continued.assignments["ion"], .paid)
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(continued)), continued)
  }

  func testBuildingContributionUsesFrozenStateAfterWearAndRepair() throws {
    var s = Rules.newGame()
    s.season = 1
    s.week = 11
    try add(.stable, level: 1, condition: 10, to: &s)
    s.buildings[0].completedSeason = 0
    let lines = Rules.buildingContributions(s)
    XCTAssertTrue(lines.contains { $0.contains("Stable") })
    var done = try resolve(s, .paid)
    XCTAssertEqual(done.buildings[0].condition, 0)
    XCTAssertEqual(done.money - s.money, 4)  // Strength wage + transport + seasonal income.
    XCTAssertEqual(
      Rules.reportBuildingContributions(done),
      Rules.buildingContributions(
        {
          var draft = s
          draft.assignments["ion"] = .paid
          return draft
        }()))
    let contributions = Rules.reportBuildingContributions(done)
    try Construction.repair(.stable, state: &done)
    XCTAssertEqual(Rules.reportBuildingContributions(done), contributions)
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(done)), done)
  }

  func testFrozenBuildingsAndNewSkillFieldsAreRequiredAndValidated() throws {
    let done = try resolve(Rules.newGame(), .paid)
    let original = try JSONSerialization.jsonObject(with: SaveCodec.encode(done)) as! [String: Any]
    var object = original
    var report = object["report"] as! [String: Any]
    report.removeValue(forKey: "buildingsBefore")
    object["report"] = report
    XCTAssertThrowsError(try SaveCodec.decode(JSONSerialization.data(withJSONObject: object)))
    for key in ["strengthXP", "enduranceXP"] {
      var invalid = original
      var character = invalid["character"] as! [String: Any]
      character[key] = 13
      invalid["character"] = character
      XCTAssertThrowsError(try SaveCodec.decode(JSONSerialization.data(withJSONObject: invalid)))
    }
  }

  func testEveryTierAndMaximumUpgradeIsReachableThroughCompletionExperience() throws {
    var s = Rules.newGame()
    s.money = 10000
    s.food = 1000
    s.materials = .init(wood: 1000, stone: 1000, planks: 1000)
    let tiers: [[BuildingID]] = [
      [.woodshed, .cellar, .well, .workshop],
      [.barn, .granary, .apiary, .storehouse],
      [.bakery, .smithy, .stable],
    ]
    for (tier, buildings) in tiers.enumerated() {
      if tier > 0 { try Materials.upgradeHouse(state: &s) }
      for id in buildings {
        XCTAssertTrue(Construction.requirements(id, state: s).isMet, id.rawValue)
        s.layout.buildings.append(
          .init(id: id, position: try XCTUnwrap(Settlement.firstAvailable(id, in: s.layout))))
        try Construction.start(id, state: &s)
      }
      s.week = 11
      s = try advance(resolve(s, .rest))
      XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(s)), s)
    }
    XCTAssertEqual(s.character.buildingXP, 11)
    s = try advance(resolve(s, .repair))
    XCTAssertEqual(s.character.level(.building), 5)
    while s.houseLevel < 5 { try Materials.upgradeHouse(state: &s) }
    for level in 2...5 {
      for id in BuildingID.allCases {
        try Construction.upgrade(id, state: &s)
        XCTAssertEqual(s.buildings.first { $0.id == id }?.level, level)
      }
    }
    XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(s)), s)
  }

  func testPracticalBonusesActivateOnCompletionAndStopWhenDamaged() {
    var s = Rules.newGame()
    s.season = 3
    s.week = 3
    s.buildings = [
      .init(id: .cellar, completedSeason: s.turn),
      .init(id: .bakery, completedSeason: s.turn, level: 3),
      .init(id: .stable, completedSeason: s.turn),
      .init(id: .woodshed, completedSeason: s.turn),
    ]
    XCTAssertEqual(Rules.suppliesGain(s), 13)
    XCTAssertEqual(Rules.task(.paid, in: s).moneyGain, 2)
    XCTAssertEqual(Rules.consumption(s, house: 55), 0)
    XCTAssertEqual(Construction.seasonalYield(s).food, 0)
    s.week = 11
    XCTAssertEqual(Rules.weathering(s), 6)
    for index in s.buildings.indices { s.buildings[index].condition = 0 }
    XCTAssertEqual(Rules.suppliesGain(s), 7)
    XCTAssertEqual(Rules.task(.paid, in: s).moneyGain, 1)
    XCTAssertEqual(Rules.consumption(s, house: 55), 1)
    XCTAssertEqual(Rules.weathering(s), 14)
  }

  func testCompletedTendAndHarvestCannotRemainPreselected() throws {
    var s = Rules.newGame()
    s.planted = true
    s.cropWeeks = 4
    s.week = 4
    XCTAssertEqual(try advance(resolve(s, .tend)).assignments["ion"], .rest)
    s.season = 2
    s.cropWeeks = 24
    XCTAssertEqual(try advance(resolve(s, .harvest)).assignments["ion"], .rest)
  }

  func testFoundationExperienceCapsAndDoesNotRewardDebugPlacedBuildings() throws {
    var s = Rules.newGame()
    s.character.buildingXP = 11
    s.week = 11
    for id in [BuildingID.woodshed, .cellar, .well] { try add(id, level: 0, to: &s) }
    XCTAssertEqual(try resolve(s, .rest).character.buildingXP, 12)
    s.character.buildingXP = 0
    for index in s.buildings.indices { s.buildings[index].debugPlaced = true }
    XCTAssertEqual(try resolve(s, .rest).character.buildingXP, 0)
  }
}
