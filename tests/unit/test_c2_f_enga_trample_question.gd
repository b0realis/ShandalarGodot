extends GameTest
## A TRAMPLER THAT CANNOT REACH LETHAL IS NOT A QUESTION (campaign
## 2026-10-12, b6-6).
##
## A blocked trampler's division is a choice only when there is something
## to divide: CR 702.19b lets damage trample over only once every blocker
## has been assigned lethal damage, so a War Mammoth (3) blocked by a Wall
## of Stone (0/8) has exactly one legal assignment — all three on the
## Wall. MtgGame._request_is_a_choice treated every blocked trampler as a
## question, and the player who wants to divide their own damage (the
## human) was put into the damage loop to click the Wall three times.
##
## The rule now: one blocker and trample is a question only when the damage
## is MORE than the blocker's lethal remaining (counting damage already
## marked and what this step has already put on it); two or more blockers
## always are.

const PRESETS := ["modern_mana_burn", "fifth"]


## A seat that wants to be asked — what HumanAgent does.
class PromptAgent extends DecisionAgent:
	func wants_to_assign_combat_damage() -> bool:
		return true


func _fresh(preset: String) -> void:
	super.before_each()
	g.rules.set_preset(preset)
	g.agents[0] = PromptAgent.new()


## P0's [param attacker] attacks; P1 blocks with [param blockers]; the
## game is taken to the combat damage step.
func _block(attacker: String, blockers: Array) -> Array:
	var a := put_battlefield(0, attacker)
	var bodies: Array = []
	var map := {}
	for name in blockers:
		var b := put_battlefield(1, name)
		bodies.append(b)
		map[b.id] = a.id
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [a.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, map))
	return [a] + bodies


func _to_damage() -> void:
	var guard := 0
	while g.current_step() != Mtg.Step.COMBAT_DAMAGE and not g.awaiting_damage_assignment \
			and guard < 50:
		_advance_once()
		guard += 1


func test_three_trample_into_a_wall_of_stone_is_not_asked() -> void:
	for preset in PRESETS:
		_fresh(preset)
		var cast := _block("War Mammoth", ["Wall of Stone"])
		_to_damage()
		assert_false(g.awaiting_damage_assignment,
			"%s: 3 into an 0/8 has one legal division" % preset)
		advance_to_step(Mtg.Step.COMBAT_END)
		assert_eq(cast[1].damage, 3, "%s: all three on the Wall" % preset)
		assert_eq(g.players[1].life, 20, "%s: nothing tramples over" % preset)


func test_exactly_lethal_is_not_asked_either() -> void:
	for preset in PRESETS:
		_fresh(preset)
		var cast := _block("War Mammoth", ["Hill Giant"])   # 3 into a 3/3
		_to_damage()
		assert_false(g.awaiting_damage_assignment,
			"%s: exactly lethal leaves nothing to trample" % preset)
		advance_to_step(Mtg.Step.COMBAT_END)
		assert_eq(cast[1].zone, Mtg.Zone.GRAVEYARD, "%s: the Giant dies" % preset)
		assert_eq(g.players[1].life, 20, "%s" % preset)


func test_more_than_lethal_is_still_asked() -> void:
	for preset in PRESETS:
		_fresh(preset)
		var cast := _block("War Mammoth", ["Grizzly Bears"])   # 3 into a 2/2
		_to_damage()
		assert_true(g.awaiting_damage_assignment,
			"%s: trample over or not is a choice" % preset)
		assert_ok(g.assign_combat_damage(0,
			{cast[1].id: 2, MtgGame.DAMAGE_TO_PLAYER: 1}))
		assert_eq(g.players[1].life, 19, "%s" % preset)


# "Lethal" is what is still needed: damage already marked on the Wall
# counts, so six on an 0/8 leaves 2 — and three is then more than that.
func test_lethal_counts_damage_already_marked() -> void:
	for preset in PRESETS:
		_fresh(preset)
		var cast := _block("War Mammoth", ["Wall of Stone"])
		cast[1].damage = 6
		_to_damage()
		assert_true(g.awaiting_damage_assignment,
			"%s: 2 lethal remaining, 3 to assign" % preset)
		assert_ok(g.assign_combat_damage(0,
			{cast[1].id: 2, MtgGame.DAMAGE_TO_PLAYER: 1}))
		assert_eq(g.players[1].life, 19, "%s" % preset)


# Two blockers are a division whatever the numbers: which of them takes
# the points is the attacker's call.
func test_two_blockers_are_still_asked() -> void:
	for preset in PRESETS:
		_fresh(preset)
		_block("War Mammoth", ["Wall of Stone", "Wall of Stone"])
		_to_damage()
		assert_true(g.awaiting_damage_assignment, "%s: two walls, a real division" % preset)


# A seat that does not want to be asked is unchanged: the AI's split runs.
func test_a_seat_that_is_not_asked_still_assigns() -> void:
	super.before_each()
	var cast := _block("War Mammoth", ["Wall of Stone"])
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_false(g.awaiting_damage_assignment)
	assert_eq(cast[1].damage, 3)
