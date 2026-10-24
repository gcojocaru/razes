extends RefCounted

const LAND_PRICE := 20
const MATERIALS := ["wood", "stone", "planks"]
const SEASONS := ["Spring", "Summer", "Autumn", "Winter"]
const INFRASTRUCTURE := ["pavement", "dirtPath", "farmland", "fence", "wattleFence", "erase"]
const SCENERY := ["barn", "well", "stores", "fence"]
const TASKS := {
	"rest": {"name":"Rest", "moneyCost":0},
	"plant": {"name":"Sow the field", "moneyCost":0},
	"tend": {"name":"Tend the crop", "moneyCost":0},
	"harvest": {"name":"Bring in the harvest", "moneyCost":0},
	"paid": {"name":"Work for wages", "moneyCost":0},
	"repair": {"name":"Mend the house", "moneyCost":3},
	"supplies": {"name":"Buy provisions", "moneyCost":4},
	"gatherWood": {"name":"Gather timber", "moneyCost":0},
	"gatherStone": {"name":"Gather stone", "moneyCost":0},
	"buildWoodshed": {"name":"Build woodshed", "moneyCost":3},
	"buildCellar": {"name":"Build root cellar", "moneyCost":4},
}
const DEFINITIONS := {
	"storehouse": {"title":"Storehouse", "cost":4,"food":0,"coins":0,"task":"","houseLevel":2,"prerequisite":"workshop","materials":{"wood":6,"stone":2,"planks":2}},
	"woodshed": {"title":"Woodshed", "cost":3,"food":0,"coins":1,"task":"buildWoodshed","houseLevel":1,"prerequisite":"","materials":{"wood":4,"stone":0,"planks":0}},
	"cellar": {"title":"Root cellar", "cost":4,"food":2,"coins":0,"task":"buildCellar","houseLevel":1,"prerequisite":"","materials":{"wood":2,"stone":4,"planks":0}},
	"barn": {"title":"Barn", "cost":5,"food":1,"coins":1,"task":"","houseLevel":2,"prerequisite":"well","materials":{"wood":6,"stone":2,"planks":0}},
	"well": {"title":"Well", "cost":3,"food":1,"coins":0,"task":"","houseLevel":1,"prerequisite":"","materials":{"wood":1,"stone":5,"planks":0}},
	"granary": {"title":"Granary", "cost":6,"food":2,"coins":1,"task":"","houseLevel":2,"prerequisite":"cellar","materials":{"wood":4,"stone":2,"planks":2}},
	"workshop": {"title":"Workshop", "cost":5,"food":0,"coins":2,"task":"","houseLevel":1,"prerequisite":"","materials":{"wood":4,"stone":2,"planks":0}},
	"bakery": {"title":"Bakery", "cost":7,"food":3,"coins":1,"task":"","houseLevel":3,"prerequisite":"granary","materials":{"wood":2,"stone":4,"planks":2}},
	"smithy": {"title":"Smithy", "cost":8,"food":0,"coins":3,"task":"","houseLevel":3,"prerequisite":"workshop","materials":{"wood":2,"stone":6,"planks":2}},
	"stable": {"title":"Stable", "cost":9,"food":1,"coins":2,"task":"","houseLevel":3,"prerequisite":"barn","materials":{"wood":4,"stone":2,"planks":4}},
	"apiary": {"title":"Apiary", "cost":4,"food":2,"coins":1,"task":"","houseLevel":2,"prerequisite":"well","materials":{"wood":3,"stone":0,"planks":1}},
}

static func _stock(wood: int = 0, stone: int = 0, planks: int = 0) -> Dictionary:
	return {"wood":wood,"stone":stone,"planks":planks}

static func _character() -> Dictionary:
	return {"health":100,"energy":100,"hunger":0,"farmingXP":0,"gatheringXP":0,"buildingXP":0,"strengthXP":0,"enduranceXP":0}

static func new_game() -> Dictionary:
	var farmland: Array = []
	for x in range(5,8):
		for y in range(10,13): farmland.append({"x":x,"y":y})
	return {"version":1,"revision":0,"season":0,"year":0,"week":0,"phase":"work","character":_character(),"food":18,"money":12,"house":55,"seeds":8,"cropWeeks":0,"materials":_stock(6,4),"houseLevel":1,"lastMaterialHaul":null,"assignments":{"ion":"rest"},"planted":false,"tended":false,"harvested":false,"report":null,"buildings":[],"layout":{"buildings":[],"scenery":[],"pavement":[],"dirtPaths":[],"farmland":farmland,"fences":[],"viewRotation":0,"ownedParcels":[{"x":0,"y":0}]},"debugSeason":null}

static func _turn(s: Dictionary) -> int:
	return int(s.year) * 4 + int(s.season)

static func display_season(s: Dictionary) -> int:
	return int(s.season) if s.get("debugSeason") == null else int(s.debugSeason)

static func skill_level(character: Dictionary, skill: String) -> int:
	return mini(5, 1 + int(character[skill + "XP"]) / 3)

static func _record(s: Dictionary, id: String) -> Dictionary:
	for record in s.buildings:
		if record.id == id: return record
	return {}

static func operational_level(s: Dictionary, id: String) -> int:
	var r := _record(s,id)
	return int(r.level) if not r.is_empty() and r.level > 0 and r.condition > 0 else 0

static func _builder(task: String) -> String:
	return "woodshed" if task == "buildWoodshed" else ("cellar" if task == "buildCellar" else "")

static func _reserved(s: Dictionary) -> Dictionary:
	var id := _builder(s.assignments.ion)
	return DEFINITIONS[id].materials.duplicate() if s.phase == "work" and id != "" else _stock()

static func available_money(s: Dictionary) -> int:
	return int(s.money) - (int(TASKS[s.assignments.ion].moneyCost) if s.phase == "work" else 0)

static func available_materials(s: Dictionary) -> Dictionary:
	var result: Dictionary = s.materials.duplicate()
	var reserved := _reserved(s)
	for id in MATERIALS: result[id] -= reserved[id]
	return result

static func storage_capacity(s: Dictionary) -> int:
	return 20 + (int(s.houseLevel)-1)*10 + int(_record(s,"storehouse").get("level",0))*40

static func _total(stock: Dictionary) -> int:
	return int(stock.wood) + int(stock.stone) + int(stock.planks)

static func _requirements(s: Dictionary, coins: int, materials: Dictionary, locks: Array, extra: Dictionary = {}) -> Dictionary:
	var free := available_materials(s)
	var shortages: Array = []
	if available_money(s) < coins: shortages.append("Needs %d free Galbeni; %d available." % [coins,maxi(0,available_money(s))])
	for id in MATERIALS:
		if free[id] < materials[id]: shortages.append("Needs %d free %s; %d available." % [materials[id],id,maxi(0,free[id])])
	var result := {"locks":locks,"shortages":shortages,"problems":locks+shortages,"isMet":locks.is_empty() and shortages.is_empty(),"coins":coins,"materials":materials,"freeCoins":available_money(s),"freeMaterials":free}
	result.merge(extra)
	return result

static func _unlock(s: Dictionary, id: String, level: int = 1) -> Array:
	var required := maxi(int(DEFINITIONS[id].houseLevel),level)
	var locks: Array = []
	if s.houseLevel < required: locks.append("Requires House level %d." % required)
	if skill_level(s.character,"building") < required: locks.append("Requires Building skill level %d." % required)
	var prerequisite: String = DEFINITIONS[id].prerequisite
	if prerequisite != "" and int(_record(s,prerequisite).get("level",0)) == 0: locks.append("Requires completed %s." % DEFINITIONS[prerequisite].title)
	return locks

static func requirements(s: Dictionary, id: String, level: int = 1) -> Dictionary:
	if id == "house":
		return _requirements(s,4*mini(5,int(s.houseLevel)+1),_stock(2,2,1),["House storage is already at level 5."] if s.houseLevel >= 5 else [])
	if not DEFINITIONS.has(id): return _requirements(s,0,_stock(),["Unknown building."])
	var locks := _unlock(s,id,level)
	if level < 1 or level > 5: locks.append("Building levels range from 1 to 5.")
	elif level == 1:
		if not _record(s,id).is_empty() or _builder(s.assignments.ion) == id: locks.append("This building already exists or has a weekly builder.")
	elif int(_record(s,id).get("level",0)) != level-1: locks.append("An upgrade to level %d needs a completed level %d building." % [level,level-1])
	var materials: Dictionary = DEFINITIONS[id].materials.duplicate()
	for material in MATERIALS: materials[material] *= clampi(level,1,5)
	return _requirements(s,int(DEFINITIONS[id].cost)*clampi(level,1,5),materials,locks,{"houseLevel":maxi(int(DEFINITIONS[id].houseLevel),level),"buildingLevel":maxi(int(DEFINITIONS[id].houseLevel),level),"prerequisite":DEFINITIONS[id].prerequisite})

static func repair_requirements(s: Dictionary, id: String) -> Dictionary:
	if not DEFINITIONS.has(id): return _requirements(s,0,_stock(),["Unknown building."])
	var r := _record(s,id)
	var material := _stock(0,1) if id in ["cellar","well","bakery","smithy"] else _stock(1)
	return _requirements(s,(int(DEFINITIONS[id].cost)+1)/2,material,[] if not r.is_empty() and r.level > 0 and r.condition < 100 else ["Repairs need a completed, worn building."])

static func _spend_problem(s: Dictionary, coins: int) -> String:
	return "Needs %d free Galbeni. Galbeni reserved for weekly work cannot be spent." % coins if available_money(s) < coins else ""

static func _pay(s: Dictionary, req: Dictionary) -> String:
	if not req.isMet: return " ".join(req.problems)
	s.money -= req.coins
	for id in MATERIALS: s.materials[id] -= req.materials[id]
	return ""

static func crop_stage(s: Dictionary) -> String:
	if s.season == 3: return "snow"
	if s.harvested: return "harvested"
	if not s.planted: return "bare"
	if s.cropWeeks < 3: return "sown"
	if s.cropWeeks < 5: return "sprouting"
	return "growing" if s.cropWeeks < 24 else "ripe"

static func _can_tend(s: Dictionary) -> bool:
	return s.season != 3 and s.planted and not s.tended and not s.harvested and s.cropWeeks >= 4 and s.cropWeeks < 24

static func _can_harvest(s: Dictionary) -> bool:
	return s.season == 2 and s.planted and not s.harvested and s.cropWeeks == 24

static func _plant_problem(s: Dictionary) -> String:
	if s.planted: return "This year’s harvest is complete. Plant again next Spring." if s.harvested else "This field is already planted. Plant again next Spring."
	if s.season != 0 or (s.phase == "summary" and s.week == 11): return "Planting is closed. Plant grain seeds next Spring."
	if s.phase != "work": return "Continue to the next week to assign planting."
	if s.layout.farmland.is_empty(): return "Paint farmland in Construction before planting."
	if s.seeds < 4: return "Planting needs 4 grain seeds; you have %d. Buy seeds first." % s.seeds
	return ""

static func energy_cost(s: Dictionary, task: String) -> int:
	if task == "rest": return 0
	return maxi(5,(10 if task in ["paid","supplies"] else 20)-2*(skill_level(s.character,"endurance")-1)) + (10 if s.character.health < 25 else 0)

static func task_options(s: Dictionary) -> Array:
	if s.phase != "work": return []
	var tasks: Array = []
	if s.season == 0 and not s.planted and not s.layout.farmland.is_empty(): tasks.append("plant")
	if _can_tend(s): tasks.append("tend")
	if _can_harvest(s): tasks.append("harvest")
	tasks.append_array(["repair","paid","supplies","gatherWood","gatherStone","rest"])
	if s.season != 3:
		for id in DEFINITIONS:
			if DEFINITIONS[id].task != "" and _record(s,id).is_empty(): tasks.append(DEFINITIONS[id].task)
	return tasks

static func _assignment_problem(s: Dictionary, task: String) -> String:
	if s.phase == "dead": return "Ion has died. Start a fresh household to play again."
	if not TASKS.has(task): return "Unknown work assignment."
	if task == "plant":
		var problem := _plant_problem(s)
		if problem != "": return problem
	if s.phase != "work": return "Continue to the next week before assigning work."
	var id := _builder(task)
	if id != "":
		var locks := _unlock(s,id)
		if not locks.is_empty(): return locks[0]
	if task not in task_options(s): return "That task is unavailable this week."
	var candidate: Dictionary = s.duplicate(true)
	candidate.assignments.ion = task
	var errors: Array = forecast(candidate).errors
	return errors[0] if not errors.is_empty() else ""

static func _haul(s: Dictionary) -> Dictionary:
	var result := {"expected":_stock(),"gained":_stock()}
	var task: String = s.assignments.ion
	if task in ["gatherWood","gatherStone"]:
		var id := "wood" if task == "gatherWood" else "stone"
		var amount := (2 if id == "wood" else 1)+skill_level(s.character,"gathering")-1
		result.expected[id] = amount
		result.gained[id] = mini(amount,maxi(0,storage_capacity(s)-_total(available_materials(s))))
	return result

static func _character_week(s: Dictionary, task: String, deficit: int, shelter: int, haul: Dictionary) -> Dictionary:
	var before: Dictionary = s.character.duplicate()
	var after: Dictionary = before.duplicate()
	var exposed: bool = s.season == 3 and shelter < 40
	var cost := energy_cost(s,task)
	after.energy = clampi(int(before.energy)+(25 if exposed else 35)+2*(skill_level(before,"endurance")-1) if task == "rest" else int(before.energy)-cost,0,100)
	after.hunger = clampi(int(before.hunger)+(25*deficit if deficit > 0 else -25),0,100)
	var starvation := 15 if after.hunger >= 75 else 0
	var exposure := 10 if exposed else 0
	after.health = clampi(int(before.health)-starvation-exposure+(10 if task == "rest" and starvation+exposure == 0 else 0),0,100)
	var skill := ""
	if task in ["plant","tend","harvest"]: skill = "farming"
	elif task in ["gatherWood","gatherStone"] and _total(haul) > 0: skill = "gathering"
	elif task == "repair" and shelter > s.house: skill = "building"
	if skill != "": after[skill+"XP"] = mini(12,int(after[skill+"XP"])+1)
	if task == "paid" or (task in ["gatherWood","gatherStone"] and _total(haul) > 0): after.strengthXP = mini(12,int(after.strengthXP)+1)
	if skill != "" or task == "paid" or _builder(task) != "": after.enduranceXP = mini(12,int(after.enduranceXP)+1)
	if s.week == 11:
		var foundations := 1 if _builder(task) != "" else 0
		for r in s.buildings:
			if r.level == 0 and not r.get("debugPlaced",false): foundations += 1
		after.buildingXP = mini(12,int(after.buildingXP)+foundations)
	return {"before":before,"after":after,"energyCost":cost,"starvationDamage":starvation,"exposureDamage":exposure}

static func forecast(s: Dictionary) -> Dictionary:
	var task: String = s.assignments.ion
	var p := {"foodCost":0,"moneyCost":TASKS[task].moneyCost,"foodGain":0,"moneyGain":0,"houseGain":0,"consumption":1,"wear":0,"foodAfter":0,"moneyAfter":0,"houseAfter":0,"seedCost":0,"seedGain":0,"seedsAfter":0,"errors":[],"warnings":[]}
	match task:
		"harvest":
			p.foodGain = 20+(8 if s.tended else 0)+2*(skill_level(s.character,"farming")-1)+2*operational_level(s,"well")
			p.seedGain = (6 if s.tended else 4)+operational_level(s,"granary")
		"repair": p.houseGain = 20+5*(skill_level(s.character,"building")-1)
		"paid": p.moneyGain = skill_level(s.character,"strength")+(1 if operational_level(s,"stable") > 0 else 0)
		"supplies": p.foodGain = (10 if operational_level(s,"cellar") > 0 else 7)+operational_level(s,"bakery")
		"plant": p.seedCost = 4
	if s.week == 11:
		p.wear = 6 if s.season == 3 and operational_level(s,"woodshed") > 0 else [6,5,8,14][int(s.season)]
		for r in s.buildings:
			if r.level > 0 and r.condition > 0 and r.completedSeason < _turn(s):
				p.foodGain += DEFINITIONS[r.id].food*r.level
				p.moneyGain += DEFINITIONS[r.id].coins*r.level
	p.seedsAfter = mini(100000,int(s.seeds)-int(p.seedCost)+int(p.seedGain))
	if p.moneyCost > s.money: p.errors.append("Work costs %d Galbeni; only %d is available now." % [p.moneyCost,s.money])
	if p.seedCost > s.seeds: p.errors.append("Sowing needs 4 grain seeds; only %d are available. Buy seeds first." % s.seeds)
	var reserved := _reserved(s)
	for id in MATERIALS:
		if s.materials[id] < reserved[id]:
			p.errors.append("Building work needs its materials already in storage.")
			break
	var haul := _haul(s)
	if haul.gained != haul.expected: p.warnings.append("Limited storage: free storage limits Ion’s haul.")
	var repaired := mini(100,int(s.house)+int(p.houseGain))
	if s.season == 3 and int(s.week)%4 == 3: p.consumption = 1+(1 if repaired < 40 else 0)-(1 if operational_level(s,"woodshed") > 0 else 0)
	p.foodAfter = mini(100000,int(s.food)+int(p.foodGain))-int(p.consumption)
	p.moneyAfter = mini(100000,int(s.money)-int(p.moneyCost)+int(p.moneyGain))
	p.houseAfter = maxi(0,repaired-int(p.wear))
	p.character = _character_week(s,task,maxi(0,-int(p.foodAfter)),repaired,haul.gained)
	if p.character.energyCost > s.character.energy: p.errors.append("Ion needs %d energy; he has %d. Assign Rest first." % [p.character.energyCost,s.character.energy])
	if p.character.starvationDamage > 0: p.warnings.append("Starvation: Ion will lose 15 health. Buy provisions or harvest food.")
	if p.character.exposureDamage > 0: p.warnings.append("Winter exposure: Ion will lose 10 health. Mend the house to reach 40 shelter.")
	if p.character.after.health == 0: p.warnings.append("This week will kill Ion. Review his needs and supplies before confirming.")
	if p.foodAfter < 0: p.warnings.append("Expected food shortfall: %d. Food will fall to zero." % -p.foodAfter)
	if p.seedsAfter < 4: p.warnings.append("Fewer than 4 seeds remain. Harvest or buy seeds before the next sowing.")
	if p.houseAfter < 40: p.warnings.append("The house will be vulnerable. Cold winter shelter needs extra food.")
	if s.season == 0 and s.week == 11 and not s.planted and task != "plant": p.warnings.append("Without planting now, there will be no autumn harvest.")
	if s.season == 2 and s.week == 11 and s.planted and not s.harvested and task != "harvest": p.warnings.append("The unharvested crop will be lost when winter comes.")
	p.materialHaul = haul
	return p

static func footprint(kind: String, facing: int = 0) -> Vector2i:
	if kind == "house": return Vector2i(3,3)
	if DEFINITIONS.has(kind) or kind == "scenery:barn": return Vector2i(2,2)
	if kind == "scenery:fence": return Vector2i(2,1) if facing%2 == 0 else Vector2i(1,2)
	return Vector2i.ONE

static func _point(tile: Vector2i) -> Dictionary:
	return {"x":tile.x,"y":tile.y}

static func _vector(point: Dictionary) -> Vector2i:
	return Vector2i(int(point.x),int(point.y))

static func _cells(tile: Vector2i, size: Vector2i) -> Array:
	var result: Array = []
	for x in range(tile.x,tile.x+size.x):
		for y in range(tile.y,tile.y+size.y): result.append(Vector2i(x,y))
	return result

static func _owned(s: Dictionary, tile: Vector2i) -> bool:
	return _point(Vector2i(floori(float(tile.x)/16.0),floori(float(tile.y)/16.0))) in s.layout.ownedParcels

static func _edge(tile: Vector2i, facing: int) -> String:
	return "h:%d:%d" % [tile.x,tile.y+(1 if facing == 2 else 0)] if facing%2 == 0 else "v:%d:%d" % [tile.x+(1 if facing == 1 else 0),tile.y]

static func _farmland_problem(s: Dictionary) -> String:
	if s.planted and not s.harvested and s.season < 3: return "Harvest the crop before changing farmland."
	if s.phase == "work" and s.assignments.ion in ["plant","tend","harvest"]: return "Cancel the farming assignment before changing farmland."
	return ""

static func placement_problem(s: Dictionary, kind: String, tile: Vector2i, facing: int = 0) -> String:
	return _placement(canonical_state(s),kind,tile,facing)

static func _placement(s: Dictionary, kind: String, tile: Vector2i, facing: int = 0, ignoring: String = "", duplicates: bool = true) -> String:
	if not DEFINITIONS.has(kind) and kind not in INFRASTRUCTURE and not (kind.begins_with("scenery:") and kind.trim_prefix("scenery:") in SCENERY): return "Unknown structure."
	if facing < 0 or facing > 3: return "Choose one of four directions."
	var cells := _cells(tile,footprint(kind,facing))
	for cell in cells:
		if cell.x < -16 or cell.y < -16 or cell.x > 31 or cell.y > 31: return "Keep the whole footprint inside the playing area."
		if not _owned(s,cell): return "Keep the whole footprint on owned land."
	var point := _point(tile)
	if duplicates and (kind == "farmland" or (kind == "erase" and point in s.layout.farmland)):
		var problem := _farmland_problem(s)
		if problem != "": return problem
	if kind == "erase": return ""
	if duplicates:
		if kind in ["pavement","dirtPath"] and (point in s.layout.pavement or point in s.layout.dirtPaths): return "A path surface is already laid here."
		if kind in ["fence","wattleFence"]:
			for fence in s.layout.fences:
				if _edge(tile,facing) == _edge(_vector(fence.position),fence.facing): return "A fence already occupies this edge."
	var occupied := _cells(Vector2i(6,6),Vector2i(3,3))
	for cell in s.layout.farmland:
		if not (kind == "farmland" and not duplicates and cell == point): occupied.append(_vector(cell))
	for building in s.layout.buildings:
		if building.id != kind: occupied.append_array(_cells(_vector(building.position),footprint(building.id,building.facing)))
	for scenery in s.layout.scenery:
		if scenery.id != ignoring: occupied.append_array(_cells(_vector(scenery.position),footprint("scenery:"+scenery.kind,scenery.facing)))
	if kind not in INFRASTRUCTURE or kind == "farmland":
		for cell in s.layout.pavement+s.layout.dirtPaths: occupied.append(_vector(cell))
		for fence in s.layout.fences: occupied.append(_vector(fence.position))
	for cell in cells:
		if cell in occupied: return "This space is occupied or reserved for the house or farmland."
	return ""

static func _first_available(s: Dictionary, id: String) -> Variant:
	var preferred := Vector2i(3,8) if id == "woodshed" else Vector2i(10,5)
	if placement_problem(s,id,preferred) == "": return _point(preferred)
	for y in range(-16,32):
		for x in range(-16,32):
			if placement_problem(s,id,Vector2i(x,y)) == "": return {"x":x,"y":y}
	return null

static func _placement_index(s: Dictionary, id: String) -> int:
	for index in range(s.layout.buildings.size()):
		if s.layout.buildings[index].id == id: return index
	return -1

static func _new_record(s: Dictionary, id: String, level: int = 0, legacy: bool = false, debug: bool = false) -> Dictionary:
	return {"id":id,"level":level,"condition":100.0,"completedSeason":_turn(s),"legacyAssignment":legacy,"debugPlaced":debug}

static func act(state: Dictionary, action: String, payload: Dictionary = {}) -> Dictionary:
	var problem := validate(state)
	if problem != "": return {"state":state.duplicate(true),"error":problem}
	if state.phase == "dead": return {"state":state.duplicate(true),"error":"Ion has died. Start a fresh household to play again."}
	var next: Dictionary = canonical_state(state)
	problem = _apply(next,action,payload)
	if problem == "":
		next.revision += 1
		problem = validate(next)
	return {"state":canonical_state(next) if problem == "" else state.duplicate(true),"error":problem}

static func _apply(s: Dictionary, action: String, p: Dictionary) -> String:
	if p.get("id") != null and not p.id is String: return "Choose a valid structure identity."
	var id: String = p.get("id") if p.get("id") != null else ""
	var amount: int = int(p.get("amount",0)) if _integer(p.get("amount"),1,100000) else 0
	if action in ["place_building","place_scenery","infrastructure","buy_land"] and not _position_valid(p.get("position"),-16,31): return "Choose a valid grid position."
	if action in ["place_building","place_scenery","infrastructure"] and not _integer(p.get("facing",0),0,3): return "Choose one of four directions."
	match action:
		"assign":
			if not p.get("task") is String: return "Unknown work assignment."
			var problem := _assignment_problem(s,p.task)
			if problem != "": return problem
			var building := _builder(p.task)
			if building != "" and _placement_index(s,building) < 0:
				var position: Variant = _first_available(s,building)
				if position == null: return "There is no free space for that building."
				s.layout.buildings.append({"id":building,"position":position,"facing":0})
			s.assignments.ion = p.task
		"end_week":
			if s.phase != "work": return "Work has already been resolved."
			var problem := _assignment_problem(s,s.assignments.ion)
			if problem != "": return problem
			var f := forecast(s)
			if not f.errors.is_empty(): return f.errors[0]
			s.report = {"foodBefore":s.food,"foodAfter":maxi(0,f.foodAfter),"moneyBefore":s.money,"moneyAfter":f.moneyAfter,"houseBefore":s.house,"houseAfter":f.houseAfter,"consumption":f.consumption,"wear":f.wear,"deficit":maxi(0,-f.foodAfter),"tasks":["Ion: "+TASKS[s.assignments.ion].name],"seedsBefore":s.seeds,"seedsAfter":f.seedsAfter,"character":f.character.duplicate(true),"buildingsBefore":s.buildings.duplicate(true)}
			s.food = maxi(0,f.foodAfter)
			s.money = f.moneyAfter
			s.house = f.houseAfter
			s.seeds = f.seedsAfter
			var reserved := _reserved(s)
			for material in MATERIALS: s.materials[material] += f.materialHaul.gained[material]-reserved[material]
			s.lastMaterialHaul = f.materialHaul.gained.duplicate() if _total(f.materialHaul.expected) > 0 else null
			var task: String = s.assignments.ion
			var building := _builder(task)
			if building != "": s.buildings.append(_new_record(s,building,0,true))
			if task == "plant": s.planted = true
			if task == "tend": s.tended = true
			if task == "harvest": s.harvested = true
			if s.planted and not s.harvested and s.season != 3: s.cropWeeks = mini(24,int(s.cropWeeks)+1)
			if s.week == 11:
				for r in s.buildings:
					if r.level == 0:
						r.level = 1
						r.completedSeason = _turn(s)
					elif r.completedSeason < _turn(s) and r.condition > 0:
						r.condition = maxf(0,float(r.condition)-20)
						if r.condition == 0 and r.level > 1:
							r.level -= 1
							r.condition = 60.0
			s.character = f.character.after.duplicate()
			s.phase = "dead" if s.character.health == 0 else "summary"
		"continue":
			if s.phase != "summary": return "Finish this week before continuing."
			if _turn(s) >= 400003 and s.week == 11: return "This settlement has reached its calendar limit."
			if s.week == 11:
				s.week = 0
				if s.season == 3:
					s.year += 1
					s.season = 0
					s.planted = false
					s.tended = false
					s.harvested = false
					s.cropWeeks = 0
				else: s.season += 1
			else: s.week += 1
			s.phase = "work"
			s.report = null
			s.lastMaterialHaul = null
			if _assignment_problem(s,s.assignments.ion) != "": s.assignments.ion = "rest"
		"place_building":
			if not DEFINITIONS.has(id): return "Unknown building."
			if not p.get("instant",false) is bool: return "Choose a valid construction mode."
			var index := _placement_index(s,id)
			var facing: int = int(p.get("facing",s.layout.buildings[index].facing if index >= 0 else 0))
			var problem := placement_problem(s,id,_vector(p.position),facing)
			if problem != "": return problem
			if index >= 0: s.layout.buildings.remove_at(index)
			s.layout.buildings.append({"id":id,"position":p.position.duplicate(),"facing":facing})
			if _record(s,id).is_empty():
				if p.get("instant",false):
					s.buildings.append(_new_record(s,id,1,false,true))
					if _builder(s.assignments.ion) == id: s.assignments.ion = "rest"
				elif _builder(s.assignments.ion) != id:
					problem = _pay(s,requirements(s,id))
					if problem != "": return problem
					s.buildings.append(_new_record(s,id))
		"upgrade_building", "repair_building":
			if not DEFINITIONS.has(id): return "Unknown building."
			var record := _record(s,id)
			if action == "upgrade_building" and (record.is_empty() or record.level < 1 or record.level >= 5): return "An upgrade needs a completed building below level 5."
			var req := repair_requirements(s,id) if action == "repair_building" else requirements(s,id,int(record.level)+1)
			var problem := _pay(s,req)
			if problem != "": return problem
			if action == "upgrade_building": record.level += 1
			record.condition = 100.0
		"rotate_building":
			var index := _placement_index(s,id)
			if index < 0: return "Place a building first."
			s.layout.buildings[index].facing = (int(s.layout.buildings[index].facing)+1)%4
		"place_scenery":
			if not p.get("kind") is String or p.kind not in SCENERY: return "Unknown scenery."
			var problem := placement_problem(s,"scenery:"+p.kind,_vector(p.position),int(p.get("facing",0)))
			if problem != "": return problem
			s.layout.scenery.append({"id":"scenery-%d" % (int(s.revision)+1),"kind":p.kind,"position":p.position.duplicate(),"facing":int(p.get("facing",0))})
		"remove_scenery":
			for index in range(s.layout.scenery.size()-1,-1,-1):
				if p.get("id") == null or s.layout.scenery[index].id == id: s.layout.scenery.remove_at(index)
		"rotate_scenery":
			for scenery in s.layout.scenery:
				if scenery.id == id:
					scenery.facing = (int(scenery.facing)+1)%4
					return ""
			return "Select scenery first."
		"remove_plan":
			if not DEFINITIONS.has(id): return "Unknown building."
			if not _record(s,id).is_empty(): return "Completed buildings cannot be removed from a live household."
			for index in range(s.layout.buildings.size()-1,-1,-1):
				if s.layout.buildings[index].id == id: s.layout.buildings.remove_at(index)
			if _builder(s.assignments.ion) == id: s.assignments.ion = "rest"
		"debug_resources":
			s.money = mini(100000,int(s.money)+100)
			s.food = mini(100000,int(s.food)+100)
		"infrastructure":
			if not p.get("kind") is String or p.kind not in INFRASTRUCTURE: return "Unknown infrastructure."
			var facing: int = int(p.get("facing",0))
			var problem := placement_problem(s,p.kind,_vector(p.position),facing)
			if problem != "": return problem
			if p.kind == "erase":
				for key in ["pavement","dirtPaths","farmland"]: s.layout[key].erase(p.position)
				var edges: Array = []
				for direction in range(4): edges.append(_edge(_vector(p.position),direction))
				for index in range(s.layout.fences.size()-1,-1,-1):
					var fence: Dictionary = s.layout.fences[index]
					if _edge(_vector(fence.position),fence.facing) in edges: s.layout.fences.remove_at(index)
			else:
				problem = _spend_problem(s,1)
				if problem != "": return problem
				s.money -= 1
				if p.kind in ["fence","wattleFence"]: s.layout.fences.append({"position":p.position.duplicate(),"facing":facing,"style":"wattle" if p.kind == "wattleFence" else "rail"})
				else: s.layout[{"pavement":"pavement","dirtPath":"dirtPaths","farmland":"farmland"}[p.kind]].append(p.position.duplicate())
		"buy_land":
			var point := _vector(p.position)
			if abs(point.x) > 1 or abs(point.y) > 1: return "Choose a parcel inside the 3 × 3 map."
			if p.position in s.layout.ownedParcels: return "This parcel is already owned."
			var adjacent := false
			for owned in s.layout.ownedParcels:
				var distance := point-_vector(owned)
				if abs(distance.x)+abs(distance.y) == 1: adjacent = true
			if not adjacent: return "New land must share an edge with owned land."
			var problem := _spend_problem(s,LAND_PRICE)
			if problem != "": return problem
			s.money -= LAND_PRICE
			s.layout.ownedParcels.append(p.position.duplicate())
		"buy_material", "discard_material":
			if id not in MATERIALS: return "Unknown material."
			if amount == 0: return "Choose a positive quantity, at most 100000."
			if action == "buy_material":
				if _total(s.materials)+amount > storage_capacity(s): return "Choose a positive quantity that fits in shared storage."
				var cost := amount*(3 if id == "planks" else 1)
				var problem := _spend_problem(s,cost)
				if problem != "": return problem
				s.money -= cost
				s.materials[id] += amount
			else:
				if available_materials(s)[id] < amount: return "Choose a positive quantity of free supplies to discard."
				s.materials[id] -= amount
		"craft":
			if amount == 0: return "Choose a positive plank quantity, at most 100000."
			if operational_level(s,"workshop") == 0: return "Crafting needs a completed Workshop with condition above zero."
			var wood := amount*(1 if operational_level(s,"smithy") > 0 else 2)
			if available_materials(s).wood < wood: return "Needs %d free wood." % wood
			if _total(s.materials)-wood+amount > storage_capacity(s): return "The crafted planks must fit in shared storage after using their ingredients."
			s.materials.wood -= wood
			s.materials.planks += amount
		"buy_seeds":
			if amount == 0 or s.seeds > 100000-amount: return "Choose a positive seed quantity that fits in seed storage (100000 maximum)."
			var problem := _spend_problem(s,amount)
			if problem != "": return problem
			s.money -= amount
			s.seeds += amount
		"upgrade_house": return _upgrade_house(s)
		"preview_season":
			if p.get("season") != null and not _integer(p.season,0,3): return "Choose a valid visual season."
			s.debugSeason = p.get("season")
		"debug_building":
			var record := _record(s,id)
			if record.is_empty() or not _integer(p.get("level"),1,5) or not _number(p.get("condition",100),0,100): return "Choose an existing building, level 1–5 and condition 0–100."
			if record.level == 0: record.completedSeason = _turn(s)
			record.level = p.level
			record.condition = p.get("condition",100)
			record.debugPlaced = true
			if s.phase == "work" and _builder(s.assignments.ion) == id: s.assignments.ion = "rest"
		_: return "Unknown action."
	return ""

static func _upgrade_house(s: Dictionary) -> String:
	var problem := _pay(s,requirements(s,"house"))
	if problem == "": s.houseLevel += 1
	return problem

static func _integer(value: Variant, low: int = 0, high: int = 100000) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= low and value <= high

static func _number(value: Variant, low: float, high: float) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value)) and value >= low and value <= high

static func _position_valid(value: Variant, low: int = -16, high: int = 31) -> bool:
	return value is Dictionary and value.size() == 2 and _integer(value.get("x"),low,high) and _integer(value.get("y"),low,high)

static func _stock_valid(value: Variant, wood_limit: int = 100000, stone_limit: int = 100000, plank_limit: int = 100000) -> bool:
	return value is Dictionary and value.size() == 3 and _integer(value.get("wood"),0,wood_limit) and _integer(value.get("stone"),0,stone_limit) and _integer(value.get("planks"),0,plank_limit)

static func _character_valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 8: return false
	for key in ["health","energy","hunger"]:
		if not _integer(value.get(key),0,100): return false
	for key in ["farmingXP","gatheringXP","buildingXP","strengthXP","enduranceXP"]:
		if not _integer(value.get(key),0,12): return false
	return true

static func _records_valid(records: Variant, turn: int) -> bool:
	if not records is Array or records.size() > 11: return false
	var seen: Array = []
	for r in records:
		if not r is Dictionary or not DEFINITIONS.has(r.get("id","")) or r.id in seen: return false
		seen.append(r.id)
		if not _integer(r.get("level"),0,5) or not _number(r.get("condition"),0,100) or not _integer(r.get("completedSeason"),0,turn): return false
		if not r.get("legacyAssignment") is bool or (r.get("debugPlaced") != null and not r.debugPlaced is bool): return false
	return true

static func canonical_state(state: Dictionary) -> Dictionary:
	return _canonical(state)

static func _canonical(value: Variant) -> Variant:
	# Godot JSON uses floats; positions need one numeric representation for dictionary equality.
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value) and abs(value) <= 1000000000:
		return int(value)
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value: result[key] = _canonical(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value: result.append(_canonical(item))
		return result
	return value

static func validate(state: Dictionary) -> String:
	return _validate(canonical_state(state))

static func _validate(s: Dictionary) -> String:
	var invalid := "This save is invalid or incomplete. Start a fresh household."
	if not _integer(s.get("version"),1,1): return "Unsupported save version. Start a fresh household."
	for key in ["food","money","seeds","year"]:
		if not _integer(s.get(key)): return invalid
	if not _integer(s.get("revision"),0,1000000000) or not _integer(s.get("season"),0,3) or not _integer(s.get("week"),0,11) or not _integer(s.get("house"),0,100) or not _integer(s.get("houseLevel"),1,5) or not _integer(s.get("cropWeeks"),0,24): return invalid
	if s.get("phase") not in ["work","summary","dead"] or not _character_valid(s.get("character")) or not _stock_valid(s.get("materials")): return invalid
	if (s.phase == "dead") != (s.character.health == 0): return invalid
	if s.get("debugSeason") != null and not _integer(s.debugSeason,0,3): return invalid
	if not s.get("assignments") is Dictionary or s.assignments.size() != 1 or not TASKS.has(s.assignments.get("ion","")): return invalid
	for key in ["planted","tended","harvested"]:
		if not s.get(key) is bool: return invalid
	if not _records_valid(s.get("buildings"),_turn(s)): return invalid
	if not s.get("layout") is Dictionary: return invalid
	var l: Dictionary = s.layout
	if not _integer(l.get("viewRotation"),0,3): return invalid
	for key in ["buildings","scenery","pavement","dirtPaths","farmland","fences","ownedParcels"]:
		if not l.get(key) is Array: return invalid
	if l.ownedParcels.is_empty() or l.ownedParcels.size() > 9 or {"x":0,"y":0} not in l.ownedParcels: return "Invalid land ownership: starter parcel is required."
	var parcels: Array = []
	for parcel in l.ownedParcels:
		if not _position_valid(parcel,-1,1) or parcel in parcels: return "Invalid or duplicate owned parcel."
		parcels.append(parcel)
	var connected: Array = [{"x":0,"y":0}]
	for iteration in range(9):
		for parcel in parcels:
			if parcel in connected: continue
			for existing in connected:
				var delta := _vector(parcel)-_vector(existing)
				if abs(delta.x)+abs(delta.y) == 1:
					connected.append(parcel)
					break
	if connected.size() != parcels.size(): return "Owned land must remain connected by shared edges."
	if l.buildings.size() > 11 or l.scenery.size() > 128 or l.pavement.size()+l.dirtPaths.size()+l.farmland.size() > 2304 or l.fences.size() > 9216: return "Excessive settlement structures."
	var ids: Array = []
	for building in l.buildings:
		if not building is Dictionary or not DEFINITIONS.has(building.get("id","")) or building.id in ids or not _position_valid(building.get("position")) or not _integer(building.get("facing"),0,3): return "Invalid building placement."
		ids.append(building.id)
	var scenery_ids: Array = []
	for scenery in l.scenery:
		if not scenery is Dictionary or not scenery.get("id") is String or scenery.id.is_empty() or scenery.id.to_utf8_buffer().size() > 64 or scenery.id in scenery_ids or scenery.get("kind") not in SCENERY or not _position_valid(scenery.get("position")) or not _integer(scenery.get("facing"),0,3): return "Invalid scenery placement."
		scenery_ids.append(scenery.id)
	var surfaces: Array = []
	for point in l.pavement+l.dirtPaths+l.farmland:
		if not _position_valid(point) or point in surfaces: return "Invalid or duplicate ground surface."
		surfaces.append(point)
	var edges: Array = []
	for fence in l.fences:
		if not fence is Dictionary or not _position_valid(fence.get("position")) or not _integer(fence.get("facing"),0,3) or fence.get("style") not in ["rail","wattle"]: return "Invalid fence."
		var edge := _edge(_vector(fence.position),int(fence.facing))
		if edge in edges: return "Duplicate fence edge."
		edges.append(edge)
	for building in l.buildings:
		var problem := _placement(s,building.id,_vector(building.position),int(building.facing),"",false)
		if problem != "": return problem
	for scenery in l.scenery:
		var problem := _placement(s,"scenery:"+scenery.kind,_vector(scenery.position),int(scenery.facing),scenery.id,false)
		if problem != "": return problem
	for key in ["pavement","dirtPaths","farmland"]:
		for point in l[key]:
			var kind: String = "dirtPath" if key == "dirtPaths" else key
			var problem := _placement(s,kind,_vector(point),0,"",false)
			if problem != "": return problem
	for fence in l.fences:
		var problem := _placement(s,"fence",_vector(fence.position),int(fence.facing),"",false)
		if problem != "": return problem
	for record in s.buildings:
		if record.id not in ids: return "A construction is missing its position."
		if record.legacyAssignment and not record.get("debugPlaced",false) and (_builder(DEFINITIONS[record.id].task) == "" or int(record.completedSeason)%4 == 3): return "Invalid worker building."
	var resolved: bool = s.phase != "work"
	if s.planted:
		if s.cropWeeks == 0: return invalid
	elif s.cropWeeks != 0 or s.tended or s.harvested: return invalid
	if s.cropWeeks > int(s.season)*12+int(s.week)+(1 if resolved else 0): return invalid
	if s.tended and (not s.planted or s.cropWeeks < 5): return invalid
	if s.harvested and (not s.planted or s.cropWeeks != 24 or s.season < 2): return invalid
	if s.planted and not s.harvested and s.season < 3 and l.farmland.is_empty(): return "A growing crop is missing its farmland."
	var task: String = s.assignments.ion
	if task == "plant" and (s.season != 0 or (not s.planted or s.cropWeeks != 1 if resolved else s.planted)): return invalid
	if task == "tend" and ((not s.tended or s.harvested or s.season == 3) if resolved else not _can_tend(s)): return invalid
	if task == "harvest" and (s.season != 2 or (not s.harvested if resolved else not _can_harvest(s))): return invalid
	if s.get("lastMaterialHaul") != null:
		if not resolved or not _stock_valid(s.lastMaterialHaul,6,5,0): return invalid
	var builder := _builder(task)
	if builder != "":
		var record := _record(s,builder)
		if s.season == 3 or builder not in ids or (record.is_empty() or record.completedSeason != _turn(s) or not record.legacyAssignment if resolved else not record.is_empty()): return invalid
	if resolved:
		var problem := _validate_report(s)
		if problem != "": return problem
	else:
		if s.get("report") != null: return invalid
		var problem := _assignment_problem(s,task)
		if problem != "": return problem
	return ""

static func _validate_report(s: Dictionary) -> String:
	var invalid := "Invalid weekly report."
	if not s.get("report") is Dictionary: return "This save has no weekly report."
	var r: Dictionary = s.report
	for key in ["foodBefore","foodAfter","moneyBefore","moneyAfter","seedsBefore","seedsAfter"]:
		if not _integer(r.get(key)): return invalid
	for key in ["houseBefore","houseAfter"]:
		if not _integer(r.get(key),0,100): return invalid
	if not _integer(r.get("consumption"),0,2) or not _integer(r.get("deficit"),0,int(r.consumption)) or not _integer(r.get("wear"),0,14): return invalid
	if r.get("tasks") != ["Ion: "+TASKS[s.assignments.ion].name] or not _records_valid(r.get("buildingsBefore"),_turn(s)): return invalid
	if not r.get("character") is Dictionary: return invalid
	var c: Dictionary = r.character
	if not _character_valid(c.get("before")) or not _character_valid(c.get("after")) or c.before.health == 0 or c.after != s.character: return invalid
	for key in ["energyCost","starvationDamage","exposureDamage"]:
		if not _integer(c.get(key),0,100): return invalid
	var before: Dictionary = s.duplicate(true)
	before.character = c.before.duplicate()
	before.house = r.houseBefore
	before.food = r.foodBefore
	before.money = r.moneyBefore
	before.seeds = r.seedsBefore
	before.buildings = r.buildingsBefore.duplicate(true)
	before.phase = "work"
	var task: String = s.assignments.ion
	var projected := forecast(before)
	for key in ["moneyAfter","houseAfter","seedsAfter","consumption","wear"]:
		if r[key] != projected[key]: return invalid
	if r.foodAfter != maxi(0,projected.foodAfter) or r.deficit != maxi(0,-projected.foodAfter): return invalid
	var shelter := mini(100,int(before.house)+(20+5*(skill_level(before.character,"building")-1) if task == "repair" else 0))
	var expected := _character_week(before,task,int(r.deficit),shelter,s.lastMaterialHaul if s.get("lastMaterialHaul") != null else _stock())
	if expected != c or before.character.energy < expected.energyCost: return invalid
	var gathering: bool = task in ["gatherWood","gatherStone"]
	if gathering != (s.get("lastMaterialHaul") != null): return invalid
	if gathering:
		var limit := (2 if task == "gatherWood" else 1)+skill_level(before.character,"gathering")-1
		if task == "gatherWood" and (s.lastMaterialHaul.stone != 0 or s.lastMaterialHaul.wood > limit): return invalid
		if task == "gatherStone" and (s.lastMaterialHaul.wood != 0 or s.lastMaterialHaul.stone > limit): return invalid
	return ""
