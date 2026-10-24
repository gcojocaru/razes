extends SceneTree

const Rules = preload("res://scripts/village_rules.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run_action(state: Dictionary, action: String, payload: Dictionary = {}) -> Dictionary:
	var original: Dictionary = state.duplicate(true)
	var result := Rules.act(state,action,payload)
	check(result.error == "", "%s %s: %s" % [action,str(payload),result.error])
	check(state == original,"%s mutated its input" % action)
	if result.error == "":
		check(Rules.validate(result.state) == "","%s produced invalid state" % action)
		check(result.state.revision == state.revision+1,"%s increments revision exactly once" % action)
	return result.state

func reject(state: Dictionary, action: String, payload: Dictionary = {}) -> void:
	var original: Dictionary = state.duplicate(true)
	var result := Rules.act(state,action,payload)
	check(result.error != "","%s %s should fail" % [action,str(payload)])
	check(state == original and result.state == original,"Rejected %s must preserve complete state" % action)

func week(state: Dictionary, task: String = "rest") -> Dictionary:
	var assigned := run_action(state,"assign",{"task":task})
	var forecast := Rules.forecast(assigned)
	var done := run_action(assigned,"end_week")
	check(done.character == forecast.character.after and done.food == maxi(0,forecast.foodAfter) and done.money == forecast.moneyAfter and done.house == forecast.houseAfter,"Resolved week matches forecast")
	return run_action(done,"continue") if done.phase == "summary" else done

func positioned(state: Dictionary, id: String, x: int, y: int) -> Dictionary:
	return run_action(state,"place_building",{"id":id,"position":{"x":x,"y":y},"instant":true})

func test_reference_fixtures() -> void:
	var file := FileAccess.open("res://tests/reference_rules.json",FileAccess.READ)
	check(file != null,"Swift reference fixtures exist")
	if file == null: return
	var fixtures: Variant = JSON.parse_string(file.get_as_text())
	check(fixtures is Array and fixtures.size() >= 40,"Representative Swift fixture count")
	if not fixtures is Array: return
	for fixture in fixtures:
		check(Rules.validate(fixture.state) == "","Native fixture input valid: "+fixture.name+": "+Rules.validate(fixture.state))
		var result := Rules.act(fixture.state,fixture.action,fixture.payload)
		check(result.error == "","Native action accepted: "+fixture.name+": "+result.error)
		check(result.state == Rules.canonical_state(fixture.expected),"Native action parity: "+fixture.name+" actual "+JSON.stringify(result.state)+" expected "+JSON.stringify(fixture.expected))
		var forecast := Rules.forecast(fixture.state)
		var expected_forecast := Rules.canonical_state(fixture.forecast)
		forecast = Rules.canonical_state(forecast)
		for key in expected_forecast: check(forecast[key] == expected_forecast[key],"Native forecast parity %s.%s" % [fixture.name,key])

func test_land() -> void:
	var state := Rules.new_game()
	check(state.food == 18 and state.money == 12 and state.house == 55,"Native starting economy")
	check(state.layout.ownedParcels == [{"x":0,"y":0}],"Starter parcel owned")
	check(state.layout.farmland.size() == 9,"Native starting farmland")
	check(Rules.validate(state) == "","New game validates")
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(state))
	check(Rules.validate(decoded) == "","JSON numeric representation validates")
	decoded = Rules.canonical_state(decoded)
	check(decoded == state,"JSON canonicalization preserves native state")
	reject(state,"buy_land",{"position":{"x":1,"y":0}})
	state.money = 100000
	for position in [{"x":1,"y":1},{"x":-1,"y":-1},{"x":2,"y":0},{"x":0,"y":0}]: reject(state,"buy_land",{"position":position})
	state = run_action(state,"assign",{"task":"supplies"})
	state.money = Rules.LAND_PRICE+3
	reject(state,"buy_land",{"position":{"x":-1,"y":0}})
	state.money += 1
	state = run_action(state,"buy_land",{"position":{"x":-1,"y":0}})
	check(state.money == 4 and Rules.available_money(state) == 0,"Land preserves weekly coin reservation")
	reject(state,"buy_land",{"position":{"x":-1,"y":0}})
	check(Rules.placement_problem(state,"well",Vector2i(-1,0)) == "","Footprint straddles two owned parcels")
	check(Rules.placement_problem(state,"well",Vector2i(15,0)) != "","Whole footprint rejects locked seam")
	check(Rules.placement_problem(state,"scenery:well",Vector2i(-1,0)) == "","Negative one floor-divides to western parcel")
	check(Rules.placement_problem(state,"scenery:well",Vector2i(-16,0)) == "","Negative sixteen remains western parcel")
	check(Rules.placement_problem(state,"scenery:well",Vector2i(-17,0)) != "","Map lower edge guarded")
	check(Rules.placement_problem(state,"scenery:well",Vector2i(32,0)) != "","Map upper edge guarded")
	state.money = 1000
	state = run_action(state,"assign",{"task":"rest"})
	for parcel in [{"x":1,"y":0},{"x":0,"y":-1},{"x":0,"y":1},{"x":-1,"y":-1},{"x":1,"y":-1},{"x":-1,"y":1},{"x":1,"y":1}]: state = run_action(state,"buy_land",{"position":parcel})
	check(state.layout.ownedParcels.size() == 9,"Every finite parcel purchasable by cardinal expansion")
	state = positioned(state,"well",-1,0)
	check(state.layout.buildings[0].position == {"x":-1,"y":0},"Building crosses owned seam with fixed coordinates")
	for kind in ["pavement","dirtPath","farmland","fence","wattleFence"]:
		state = run_action(state,"infrastructure",{"kind":kind,"position":{"x":-10+state.layout.pavement.size()+state.layout.dirtPaths.size()+state.layout.farmland.size()+state.layout.fences.size(),"y":-10},"facing":1})
	state = run_action(state,"infrastructure",{"kind":"erase","position":{"x":-16,"y":-16}})

func test_layout() -> void:
	var state := Rules.new_game()
	state.money = 100
	check(Rules.footprint("house") == Vector2i(3,3),"House footprint")
	check(Rules.footprint("scenery:fence",0) == Vector2i(2,1) and Rules.footprint("scenery:fence",1) == Vector2i(1,2),"Scenery rotates footprint")
	for id in Rules.DEFINITIONS: check(Rules.footprint(id,3) == Vector2i(2,2),"Native building footprint "+id)
	for payload in [{"id":"well","position":{"x":15,"y":0},"instant":true},{"id":"well","position":{"x":6,"y":6},"instant":true},{"id":"well","position":{"x":5,"y":10},"instant":true},{"id":"well","position":{"x":1,"y":1},"facing":4},{"id":"unknown","position":{"x":1,"y":1}}]: reject(state,"place_building",payload)
	state = positioned(state,"well",1,1)
	state = run_action(state,"place_building",{"id":"well","position":{"x":3,"y":1},"facing":2})
	check(state.buildings.size() == 1 and state.money == 100 and state.layout.buildings[0].facing == 2,"Relocation costs nothing and retains one record")
	state = run_action(state,"rotate_building",{"id":"well"})
	check(state.layout.buildings[0].facing == 3,"Rotate building advances facing")
	state = run_action(state,"place_scenery",{"kind":"fence","position":{"x":12,"y":1},"facing":1})
	state = run_action(state,"remove_scenery",{"id":state.layout.scenery[0].id})
	check(state.layout.scenery.is_empty(),"Remove scenery by identity")
	state = run_action(state,"infrastructure",{"kind":"fence","position":{"x":1,"y":5},"facing":2})
	reject(state,"infrastructure",{"kind":"wattleFence","position":{"x":1,"y":6},"facing":0})
	state = run_action(state,"infrastructure",{"kind":"pavement","position":{"x":1,"y":5}})
	state = run_action(state,"infrastructure",{"kind":"erase","position":{"x":1,"y":6}})
	check(state.layout.fences.is_empty(),"Erase removes adjacent canonical fence edge")
	reject(state,"infrastructure",{"kind":"dirtPath","position":{"x":1,"y":5}})
	state = run_action(state,"infrastructure",{"kind":"erase","position":{"x":1,"y":5}})
	check(state.layout.pavement.is_empty(),"Erase path surface")
	state = run_action(state,"preview_season",{"season":3})
	check(Rules.display_season(state) == 3 and state.season == 0,"Visual season preserves actual calendar")
	state = run_action(state,"preview_season")
	check(Rules.display_season(state) == 0,"Clear visual preview")

func test_economy() -> void:
	var state := Rules.new_game()
	state = run_action(state,"assign",{"task":"buildWoodshed"})
	check(Rules.available_money(state) == 9 and Rules.available_materials(state).wood == 2,"Worker construction reserves money and stock")
	reject(state,"discard_material",{"id":"wood","amount":3})
	state = run_action(state,"assign",{"task":"rest"})
	check(Rules.available_materials(state).wood == 6,"Cancel releases reservation")
	state = run_action(state,"place_building",{"id":"woodshed","position":{"x":1,"y":1}})
	check(state.money == 9 and state.materials.wood == 2 and state.buildings[0].level == 0,"Direct construction spends immediately")
	reject(state,"upgrade_building",{"id":"woodshed"})
	state.week = 11
	state = week(state)
	check(state.buildings[0].level == 1 and state.character.buildingXP == 1,"Season finishes foundation and gives building XP")
	var locks := Rules.requirements(state,"barn")
	check(not locks.isMet and locks.locks.size() == 3,"House, skill and prerequisite gates")
	state = positioned(state,"workshop",1,4)
	state = run_action(state,"craft",{"amount":1})
	check(state.materials.wood == 0 and state.materials.planks == 1,"Workshop crafts 2 wood per plank")
	reject(state,"craft",{"amount":1})
	state = run_action(state,"buy_material",{"id":"wood","amount":1})
	state = positioned(state,"smithy",10,1)
	state = run_action(state,"craft",{"amount":1})
	check(state.materials.wood == 0 and state.materials.planks == 2,"Operational smithy halves wood cost")
	state = run_action(state,"debug_building",{"id":"smithy","level":2,"condition":0})
	state = run_action(state,"buy_material",{"id":"wood","amount":1})
	reject(state,"craft",{"amount":1})
	state.money = 100
	state.materials = {"wood":20,"stone":20,"planks":20}
	state = positioned(state,"storehouse",10,4)
	state = run_action(state,"debug_building",{"id":"storehouse","level":5,"condition":0})
	check(Rules.storage_capacity(state) == 220,"Worn storehouse retains storage")
	state = run_action(state,"upgrade_house")
	check(state.houseLevel == 2 and state.money == 92 and state.materials == {"wood":18,"stone":18,"planks":19},"House upgrade exact cost")
	state.character.buildingXP = 12
	state = run_action(state,"upgrade_building",{"id":"woodshed"})
	check(state.buildings[0].level == 2 and state.buildings[0].condition == 100,"Upgrade level and condition")
	state = run_action(state,"debug_building",{"id":"woodshed","level":2,"condition":20})
	state = run_action(state,"repair_building",{"id":"woodshed"})
	check(state.buildings[0].condition == 100,"Immediate repair condition")
	state = run_action(state,"debug_building",{"id":"woodshed","level":2,"condition":12.25})
	check(Rules.canonical_state(JSON.parse_string(JSON.stringify(state))).buildings[0].condition == 12.25,"Fractional condition survives canonicalization")
	for action in ["buy_material","discard_material","buy_seeds","craft"]:
		for amount in [0,-1,100001,true,"1",1.5]: reject(state,action,{"id":"wood","amount":amount})

func test_native_edit_actions() -> void:
	var populated := Rules.new_game()
	populated = run_action(populated,"place_scenery",{"kind":"fence","position":{"x":1,"y":1}})
	populated = run_action(populated,"place_scenery",{"kind":"well","position":{"x":4,"y":1}})
	for malformed in [true,false,1,0,[],{},1.5]: reject(populated,"remove_scenery",{"id":malformed})
	var empty_id := run_action(populated,"remove_scenery",{"id":""})
	check(empty_id.layout.scenery == populated.layout.scenery,"Empty scenery identity does not mean remove all")
	for payload in [{},{"id":null}]:
		var cleared := run_action(populated,"remove_scenery",payload)
		check(cleared.layout.scenery.is_empty(),"Missing/null identity explicitly removes all scenery")
	var selected: String = populated.layout.scenery[0].id
	var rotated := run_action(populated,"rotate_scenery",{"id":selected})
	check(rotated.layout.scenery[0].facing == 1 and rotated.layout.scenery[1] == populated.layout.scenery[1],"Rotate only selected scenery")
	reject(populated,"rotate_scenery",{"id":"absent"})
	var edge := run_action(Rules.new_game(),"place_scenery",{"kind":"fence","position":{"x":14,"y":15},"facing":0})
	reject(edge,"rotate_scenery",{"id":edge.layout.scenery[0].id})
	var collision := run_action(populated,"place_scenery",{"kind":"stores","position":{"x":1,"y":2}})
	reject(collision,"rotate_scenery",{"id":selected})
	var plan := run_action(Rules.new_game(),"assign",{"task":"buildWoodshed"})
	plan = run_action(plan,"remove_plan",{"id":"woodshed"})
	check(plan.layout.buildings.is_empty() and plan.assignments.ion == "rest" and Rules.available_money(plan) == 12 and Rules.available_materials(plan).wood == 6,"Remove worker plan and release assignment reservations")
	plan = run_action(Rules.new_game(),"place_building",{"id":"woodshed","position":{"x":1,"y":1}})
	reject(plan,"remove_plan",{"id":"woodshed"})
	plan = positioned(Rules.new_game(),"woodshed",1,1)
	reject(plan,"remove_plan",{"id":"woodshed"})
	reject(plan,"remove_plan",{"id":"unknown"})
	var boosted := run_action(Rules.new_game(),"debug_resources")
	check(boosted.food == 118 and boosted.money == 112,"Debug resources adds 100 food and money")
	boosted.food = 99950
	boosted.money = 100000
	boosted = run_action(boosted,"debug_resources")
	check(boosted.food == 100000 and boosted.money == 100000,"Debug resources respects storage caps")

func test_farming_and_routine() -> void:
	var state := Rules.new_game()
	state = run_action(state,"assign",{"task":"plant"})
	reject(state,"infrastructure",{"kind":"farmland","position":{"x":1,"y":1}})
	reject(state,"infrastructure",{"kind":"erase","position":{"x":5,"y":10}})
	state = week(state,"plant")
	check(state.cropWeeks == 1 and state.seeds == 4,"Plant seeds and grow in first week")
	reject(state,"assign",{"task":"plant"})
	reject(state,"infrastructure",{"kind":"farmland","position":{"x":1,"y":1}})
	reject(state,"assign",{"task":"tend"})
	for i in range(3): state = week(state)
	state = week(state,"tend")
	check(state.cropWeeks == 5 and state.tended,"Tend begins at four growing weeks")
	for i in range(19): state = week(state)
	check(state.season == 2 and state.cropWeeks == 24 and Rules.crop_stage(state) == "ripe","24 growing weeks ripens in autumn")
	state = week(state,"harvest")
	check(state.food == 27 and state.seeds == 10 and Rules.crop_stage(state) == "harvested","Tended harvest native yield")
	reject(state,"assign",{"task":"harvest"})
	state = Rules.new_game()
	for i in range(144):
		var task := "paid"
		if state.food <= 3 and state.money >= 4: task = "supplies"
		elif Rules._can_harvest(state): task = "harvest"
		elif state.house <= 45 and state.money >= 3: task = "repair"
		elif state.season == 0 and not state.planted: task = "plant"
		elif Rules._can_tend(state): task = "tend"
		if Rules.energy_cost(state,task) > state.character.energy: task = "rest"
		state = week(state,task)
		check(state.character.health == 100,"Healthy three-year routine week %d" % i)
	check(state.year == 3 and Rules.skill_level(state.character,"farming") == 4 and state.money > 12,"Three-year native survival routine")

func test_survival() -> void:
	var state := Rules.new_game()
	for i in range(5): state = week(state,"gatherWood")
	reject(state,"assign",{"task":"paid"})
	state = week(state)
	state = run_action(state,"assign",{"task":"paid"})
	state = Rules.new_game()
	for i in range(27):
		state = week(state)
		if state.phase == "dead": break
	check(state.phase == "dead" and state.character.health == 0,"Neglect ends household")
	for action in ["assign","end_week","continue","place_building","upgrade_building","repair_building","rotate_building","place_scenery","remove_scenery","rotate_scenery","remove_plan","debug_resources","infrastructure","buy_land","buy_material","discard_material","craft","buy_seeds","upgrade_house","preview_season","debug_building"]: reject(state,action)

func corrupt(state: Dictionary, key: String, value: Variant) -> void:
	var copy: Dictionary = state.duplicate(true)
	copy[key] = value
	check(Rules.validate(copy) != "","Reject corrupt "+key+"="+str(value))

func test_validation() -> void:
	var state := Rules.new_game()
	for key in ["version","revision","season","year","week","food","money","seeds","cropWeeks","houseLevel","phase","character","materials","assignments","planted","tended","harvested","layout","buildings"]:
		var incomplete: Dictionary = state.duplicate(true)
		incomplete.erase(key)
		check(Rules.validate(incomplete) != "","Missing required field "+key)
	for key in ["revision","season","year","week","food","money","seeds","cropWeeks","house","houseLevel"]:
		for value in [true,-1,100000000001,1.5,"1",[],{}]: corrupt(state,key,value)
	for value in [{"wood":-1,"stone":4,"planks":0},{"wood":true,"stone":4,"planks":0},{"wood":6,"stone":4},[],null]: corrupt(state,"materials",value)
	for value in [{},{"ion":"unknown"},{"ion":"rest","other":"rest"},{"ion":true}]: corrupt(state,"assignments",value)
	for value in [{"x":1,"y":1},{"x":0,"y":-2},{"x":true,"y":0}]:
		var copy: Dictionary = state.duplicate(true)
		copy.layout.ownedParcels.append(value)
		check(Rules.validate(copy) != "","Reject corrupt/disconnected parcel "+str(value))
	var duplicate: Dictionary = state.duplicate(true)
	duplicate.layout.ownedParcels.append({"x":0,"y":0})
	check(Rules.validate(duplicate) != "","Duplicate parcels")
	duplicate = state.duplicate(true)
	duplicate.layout.farmland.append(duplicate.layout.farmland[0])
	check(Rules.validate(duplicate) != "","Duplicate surfaces")
	for facing in [-1,4,true,1.5]:
		var copy: Dictionary = state.duplicate(true)
		copy.layout.fences.append({"position":{"x":1,"y":1},"facing":facing,"style":"rail"})
		check(Rules.validate(copy) != "","Invalid fence facing")
	for kind in ["buildings","scenery","pavement","dirtPaths","farmland","fences","ownedParcels"]:
		var copy: Dictionary = state.duplicate(true)
		copy.layout[kind] = null
		check(Rules.validate(copy) != "","Missing layout array "+kind)
	state = run_action(state,"end_week")
	for key in ["foodAfter","moneyAfter","houseAfter","seedsAfter","consumption","wear"]:
		var altered: Dictionary = state.duplicate(true)
		altered.report[key] += 1
		check(Rules.validate(altered) != "","Reject forged report result "+key)
	for key in ["consumption","wear","deficit","houseBefore","tasks","character","buildingsBefore"]:
		var copy: Dictionary = state.duplicate(true)
		copy.report.erase(key)
		check(Rules.validate(copy) != "","Incomplete report "+key)
	var copy: Dictionary = state.duplicate(true)
	copy.report.character.after.health -= 1
	check(Rules.validate(copy) != "","Report character must match state")
	copy = state.duplicate(true)
	copy.report.character.energyCost = 40
	check(Rules.validate(copy) != "","Report simulation must recompute")
	copy = state.duplicate(true)
	copy.lastMaterialHaul = {"wood":0,"stone":0,"planks":0}
	check(Rules.validate(copy) != "","Rest cannot claim gathering haul")

func _initialize() -> void:
	test_reference_fixtures()
	test_land()
	test_layout()
	test_economy()
	test_native_edit_actions()
	test_farming_and_routine()
	test_survival()
	test_validation()
	print("Rules: %d/%d checks passed" % [checks - failures,checks])
	quit(0 if failures == 0 else 1)
