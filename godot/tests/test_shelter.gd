extends SceneTree
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func _initialize() -> void:
	var person = Human.new()
	var farm = Farm.new()
	if not person.has_method("build_shelter"):
		check(false, "Camp offers timed shelter construction with a wood reservation")
		quit(1)
		return
	person.home = Vector2.ZERO
	person.position = person.home
	farm.heating_enabled = false
	farm.wood = 350000
	person.order(farm, [Vector2i(8,8)], 0, "Plow")
	check(person.build_shelter(farm) and farm.wood == 50000 and not person.build_shelter(farm), "Construction reserves 300kg once and preserves field orders")
	person.advance(farm, 0, 6, 3)
	check(not farm.shelter and is_equal_approx(person.build_remaining, 5) and person.queue.size() == 1, "Building takes work before completing and leaves field queue intact")
	person.sleep(2)
	person.advance(farm, 0, 9, 2)
	check(is_equal_approx(person.build_remaining, 5), "Sleep interrupts construction without losing its progress")
	person.cancel(farm)
	check(farm.wood == 350000 and person.build_remaining == 0 and person.build_reserved == 0, "Cancelling construction returns its wood exactly once")
	person.cancel(farm)
	check(farm.wood == 350000, "Repeated cancellation cannot duplicate refunded logs")
	person.fatigue = 0
	person.build_shelter(farm)
	person.advance(farm, 0, 11, 8)
	check(farm.shelter and person.build_reserved == 0 and not person.build_shelter(farm), "Eight comfortable work hours finish the one shelter")
	person.fatigue = 100
	person.sleep(6)
	person.advance(farm, 0, 19, 6)
	check(person.fatigue < 0.001, "Comfortable shelter sleep clears full fatigue in six hours")
	person = Human.new()
	farm = Farm.new()
	person.position = person.home
	farm.wood = 500
	person.advance(farm, 0, 6, 2)
	check(farm.wood == 0 and not farm.fire_lit and farm.fuel_remainder < 0.00001, "Heating burns exactly 500g then extinguishes after one hour")
	farm.wood = 1000
	person.position += Vector2(1,0)
	person.advance(farm, 0, 8, 2)
	check(farm.wood == 1000 and not farm.fire_lit, "Being away from camp consumes no heating wood")
	person.position = person.home
	var grain: int = farm.stock.Barley
	check(person.eat(farm, "Barley", 300) and person.meal_fuel == 250 and farm.wood == 750 and farm.stock.Barley == grain - 300, "A half-hour meal atomically reserves grain and 250g fuel")
	person.advance(farm, 0, 10, 0.25)
	check(person.meal_fuel == 125 and farm.wood == 750, "Cooking and heating share one fire, not two fuel charges")
	person.cancel_meal(farm)
	check(farm.wood == 875 and farm.stock.Barley == grain and not person.eating_requested, "Cancelled cooking refunds only unburned fuel and uneaten grain")
	farm.wood = 249
	check(not person.eat(farm, "Barley", 300) and farm.stock.Barley == grain and farm.wood == 249, "Fuel shortage refuses meals without spending either ingredient")
	farm.wood = 1000
	farm.heating_enabled = false
	person.eat(farm, "Barley", 300)
	person.advance(farm, 0, 10.25, 0.5)
	check(farm.wood == 750 and person.stomach > 0 and person.meal_fuel == 0, "Cooking lights its fire even when heating is disabled")
	person=Human.new();person.position=person.home
	farm=Farm.new();farm.heating_enabled=false;farm.wood=10
	for i in 6:
		person.eat(farm,"Millet",1)
		person.advance(farm,0,12+i/600.0,1.0/600.0)
	check(farm.wood==5 and absf(farm.fuel_remainder)<0.00001, "Six one-gram meals burn exactly five grams despite fractional per-meal fuel")
	var terrain=load("res://terrain.gd").new(42)
	person=Human.new();person.terrain=terrain
	farm=Farm.new();person.position=person.home
	var grain_before: int=farm.stock.Barley
	var wood_before: int=farm.wood
	person.eat(farm,"Barley",300)
	person.position=terrain.ponds[0].center/person.terrain_scale
	person.advance(farm,0,6,0.1)
	check(farm.wood==wood_before and farm.stock.Barley==grain_before and not person.eating_requested, "An unreachable camp refunds the meal's grain and reserved cooking fuel once")
	if failures.is_empty(): print("PASS: shelter reservation/progress/refunds, interrupted work, comfortable sleep, shared fuel and cooking")
	quit(0 if failures.is_empty() else 1)
