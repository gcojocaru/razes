import XCTest

@testable import RazesCore

final class SurvivalTests: XCTestCase {
  func resolve(_ state: GameState, _ task: TaskID = .rest) throws -> GameState {
    let draft = try Rules.dispatch(
      state, action: .init(type: "assign", revision: state.revision, worker: .ion, task: task))
    return try Rules.dispatch(draft, action: .init(type: "resolve", revision: draft.revision))
  }

  func next(_ state: GameState, _ task: TaskID = .rest) throws -> GameState {
    let done = try resolve(state, task)
    return try Rules.dispatch(done, action: .init(type: "continue", revision: done.revision))
  }

  func testMealsAreWeeklyAndUseThisWeeksProvisions() throws {
    let s = Rules.newGame()
    XCTAssertEqual(Rules.preview(s).consumption, 1)
    XCTAssertEqual(try resolve(s).food, 17)
    var empty = s
    empty.food = 0
    let supplied = try resolve(empty, .supplies)
    XCTAssertEqual(supplied.food, 6)
    XCTAssertEqual(supplied.report?.deficit, 0)
  }

  func testWinterMonthEndModifiersAndRepairBeforeMeal() throws {
    for shed in [false, true] {
      for cold in [false, true] {
        var s = Rules.newGame()
        s.season = 3
        s.week = 3
        s.house = cold ? 35 : 55
        if shed { s.buildings = [.init(id: .woodshed, completedSeason: 0)] }
        XCTAssertEqual(Rules.preview(s).consumption, 1 + (cold ? 1 : 0) - (shed ? 1 : 0))
        let repaired = try resolve(s, .repair)
        XCTAssertEqual(repaired.report?.consumption, shed ? 0 : 1)
        s.week = 2
        XCTAssertEqual(Rules.preview(s).consumption, 1)
      }
    }
  }

  func testGatheringLevelAppliesOnFollowingWeek() throws {
    var s = Rules.newGame()
    s.materials = .init()
    for _ in 0..<3 { s = try next(s, .gatherStone) }
    XCTAssertEqual(s.materials.stone, 3)
    let done = try resolve(s, .gatherStone)
    XCTAssertEqual(done.lastMaterialHaul?.stone, 2)
    XCTAssertEqual(done.materials.stone, 5)
  }

  func testExhaustedWorkerMustRestBeforeWorkingAgain() throws {
    var s = Rules.newGame()
    for _ in 0..<5 { s = try next(s, .gatherWood) }
    XCTAssertNotNil(Rules.assignmentProblem(s, worker: .ion, task: .paid))
    XCTAssertThrowsError(try resolve(s, .paid))
    s = try next(s, .rest)
    XCTAssertNil(Rules.assignmentProblem(s, worker: .ion, task: .paid))
  }

  func testNeglectEndsTheRunAndCannotAdvance() throws {
    var s = Rules.newGame()
    for _ in 0..<27 {
      s = try resolve(s)
      if s.phase.rawValue == "dead" { break }
      s = try Rules.dispatch(s, action: .init(type: "continue", revision: s.revision))
    }
    XCTAssertEqual(s.phase.rawValue, "dead")
    XCTAssertEqual(s.report?.deficit, 1)
    XCTAssertThrowsError(
      try Rules.dispatch(s, action: .init(type: "continue", revision: s.revision)))
  }

  func testRecoveryAndEnergyCostsUseStartingHealth() throws {
    var s = Rules.newGame()
    s.character.health = 24
    s.character.energy = 19
    XCTAssertNotNil(Rules.assignmentProblem(s, worker: .ion, task: .paid))
    s.character.energy = 20
    let work = try resolve(s, .paid)
    XCTAssertEqual(work.character.health, 24)
    XCTAssertEqual(work.character.energy, 0)
    s.character.energy = 80
    let rest = try resolve(s)
    XCTAssertEqual(rest.character.health, 34)
    XCTAssertEqual(rest.character.energy, 100)
    s.season = 3
    s.house = 39
    s.character.energy = 0
    let cold = try resolve(s)
    XCTAssertEqual(cold.character.health, 14)
    XCTAssertEqual(cold.character.energy, 25)
    XCTAssertEqual(cold.report?.character.exposureDamage, 10)
  }

  func testFeedingPreventsStarvationAndDamageStacksOnlyAfterEating() throws {
    var s = Rules.newGame()
    s.season = 3
    s.house = 39
    s.character.health = 25
    s.character.hunger = 50
    s.food = 0
    let p = Rules.preview(s)
    XCTAssertTrue(p.character.fatal)
    XCTAssertTrue(p.warnings.contains { $0.contains("will kill Ion") })
    let dead = try resolve(s)
    XCTAssertEqual(dead.character.health, 0)
    XCTAssertEqual(dead.character.hunger, 75)
    XCTAssertEqual(dead.report?.character.starvationDamage, 15)
    XCTAssertEqual(dead.report?.character.exposureDamage, 10)
    XCTAssertEqual(dead.report?.character, p.character)
    XCTAssertEqual(dead.report?.character.deathCause, "Starvation and winter exposure")
    XCTAssertEqual(dead.week, 0)
    for type in ["assign", "resolve", "continue"] {
      XCTAssertThrowsError(
        try Rules.dispatch(dead, action: .init(type: type, revision: dead.revision)))
    }
    let supplied = try resolve(s, .supplies)
    XCTAssertEqual(supplied.character.hunger, 25)
    XCTAssertEqual(supplied.character.health, 15)
    XCTAssertEqual(supplied.phase, .summary)
    s.food = 1
    let repaired = try resolve(s, .repair)
    XCTAssertEqual(repaired.character.health, 25)
    XCTAssertEqual(repaired.report?.character.exposureDamage, 0)
  }

  func testSeasonEndWearDoesNotExposeIonUntilNextWeek() throws {
    var s = Rules.newGame()
    s.season = 3
    s.week = 11
    s.house = 40
    let result = try resolve(s)
    XCTAssertEqual(result.house, 26)
    XCTAssertEqual(result.character.health, 100)
    XCTAssertEqual(result.report?.character.exposureDamage, 0)
  }

  func testSkillBonusesUseStartingLevelAndDoNotRewardUnproductiveWork() throws {
    var s = Rules.newGame()
    s.character.buildingXP = 2
    let repair = try resolve(s, .repair)
    XCTAssertEqual(repair.house, 75)
    XCTAssertEqual(repair.character.buildingXP, 3)
    s = try next(s, .repair)
    let stronger = try resolve(s, .repair)
    XCTAssertEqual(stronger.house, 100)
    XCTAssertEqual(stronger.character.buildingXP, 4)
    s.house = 100
    XCTAssertEqual(try resolve(s, .repair).character.buildingXP, 3)
    s.materials = .init(wood: 20)
    XCTAssertEqual(try resolve(s, .gatherWood).character.gatheringXP, 0)
    s = Rules.newGame()
    s.season = 2
    s.planted = true
    s.cropWeeks = 24
    s.tended = true
    s.character.farmingXP = 11
    let harvest = try resolve(s, .harvest)
    XCTAssertEqual(harvest.report?.character.after.farmingXP, 12)
    XCTAssertEqual(harvest.food, 51)
    XCTAssertEqual(harvest.seeds, 14)
    s.character.gatheringXP = 12
    s.materials = .init(wood: 18)
    let haul = try resolve(s, .gatherWood)
    XCTAssertEqual(haul.lastMaterialHaul?.wood, 2)
    XCTAssertEqual(haul.character.gatheringXP, 12)
  }

  func testThreeYearRoutineSurvivesAndMatchesEveryForecast() throws {
    var s = Rules.newGame()
    for _ in 0..<144 {
      var job: TaskID
      if s.food <= 3 && s.money >= 4 {
        job = .supplies
      } else if Farming.canHarvest(s) {
        job = .harvest
      } else if s.house <= 45 && s.money >= 3 {
        job = .repair
      } else if s.season == 0 && !s.planted {
        job = .plant
      } else if Farming.canTend(s) {
        job = .tend
      } else {
        job = .paid
      }
      if CharacterSimulation.energyCost(job, character: s.character) > s.character.energy {
        job = .rest
      }
      let draft = try Rules.dispatch(
        s, action: .init(type: "assign", revision: s.revision, worker: .ion, task: job))
      let forecast = Rules.preview(draft)
      let done = try Rules.dispatch(draft, action: .init(type: "resolve", revision: draft.revision))
      XCTAssertEqual(done.character, forecast.character.after)
      XCTAssertEqual(done.report?.character, forecast.character)
      XCTAssertEqual(done.food, max(0, forecast.foodAfter))
      XCTAssertEqual(done.house, forecast.houseAfter)
      XCTAssertEqual(done.money, forecast.moneyAfter)
      XCTAssertEqual(done.character.health, 100)
      XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(done)), done)
      s = try Rules.dispatch(done, action: .init(type: "continue", revision: done.revision))
    }
    XCTAssertEqual(s.year, 3)
    XCTAssertEqual(s.character.level(.farming), 4)
    XCTAssertGreaterThan(s.money, 12)
  }
}
