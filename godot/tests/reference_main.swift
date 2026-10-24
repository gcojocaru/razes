// Generate with: swiftc -module-cache-path /tmp/razes-swift-cache native/macos/Sources/RazesCore/*.swift godot/tests/reference_main.swift -o /tmp/razes-reference && /tmp/razes-reference > godot/tests/reference_rules.json
import Foundation

@main struct ReferenceFixtures {
  static var fixtures: [[String: Any]] = []
  static func json(_ s: GameState) throws -> [String: Any] {
    var j = try JSONSerialization.jsonObject(with: SaveCodec.encode(s)) as! [String: Any]
    j["version"] = 1
    var layout = j["layout"] as! [String: Any]
    layout["ownedParcels"] = [["x":0,"y":0]]
    j["layout"] = layout
    for key in ["report", "lastMaterialHaul", "debugSeason"] where j[key] == nil { j[key] = NSNull() }
    func records(_ list: [[String: Any]]) -> [[String: Any]] {
      list.map { r in var r = r; if r["debugPlaced"] == nil { r["debugPlaced"] = false }; return r }
    }
    j["buildings"] = records(j["buildings"] as! [[String: Any]])
    if var report = j["report"] as? [String: Any] {
      report["buildingsBefore"] = records(report["buildingsBefore"] as! [[String: Any]])
      j["report"] = report
    }
    return j
  }
  static func add(_ name: String, _ before: GameState, _ action: String, _ payload: [String: Any] = [:], _ edit: (inout GameState) throws -> Void) throws -> GameState {
    var after = before
    try edit(&after)
    if action != "assign" && action != "end_week" && action != "continue" { after.revision += 1 }
    // Validate the owning implementation's result before treating it as a reference.
    _ = try SaveCodec.decode(SaveCodec.encode(after))
    let p = Rules.preview(before)
    fixtures.append(["name":name,"state":try json(before),"action":action,"payload":payload,"expected":try json(after),"forecast":["foodAfter":p.foodAfter,"moneyAfter":p.moneyAfter,"houseAfter":p.houseAfter,"seedsAfter":p.seedsAfter,"consumption":p.consumption,"wear":p.wear,"character":try JSONSerialization.jsonObject(with:JSONEncoder().encode(p.character))]])
    return after
  }
  static func dispatch(_ name: String, _ s: GameState, _ action: String, _ task: TaskID? = nil) throws -> GameState {
    try add(name,s,action,task.map { ["task":$0.rawValue] } ?? [:]) {
      $0 = try Rules.dispatch($0,action:.init(type:action == "end_week" ? "resolve" : action, revision:$0.revision,worker:task == nil ? nil : .ion,task:task))
    }
  }
  static func week(_ name: String, _ initial: GameState, _ task: TaskID) throws -> GameState {
    let s = try dispatch(name+" assign",initial,"assign",task)
    let done = try dispatch(name+" resolve",s,"end_week")
    return done.phase == .dead ? done : try dispatch(name+" continue",done,"continue")
  }
  static func main() throws {
    var s = Rules.newGame()
    s = try week("initial rest",s,.rest)
    s = try week("gather",s,.gatherStone)
    s = try week("gather again",s,.gatherStone)
    s = try week("gather level",s,.gatherStone)
    s = try week("new gather level",s,.gatherStone)
    s = Rules.newGame(); s.food = 0
    _ = try week("immediate provisions",s,.supplies)
    s = Rules.newGame(); s.season = 3; s.week = 3; s.house = 35; s.character.buildingXP = 2
    _ = try week("winter repair before meal",s,.repair)
    s = Rules.newGame(); s.character.health = 24; s.character.energy = 20
    _ = try week("poor health paid",s,.paid)
    s = Rules.newGame(); s.season = 3; s.house = 39; s.food = 0; s.character.health = 25; s.character.hunger = 50
    _ = try week("stacked fatal damage",s,.rest)
    s = Rules.newGame(); s.week = 11
    _ = try week("legacy cellar completion",s,.buildCellar)
    s = Rules.newGame(); s.week = 11; s.season = 3; s.house = 39
    s.buildings = [.init(id:.woodshed, completedSeason:1,legacyAssignment:false,level:2,condition:10)]
    s.layout.buildings = [.init(id:.woodshed,position:.init(x:1,y:1))]
    _ = try week("season wear downgrade",s,.rest)
    s = Rules.newGame(); s.season = 2; s.planted = true; s.tended = true; s.cropWeeks = 24; s.character.farmingXP = 11
    s.buildings = [.init(id:.well,completedSeason:0,legacyAssignment:false,level:2), .init(id:.granary,completedSeason:0,legacyAssignment:false,level:3)]
    s.layout.buildings = [.init(id:.well,position:.init(x:1,y:1)),.init(id:.granary,position:.init(x:3,y:1))]
    _ = try week("skilled harvest",s,.harvest)
    s = Rules.newGame(); s.week = 4; s.planted = true; s.cropWeeks = 4
    _ = try week("tending",s,.tend)
    s = Rules.newGame(); s.week = 11; s.season = 3; s.food = 30; s.house = 100
    _ = try week("new year",s,.rest)
    s = Rules.newGame()
    s = try add("direct workshop foundation",s,"place_building",["id":"workshop","position":["x":1,"y":1]]) {
      try Construction.start(.workshop,state:&$0)
      $0.layout.buildings.append(.init(id:.workshop,position:.init(x:1,y:1)))
    }
    s.week = 11
    s = try week("direct foundation completion",s,.rest)
    s = try add("craft planks",s,"craft",["amount":1]) { try Materials.craftPlanks(quantity:1,state:&$0) }
    s.money = 100; s.materials = .init(wood:20,stone:20,planks:20); s.character.buildingXP = 12; s.houseLevel = 5
    s = try add("workshop upgrade",s,"upgrade_building",["id":"workshop"]) { try Construction.upgrade(.workshop,state:&$0) }
    s.buildings[0].condition = 20
    s = try add("workshop repair",s,"repair_building",["id":"workshop"]) { try Construction.repair(.workshop,state:&$0) }
    s = try add("buy seeds",s,"buy_seeds",["amount":3]) { try Farming.buySeeds(quantity:3,state:&$0) }
    s = try add("discard wood",s,"discard_material",["id":"wood","amount":5]) { try Materials.discard(.wood,quantity:5,state:&$0) }
    s = try add("buy stone",s,"buy_material",["id":"stone","amount":2]) { try Materials.buy(.stone,quantity:2,state:&$0) }
    s = Rules.newGame(); s.materials = .init(wood:6,stone:4,planks:1)
    _ = try add("house storage upgrade",s,"upgrade_house") { try Materials.upgradeHouse(state:&$0) }
    let output = try JSONSerialization.data(withJSONObject:fixtures,options:[.sortedKeys,.prettyPrinted])
    FileHandle.standardOutput.write(output)
    FileHandle.standardOutput.write(Data("\n".utf8))
  }
}
