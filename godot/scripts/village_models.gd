class_name VillageModels
extends RefCounted

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}

static func building(id: String, level: int = 1, condition: float = 100.0, winter: bool = false, progress: float = 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = id.capitalize()
	var rank := clampi(level, 1, 5)
	var stage := clampf(progress, 0, 1)
	if level <= 0 and stage >= 1:
		stage = 0
	if stage < 1:
		_construction(root, id, rank, stage, winter)
	else:
		match id:
			"house": _house(root, rank, winter)
			"woodshed": _woodshed(root, rank, winter)
			"cellar": _cellar(root, rank, winter)
			"barn": _barn(root, rank, winter)
			"well": _well(root, rank, winter)
			"granary": _granary(root, rank, winter)
			"workshop": _workshop(root, rank, winter)
			"bakery": _bakery(root, rank, winter)
			"smithy": _smithy(root, rank, winter)
			"stable": _stable(root, rank, winter)
			"apiary": _apiary(root, rank, winter)
			"storehouse": _storehouse(root, rank, winter)
			_: _barn(root, rank, winter)
		if condition < 75:
			_wear(root, id, condition)
	return root

static func figure(task: String = "rest") -> Node3D:
	var root := Node3D.new()
	root.name = "Ion"
	for side in [-1, 1]:
		_box(root, "Boot", Vector3(.17, .16, .29), Vector3(side * .12, .08, .04), "leather")
		_box(root, "Trousers", Vector3(.15, .61, .17), Vector3(side * .12, .43, 0), "trousers")
		_box(root, "Sleeve", Vector3(.13, .43, .16), Vector3(side * .30, .99, .015), "linen", Vector3(0, 0, side * .16))
		_sphere(root, "Hand", Vector3(.13, .15, .13), Vector3(side * .33, .74, .025), "skin")
	_box(root, "LinenShirt", Vector3(.46, .51, .26), Vector3(0, 1.0, 0), "linen")
	_box(root, "WovenBelt", Vector3(.48, .07, .28), Vector3(0, .82, 0), "red")
	_cylinder(root, "Neck", .075, .10, Vector3(0, 1.32, 0), "skin")
	_sphere(root, "Head", Vector3(.26, .34, .27), Vector3(0, 1.48, 0), "skin")
	_cylinder(root, "HatBrim", .23, .045, Vector3(0, 1.64, 0), "thatch")
	_cylinder(root, "StrawHat", .15, .09, Vector3(0, 1.69, 0), "thatch", .12)
	_box(root, "Nose", Vector3(.06, .08, .07), Vector3(0, 1.47, .15), "skin")
	if task not in ["rest", "", "resting"]:
		if task in ["woodcutting", "gatherWood", "gatherStone", "gather_wood", "gather_stone", "chop", "quarry"]:
			_box(root, "AxeHandle", Vector3(.055, .73, .055), Vector3(.39, .62, .12), "wood", Vector3(0, 0, -.18))
			_box(root, "AxeHead", Vector3(.27, .17, .075), Vector3(.43, .91, .12), "iron")
		elif task in ["build", "construction", "repair", "craft"]:
			_box(root, "HammerHandle", Vector3(.045, .40, .045), Vector3(.36, .74, .15), "wood")
			_box(root, "HammerHead", Vector3(.23, .10, .11), Vector3(.36, .94, .15), "iron")
		else:
			_cylinder(root, "Basket", .23, .30, Vector3(.35, .72, .26), "wicker", .27)
	return root

static func scenery(kind: String, winter: bool = false) -> Node3D:
	if kind in ["barn", "well"]:
		return building(kind, 1, 100, winter)
	var root := Node3D.new()
	root.name = kind.capitalize()
	if kind in ["fence", "wattleFence", "wattle_fence"]:
		for x in [-1.75, 0.0, 1.75]:
			_box(root, "FencePost", Vector3(.13, 1.05, .15), Vector3(x, .525, 0), "wood")
		for row in range(5):
			_box(root, "WovenWillow", Vector3(3.65, .075, .09), Vector3(0, .21 + row * .16, .025 if row % 2 == 0 else -.025), "wicker")
		if winter:
			_box(root, "Snow", Vector3(3.65, .06, .13), Vector3(0, .92, 0), "snow")
	else:
		_box(root, "Pallet", Vector3(1.7, .12, 1.65), Vector3(0, .06, 0), "wood")
		_barrel(root, Vector3(-.48, .12, -.32), .29, .72)
		_crate(root, Vector3(.37, .12, .35), Vector3(.72, .60, .64))
		_sphere(root, "Sack", Vector3(.55, .66, .5), Vector3(.40, .45, -.38), "linen")
		if winter:
			_box(root, "Snow", Vector3(.73, .05, .65), Vector3(.37, .745, .35), "snow")
	return root

static func _house(root: Node3D, level: int, winter: bool) -> void:
	var h := 2.25 + level * .10
	_body(root, Vector3(4.35, h, 3.65), Vector3(0, 0, -.15), "plaster")
	_gable(root, 4.95, 4.30, h + .22, 1.35, -.15, "shingle", winter)
	_door(root, Vector3(0, .22, 1.69), .80, 1.85)
	for x in [-1.47, 1.47]:
		_window(root, Vector3(x, 1.56, 1.70), 0)
	for x in [-2.19, 2.19]:
		_window(root, Vector3(x, 1.54, -.30), signf(x) * PI / 2)
	_window(root, Vector3(.9, 1.54, -2.0), PI)
	_window(root, Vector3(-.9, 1.54, -2.0), PI)
	_box(root, "VerandaFloor", Vector3(4.8, .15, .80), Vector3(0, .075, 2.15), "stone")
	for x in [-2.16, 0.0, 2.16]:
		_box(root, "CarvedVerandaPost", Vector3(.13, 2.08, .13), Vector3(x, 1.19, 2.46), "wood")
		_box(root, "PostCapital", Vector3(.25, .13, .24), Vector3(x, 2.19, 2.46), "wood")
	_box(root, "VerandaCanopy", Vector3(4.90, .13, 1.12), Vector3(0, 2.29, 2.18), "shingle", Vector3(.17, 0, 0))
	if winter:
		_box(root, "Snow", Vector3(4.90, .07, 1.12), Vector3(0, 2.39, 2.18), "snow", Vector3(.17, 0, 0))
	_chimney(root, Vector3(1.30, h + .85, -.8), .42, 1.55)
	for i in range(level):
		_box(root, "CarvedEave", Vector3(.13, .23, .18), Vector3(-1.75 + i * .86, h + .17, 1.74), "wood")
	if level >= 3:
		_box(root, "VerandaRail", Vector3(1.65, .09, .09), Vector3(-1.22, .90, 2.46), "wood")
		for x in [-1.84, -1.43, -1.02, -.61]:
			_box(root, "Baluster", Vector3(.055, .65, .055), Vector3(x, .52, 2.46), "wood")

static func _woodshed(root: Node3D, level: int, winter: bool) -> void:
	var h := 1.9 + level * .07
	_box(root, "StoneFooting", Vector3(3.35, .16, 2.75), Vector3(0, .08, 0), "stone")
	_posts(root, 2.95, 2.4, h)
	for i in range(10):
		_box(root, "RearBoard", Vector3(.27, h - .1, .08), Vector3(-1.36 + i * .30, h / 2 + .10, -1.24), "wood")
	_lean_roof(root, Vector3(3.65, .15, 3.05), Vector3(0, h + .15, 0), -.13, winter)
	for row in range(3 + level):
		for side in [-1, 1]:
			_cylinder(root, "CutLog", .095, 1.24, Vector3(side * .78, .30 + row * .18, -.69), "bark", .095, Vector3(0, 0, PI / 2))
	for x in [-1.46, 1.46]:
		_box(root, "DiagonalBrace", Vector3(.09, .7, .09), Vector3(x, h - .32, .90), "wood", Vector3(.67, 0, 0))

static func _cellar(root: Node3D, level: int, winter: bool) -> void:
	var h := 1.22 + level * .08
	_part(root, "EarthMound", _dome_mesh(Vector3(3.65, h, 3.3)), Vector3(0, 0, -.15), "earth")
	_box(root, "StoneEntrance", Vector3(2.1, 1.7, .50), Vector3(0, .85, 1.30), "stone")
	_door(root, Vector3(0, 0, 1.56), .95, 1.50)
	for i in range(level + 2):
		_box(root, "ArchStone", Vector3(.28, .25, .54), Vector3(-.85 + i * 1.7 / (level + 1), 1.65, 1.31), "stone")
	_box(root, "Hatch", Vector3(.64, .09, .65), Vector3(-.68, h * .92, -.40), "wood", Vector3(-.25, 0, .15))
	if winter:
		_part(root, "SnowCap", _dome_mesh(Vector3(3.68, h + .035, 3.33)), Vector3(0, .025, -.15), "snow")

static func _barn(root: Node3D, level: int, winter: bool) -> void:
	var h := 2.35 + .08 * level
	_body(root, Vector3(3.1, h, 2.85), Vector3.ZERO, "redwood")
	_gable(root, 3.66, 3.50, h + .22, 1.05, 0, "thatch", winter)
	for x in [-.53, .53]:
		_door(root, Vector3(x, .22, 1.44), .98, 1.92)
		_box(root, "DoorBrace", Vector3(.075, 1.87, .065), Vector3(x, 1.18, 1.53), "wood", Vector3(0, 0, .43 if x < 0 else -.43))
	_window(root, Vector3(0, h + .40, -1.45), PI, .54)
	for i in range(level + 1):
		_box(root, "SideRib", Vector3(.11, h, .12), Vector3(-1.60, h / 2 + .22, -1.1 + i * 2.2 / level), "wood")
	_sphere(root, "HayBale", Vector3(.73, .65, .78), Vector3(1.12, .325, 1.27), "thatch")

static func _well(root: Node3D, level: int, winter: bool) -> void:
	_cylinder(root, "StoneApron", .83, .10, Vector3(0, .05, 0), "stone")
	_cylinder(root, "StoneWell", .65, .76 + level * .035, Vector3(0, .48, 0), "stone")
	_cylinder(root, "DarkWater", .52, .018, Vector3(0, .90 + level * .018, 0), "water")
	for i in range(level + 1):
		_torus(root, "StoneCourse", .60, .68, Vector3(0, .26 + i * .11, 0), "stone")
	for x in [-.72, .72]:
		_box(root, "WellPost", Vector3(.13, 2.13, .13), Vector3(x, 1.065, 0), "wood")
	_cylinder(root, "Winch", .10, 1.55, Vector3(0, 1.56, 0), "wood", .10, Vector3(0, 0, PI / 2))
	_box(root, "Rope", Vector3(.025, .69, .025), Vector3(0, 1.2, .02), "wicker")
	_box(root, "Crank", Vector3(.055, .32, .055), Vector3(.83, 1.41, 0), "iron")
	_gable(root, 1.78, 1.60, 2.13 + .035 * level, .48, 0, "shingle", winter)
	_cylinder(root, "Bucket", .15, .27, Vector3(.48, .235, .57), "wood", .18)

static func _granary(root: Node3D, level: int, winter: bool) -> void:
	var h := 1.60 + level * .08
	_posts(root, 2.22, 2.03, .65)
	for x in [-1.11, 1.11]:
		for z in [-1.015, 1.015]:
			_cylinder(root, "MouseGuard", .23, .07, Vector3(x, .48, z), "stone")
	_box(root, "RaisedFloor", Vector3(2.7, .18, 2.5), Vector3(0, .64, -.12), "wood")
	_box(root, "GranaryWalls", Vector3(2.5, h, 2.27), Vector3(0, .73 + h / 2, -.12), "wood")
	_gable(root, 3.05, 2.90, h + .73, .83, -.12, "shingle", winter)
	_door(root, Vector3(0, .73, 1.035), .70, 1.38)
	for i in range(3):
		_box(root, "StoneStep", Vector3(.95, .22 * (3 - i), .24), Vector3(0, .11 * (3 - i), 1.3 + i * .23), "stone")
	for i in range(level + 2):
		_box(root, "Vent", Vector3(.20, .07, .035), Vector3(-.82 + i * .27, h + .40, 1.04), "darkwood")
	for x in [-1.27, 1.27]:
		_window(root, Vector3(x, 1.64, -.12), signf(x) * PI / 2, .45)
	_box(root, "RearCrossBeam", Vector3(2.4, .10, .10), Vector3(0, 1.05, -1.30), "darkwood")

static func _workshop(root: Node3D, level: int, winter: bool) -> void:
	var h := 2.02 + .07 * level
	_body(root, Vector3(2.60, h, 2.25), Vector3(0, 0, -.34), "plaster")
	_gable(root, 3.12, 2.85, h + .22, .91, -.34, "shingle", winter)
	_door(root, Vector3(-.60, .22, .80), .70, 1.70)
	_window(root, Vector3(.64, 1.50, .81), 0, .65)
	_window(root, Vector3(-1.32, 1.45, -.40), -PI / 2, .65)
	_box(root, "Workbench", Vector3(1.42, .14, .65), Vector3(.64, .96, 1.36), "wood")
	for x in [.05, 1.24]:
		_box(root, "BenchLeg", Vector3(.12, .90, .48), Vector3(x, .45, 1.36), "wood")
	for i in range(level):
		_box(root, "TimberStock", Vector3(.12, .14, 1.50), Vector3(-1.1 + i * .18, .10 + i * .10, -.9), "wood")
	_box(root, "SawBlade", Vector3(.65, .08, .04), Vector3(.53, 1.08, 1.30), "iron")
	_barrel(root, Vector3(-1.05, 0, 1.26), .26, .65)
	_box(root, "ToolRack", Vector3(1.20, .10, .12), Vector3(0, 1.55, -1.50), "wood")

static func _bakery(root: Node3D, level: int, winter: bool) -> void:
	var h := 1.95 + .08 * level
	_body(root, Vector3(2.30, h, 2.25), Vector3(-.40, 0, -.18), "plaster")
	_gable(root, 2.85, 2.95, h + .22, .85, -.18, "terracotta", winter, -.40)
	_door(root, Vector3(-.88, .22, .96), .67, 1.66)
	_window(root, Vector3(.02, 1.49, .97), 0, .55)
	_box(root, "OvenPlinth", Vector3(1.10, .64, 1.28), Vector3(1.16, .32, .15), "brick")
	_sphere(root, "BreadOven", Vector3(1.21, 1.15, 1.38), Vector3(1.12, .88, .15), "plaster")
	_box(root, "OvenMouth", Vector3(.58, .42, .06), Vector3(1.12, .79, .86), "darkwood")
	_chimney(root, Vector3(1.12, 1.87, -.12), .42, 2.25 + level * .06)
	_box(root, "BreadShelf", Vector3(1.58, .09, .50), Vector3(.0, .93, 1.36), "wood")
	for i in range(level + 1):
		_sphere(root, "Loaf", Vector3(.22, .15, .28), Vector3(-.60 + i * .23, 1.04, 1.35), "bread")
	if winter:
		_sphere(root, "SnowOnOven", Vector3(1.0, .12, .91), Vector3(1.12, 1.44, .15), "snow")

static func _smithy(root: Node3D, level: int, winter: bool) -> void:
	var h := 2.05 + .08 * level
	_box(root, "StoneFloor", Vector3(3.3, .12, 2.8), Vector3(0, .06, 0), "stone")
	_posts(root, 2.90, 2.40, h)
	_box(root, "RearWall", Vector3(3.0, 1.65, .23), Vector3(0, .945, -1.22), "stone")
	_lean_roof(root, Vector3(3.6, .17, 3.2), Vector3(0, h + .19, 0), -.15, winter)
	_box(root, "Forge", Vector3(1.05, .9, .90), Vector3(.85, .57, -.73), "brick")
	_box(root, "FireBed", Vector3(.65, .09, .57), Vector3(.85, 1.065, -.63), "ember")
	_chimney(root, Vector3(.85, 2.03, -.86), .55, 2.75 + level * .10)
	_cylinder(root, "AnvilStump", .29, .59, Vector3(-.60, .415, .62), "bark")
	_box(root, "AnvilFoot", Vector3(.44, .13, .31), Vector3(-.60, .77, .62), "iron")
	_box(root, "AnvilWaist", Vector3(.25, .19, .23), Vector3(-.60, .90, .62), "iron")
	_box(root, "AnvilFace", Vector3(.68, .13, .28), Vector3(-.59, 1.06, .62), "iron")
	_cylinder(root, "AnvilHorn", .10, .33, Vector3(-.10, 1.05, .62), "iron", .015, Vector3(0, 0, PI / 2))
	for i in range(level):
		_box(root, "IronStock", Vector3(.055, .045, 1.22), Vector3(-1.25 + i * .12, .20, -.50), "iron")
	_barrel(root, Vector3(1.05, .12, .78), .27, .62)

static func _stable(root: Node3D, level: int, winter: bool) -> void:
	var h := 2.02 + .09 * level
	_box(root, "StableFooting", Vector3(3.3, .17, 2.8), Vector3(0, .085, 0), "stone")
	_box(root, "RearWall", Vector3(3.0, h, .17), Vector3(0, h / 2 + .17, -1.21), "wood")
	for x in [-1.5, 1.5]:
		_box(root, "SideWall", Vector3(.16, h, 2.4), Vector3(x, h / 2 + .17, 0), "wood")
	_posts(root, 2.97, 2.4, h + .17)
	_gable(root, 3.64, 3.20, h + .17, .90, 0, "thatch", winter)
	for x in [-.76, .76]:
		_box(root, "StallGate", Vector3(1.24, .65, .09), Vector3(x, .73, 1.22), "wood")
		_box(root, "GateRail", Vector3(1.3, .07, .14), Vector3(x, 1.09, 1.23), "darkwood")
	_box(root, "StallDivider", Vector3(.13, 1.08, 2.4), Vector3(0, .71, 0), "wood")
	_box(root, "Trough", Vector3(2.10, .34, .40), Vector3(0, .34, 1.62), "wood")
	for i in range(level + 1):
		_box(root, "HayBundle", Vector3(.29, .20, .27), Vector3(-.82 + i * .30, .60, 1.62), "thatch")
	_window(root, Vector3(0, h - .16, -1.32), PI, .54)

static func _apiary(root: Node3D, level: int, winter: bool) -> void:
	_box(root, "GravelBed", Vector3(3.4, .07, 3.3), Vector3(0, .035, 0), "earth")
	for i in range(level + 1):
		var x := -.86 if i % 2 == 0 else .86
		var z := -1.05 + floori(i / 2.0) * 1.02
		_box(root, "HiveStand", Vector3(.80, .08, .72), Vector3(x, .38, z), "wood")
		for side in [-1, 1]:
			_box(root, "HiveLeg", Vector3(.07, .34, .49), Vector3(x + side * .29, .17, z), "wood")
		_box(root, "HiveBox", Vector3(.69, .69, .64), Vector3(x, .765, z), "hive")
		_box(root, "HiveEntrance", Vector3(.28, .045, .035), Vector3(x, .56, z + .335), "darkwood")
		_box(root, "LandingBoard", Vector3(.40, .05, .17), Vector3(x, .53, z + .39), "wood")
		_gable(root, .88, .84, 1.12, .26, z, "shingle", winter, x)
		_box(root, "HiveStrap", Vector3(.73, .045, .68), Vector3(x, .80, z), "wood")

static func _storehouse(root: Node3D, level: int, winter: bool) -> void:
	var h := 2.3 + .12 * level
	_body(root, Vector3(3.03, h, 2.83), Vector3.ZERO, "stone")
	_gable(root, 3.62, 3.42, h + .22, 1.02, 0, "shingle", winter)
	_door(root, Vector3(0, .22, 1.435), 1.15, 1.90)
	_box(root, "Lintel", Vector3(1.46, .21, .25), Vector3(0, 2.20, 1.47), "wood")
	_box(root, "Hoist", Vector3(.15, .18, .81), Vector3(0, h + .45, 1.38), "wood")
	_box(root, "HoistRope", Vector3(.026, .70, .026), Vector3(0, h + .10, 1.73), "wicker")
	for x in [-1.54, 1.54]:
		_window(root, Vector3(x, 1.76, -.32), signf(x) * PI / 2, .48)
	for i in range(level):
		_box(root, "RearButtress", Vector3(.20, 1.13 + level * .12, .27), Vector3(-1.22 + i * .59, .565 + level * .06, -1.50), "stone")
	_barrel(root, Vector3(-1.11, 0, 1.43), .25, .73)
	_crate(root, Vector3(1.05, 0, 1.37), Vector3(.60, .58, .60))

static func _construction(root: Node3D, id: String, level: int, progress: float, winter: bool) -> void:
	var size := Vector3(4.65, .22, 4.25) if id == "house" else Vector3(3.15, .22, 2.95)
	if id == "well":
		size = Vector3(1.55, .22, 1.45)
	_box(root, "Foundation", size, Vector3(0, .11, 0), "stone")
	if winter:
		_box(root, "FoundationSnow", Vector3(size.x - .10, .05, size.z - .10), Vector3(0, .245, 0), "snow")
	if progress <= 0:
		return
	var h := .65 + progress * (1.25 + level * .07)
	if id == "apiary":
		h = .35 + progress * .50
	elif id == "cellar":
		h = .45 + progress * .65
	elif id == "woodshed":
		h = .55 + progress * (1.05 + level * .05)
	for x in [-size.x / 2 + .14, size.x / 2 - .14]:
		for z in [-size.z / 2 + .14, size.z / 2 - .14]:
			_box(root, "RisingPost", Vector3(.13, h, .13), Vector3(x, .22 + h / 2, z), "wood")
	_box(root, "IncompleteWall", Vector3(size.x - .30, h * .52, .16), Vector3(0, .22 + h * .26, -size.z / 2 + .14), "wood")
	for i in range(3):
		_box(root, "StackedBoards", Vector3(size.x * .42, .08, .20), Vector3(.10, .27 + i * .09, .30 + i * .21), "wood")
	if progress >= .65:
		_box(root, "RoofRidgeFrame", Vector3(.11, .12, size.z - .25), Vector3(0, h + .48, 0), "wood")
		for x in [-1, 1]:
			_box(root, "BareRafter", Vector3(size.x * .52, .10, .10), Vector3(x * size.x * .23, h + .15, -.7), "wood", Vector3(0, 0, x * -.35))

static func _wear(root: Node3D, id: String, condition: float) -> void:
	var z := 1.75 if id == "house" else 1.3
	for i in range(1 + int((75 - clampf(condition, 0, 75)) / 25)):
		_box(root, "WornTimber", Vector3(.08, .42 + i * .12, .035), Vector3(-.45 + i * .27, .68 + i * .10, z), "darkwood", Vector3(0, 0, -.3 + i * .16))
	_box(root, "LooseBoard", Vector3(.15, .06, .75), Vector3(.45, .06, z + .12), "wood", Vector3(0, .4, 0))

static func _body(root: Node3D, size: Vector3, offset: Vector3, material: String) -> void:
	_box(root, "StoneFoundation", Vector3(size.x + .16, .22, size.z + .16), offset + Vector3(0, .11, 0), "stone")
	_box(root, "Walls", size, offset + Vector3(0, .22 + size.y / 2, 0), material)
	for x in [-1, 1]:
		for z in [-1, 1]:
			_box(root, "CornerTimber", Vector3(.13, size.y, .13), offset + Vector3(x * (size.x / 2 + .015), .22 + size.y / 2, z * (size.z / 2 + .015)), "wood")
	_box(root, "RearSill", Vector3(size.x + .12, .10, .12), offset + Vector3(0, .39, -size.z / 2 - .04), "wood")

static func _posts(root: Node3D, width: float, depth: float, height: float) -> void:
	for x in [-width / 2, width / 2]:
		for z in [-depth / 2, depth / 2]:
			_box(root, "TimberPost", Vector3(.15, height, .15), Vector3(x, height / 2, z), "wood")
	_box(root, "FrontBeam", Vector3(width + .15, .17, .15), Vector3(0, height - .10, depth / 2), "wood")

static func _door(root: Node3D, bottom: Vector3, width: float, height: float) -> void:
	_box(root, "DoorRecess", Vector3(width + .13, height + .08, .07), bottom + Vector3(0, height / 2 + .04, 0), "darkwood")
	_box(root, "PlankDoor", Vector3(width, height, .065), bottom + Vector3(0, height / 2, .04), "wood")
	for y in [height * .20, height * .78]:
		_box(root, "IronDoorStrap", Vector3(width * .91, .045, .03), bottom + Vector3(0, y, .085), "iron")
	_box(root, "DoorHandle", Vector3(.055, .11, .045), bottom + Vector3(width * .31, height * .49, .11), "iron")

static func _window(root: Node3D, position: Vector3, turn: float, width: float = .72) -> void:
	var frame := Node3D.new()
	frame.position = position
	frame.rotation.y = turn
	root.add_child(frame)
	_box(frame, "WindowFrame", Vector3(width + .11, .79, .10), Vector3.ZERO, "wood")
	_box(frame, "DarkGlass", Vector3(width - .07, .62, .025), Vector3(0, 0, .061), "glass")
	_box(frame, "Mullion", Vector3(.045, .65, .045), Vector3(0, 0, .085), "wood")
	_box(frame, "Crossbar", Vector3(width - .06, .045, .045), Vector3(0, .02, .085), "wood")
	for side in [-1, 1]:
		_box(frame, "Shutter", Vector3(width * .36, .76, .07), Vector3(side * width * .76, 0, 0), "greenwood")

static func _gable(root: Node3D, width: float, depth: float, y: float, rise: float, z: float, material: String, winter: bool, x: float = 0) -> void:
	var slope := atan2(rise, width / 2)
	var length := sqrt(rise * rise + width * width / 4)
	for side in [-1, 1]:
		var angle: float = -side * slope
		_box(root, "Roof", Vector3(length, .13, depth), Vector3(x + side * width / 4, y + rise / 2, z), material, Vector3(0, 0, angle))
		if winter:
			_box(root, "RoofSnow", Vector3(length, .07, depth), Vector3(x + side * width / 4, y + rise / 2 + .09, z), "snow", Vector3(0, 0, angle))
	for end in [-1, 1]:
		_part(root, "GableEnd", _triangle_mesh(width - .20, rise - .07), Vector3(x, y, z + end * (depth / 2 - .18)), "wood")
	_box(root, "RidgeCap", Vector3(.17, .16, depth + .03), Vector3(x, y + rise + .03, z), material)

static func _lean_roof(root: Node3D, size: Vector3, position: Vector3, angle: float, winter: bool) -> void:
	_box(root, "LeanRoof", size, position, "shingle", Vector3(angle, 0, 0))
	if winter:
		_box(root, "RoofSnow", Vector3(size.x, .07, size.z), position + Vector3(0, .12, 0), "snow", Vector3(angle, 0, 0))

static func _chimney(root: Node3D, centre: Vector3, width: float, height: float) -> void:
	_box(root, "BrickChimney", Vector3(width, height, width), centre, "brick")
	_box(root, "ChimneyCrown", Vector3(width + .14, .13, width + .14), centre + Vector3(0, height / 2, 0), "stone")
	_box(root, "ChimneyOpening", Vector3(width * .60, .015, width * .60), centre + Vector3(0, height / 2 + .07, 0), "darkwood")

static func _barrel(root: Node3D, bottom: Vector3, radius: float, height: float) -> void:
	_cylinder(root, "Barrel", radius, height, bottom + Vector3(0, height / 2, 0), "wood", radius * .89)
	for y in [.16, .78]:
		_torus(root, "BarrelHoop", radius * .94, radius * 1.04, bottom + Vector3(0, height * y, 0), "iron")

static func _crate(root: Node3D, bottom: Vector3, size: Vector3) -> void:
	_box(root, "Crate", size, bottom + Vector3(0, size.y / 2, 0), "wood")
	for side in [-1, 1]:
		_box(root, "CrateStrap", Vector3(.07, size.y + .03, size.z + .03), bottom + Vector3(side * size.x * .35, size.y / 2, 0), "darkwood")

static func _box(root: Node3D, label: String, size: Vector3, position: Vector3, material: String, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var key := "box:%s" % size
	if not _meshes.has(key):
		var mesh := BoxMesh.new()
		mesh.size = size
		_meshes[key] = mesh
	return _part(root, label, _meshes[key], position, material, rotation)

static func _cylinder(root: Node3D, label: String, radius: float, height: float, position: Vector3, material: String, top: float = -1, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	if top < 0:
		top = radius
	var key := "cylinder:%.4f:%.4f:%.4f" % [radius, height, top]
	if not _meshes.has(key):
		var mesh := CylinderMesh.new()
		mesh.bottom_radius = radius
		mesh.top_radius = top
		mesh.height = height
		mesh.radial_segments = 12
		_meshes[key] = mesh
	return _part(root, label, _meshes[key], position, material, rotation)

static func _sphere(root: Node3D, label: String, size: Vector3, position: Vector3, material: String) -> MeshInstance3D:
	if not _meshes.has("sphere"):
		var mesh := SphereMesh.new()
		mesh.radius = .5
		mesh.height = 1.0
		mesh.radial_segments = 16
		mesh.rings = 8
		_meshes["sphere"] = mesh
	var part := _part(root, label, _meshes["sphere"], position, material)
	part.scale = size
	return part

static func _torus(root: Node3D, label: String, inner: float, outer: float, position: Vector3, material: String) -> void:
	var key := "torus:%.4f:%.4f" % [inner, outer]
	if not _meshes.has(key):
		var mesh := TorusMesh.new()
		mesh.inner_radius = inner
		mesh.outer_radius = outer
		mesh.rings = 16
		mesh.ring_segments = 6
		_meshes[key] = mesh
	_part(root, label, _meshes[key], position, material)

static func _part(root: Node3D, label: String, mesh: Mesh, position: Vector3, material: String, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh
	part.position = position
	part.rotation = rotation
	part.material_override = _material(material)
	root.add_child(part)
	return part

static func _triangle_mesh(width: float, height: float) -> ArrayMesh:
	var key := "triangle:%.4f:%.4f" % [width, height]
	if not _meshes.has(key):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for v in [Vector3(-width / 2, 0, 0), Vector3(0, height, 0), Vector3(width / 2, 0, 0)]:
			surface.set_uv(Vector2(v.x + width / 2, v.y))
			surface.add_vertex(v)
		surface.generate_normals()
		_meshes[key] = surface.commit()
	return _meshes[key]

static func _dome_mesh(size: Vector3) -> ArrayMesh:
	var key := "dome:%s" % size
	if not _meshes.has(key):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for ring in range(6):
			for segment in range(20):
				for corner in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 1), Vector2i(1, 0)]:
					var angle: float = (segment + corner.x) * TAU / 20
					var elevation: float = (ring + corner.y) * PI / 12
					var p := Vector3(cos(angle) * cos(elevation) * size.x / 2, sin(elevation) * size.y, sin(angle) * cos(elevation) * size.z / 2)
					surface.set_uv(Vector2(p.x, p.z))
					surface.add_vertex(p)
		surface.generate_normals()
		_meshes[key] = surface.commit()
	return _meshes[key]

static func _material(kind: String) -> StandardMaterial3D:
	if _materials.has(kind):
		return _materials[kind]
	var colors := {
		"wood": Color("785336"), "darkwood": Color("332b23"), "redwood": Color("80503a"), "greenwood": Color("52654a"),
		"hive": Color("c3aa68"), "plaster": Color("ded2af"), "stone": Color("8d8976"), "brick": Color("98704d"),
		"shingle": Color("625344"), "terracotta": Color("9d6348"), "thatch": Color("ac8d50"), "earth": Color("65704a"),
		"bark": Color("5c4630"), "iron": Color("474a45"), "linen": Color("cfc6a8"), "red": Color("8b4e3b"),
		"trousers": Color("5d5543"), "leather": Color("433a2e"), "skin": Color("c49a77"), "wicker": Color("9b7b46"),
		"bread": Color("be914a"), "snow": Color("e3e7de"), "water": Color("334a49"), "glass": Color("5e7162"), "ember": Color("aa5126")
	}
	var base: Color = colors.get(kind, Color("95856b"))
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in range(64):
		for x in range(64):
			var noise := float(posmod(x * 197 + y * 73 + x * y * 13, 101)) / 100 - .5
			var value := noise * .10
			if kind in ["wood", "darkwood", "redwood", "greenwood", "hive", "bark"]:
				value += sin(y * 1.9 + sin(x * .14) * 2.2) * .07
				if y % 16 == 0:
					value -= .16
			elif kind in ["stone", "brick"]:
				if y % 16 <= 1 or (x + (16 if (y / 16) % 2 else 0)) % 32 <= 1:
					value -= .19
			elif kind in ["shingle", "terracotta"]:
				if y % 12 <= 1 or (x + (8 if (y / 12) % 2 else 0)) % 16 == 0:
					value -= .17
				value += sin(x * 2.3) * .035
			elif kind in ["thatch", "wicker"]:
				value += sin(x * 2.8 + sin(y * .10)) * .09
			image.set_pixel(x, y, Color(clampf(base.r + value, 0, 1), clampf(base.g + value, 0, 1), clampf(base.b + value, 0, 1)))
	image.generate_mipmaps()
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.roughness = .96
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.uv1_triplanar = true
	material.uv1_scale = Vector3(1.6, 1.6, 1.6)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[kind] = material
	return material
