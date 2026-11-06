extends GameTest
## THE URZA BLOCK'S COMBAT LIABILITIES, READ BY THE FAIR AI (Pack 10;
## [member AiProfile.forecasts_tactics]; engine/ai/urza_tactics.gd
## `price_attackers` / `price_blocks`, asked by the Mirage module's combat
## repairs).
##  * Goblin Cadets — "Whenever this creature blocks or becomes blocked,
##    target opponent gains control of it": it does not attack into a
##    board that can block it, and does not block, unless the swing is
##    lethal either way.
##  * Phyrexian Negator — "Whenever this creature is dealt damage,
##    sacrifice that many permanents": it does not block a creature with
##    power, nor attack into one, unless the swing is lethal.
## Read off the creature's own trigger text, never its name; each with its
## null arm (gate off: the pilot as before Pack 10).

const UT := preload("res://engine/ai/urza_tactics.gd")


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(on := true, seat := 0) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(seat, p)
	g.set_agent(seat, ai)
	return ai


## Seat 0's declare-attackers decision, by the pilot.
func _our_attack(ai: AiPlayer) -> Array:
	var guard := 0
	while not (g.active_player == 0 and g.awaiting_attackers) and guard < 400:
		_advance_once()
		guard += 1
	ai.act(g)
	return g.combat.attackers.keys()


## Seat 1 attacks with [param ids]; seat 0's pilot declares its blocks.
func _their_attack_blocked_by(ai: AiPlayer, ids: Array) -> Dictionary:
	var guard := 0
	while not (g.active_player == 1 and g.awaiting_attackers) and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.declare_attackers(1, ids))
	guard = 0
	while not g.awaiting_blockers and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	ai.act(g)
	return g.combat.blocks.duplicate()


func test_the_shapes_are_read_off_the_trigger_text() -> void:
	assert_true(UT.defects_in_combat(put_battlefield(0, "Goblin Cadets")))
	assert_true(UT.damage_costs_permanents(put_battlefield(0, "Phyrexian Negator")))
	assert_false(UT.defects_in_combat(put_battlefield(0, "Grizzly Bears")))


# --------------------------------------------------------------- Goblin Cadets --

func test_goblin_cadets_do_not_attack_into_a_blocker() -> void:
	var ai := _ai()
	var cadets := put_battlefield(0, "Goblin Cadets")
	put_battlefield(1, "Llanowar Elves")
	assert_false(_our_attack(ai).has(cadets.id), "a block hands it to them")


func test_goblin_cadets_attack_an_empty_board() -> void:
	var ai := _ai()
	var cadets := put_battlefield(0, "Goblin Cadets")
	assert_true(_our_attack(ai).has(cadets.id))


func test_goblin_cadets_do_not_block() -> void:
	var ai := _ai()
	var cadets := put_battlefield(0, "Goblin Cadets")
	var elves := put_battlefield(1, "Llanowar Elves")
	var blocks := _their_attack_blocked_by(ai, [elves.id])
	assert_false(blocks.has(cadets.id))


func test_the_null_arm_lets_the_cadets_attack() -> void:
	var ai := _ai(false)
	var cadets := put_battlefield(0, "Goblin Cadets")
	put_battlefield(1, "Llanowar Elves")
	assert_eq(UT.price_attackers(g, ai, [cadets.id], 1), [cadets.id])


# ----------------------------------------------------------- Phyrexian Negator --

func test_phyrexian_negator_does_not_block_a_giant() -> void:
	var ai := _ai()
	var negator := put_battlefield(0, "Phyrexian Negator")
	for i in 3: put_battlefield(0, "Swamp")
	var giant := put_battlefield(1, "Hill Giant")
	var blocks := _their_attack_blocked_by(ai, [giant.id])
	assert_false(blocks.has(negator.id), "three permanents for a Hill Giant")


func test_phyrexian_negator_blocks_when_the_hit_is_lethal() -> void:
	var ai := _ai()
	var negator := put_battlefield(0, "Phyrexian Negator")
	var giant := put_battlefield(1, "Hill Giant")
	g.players[0].life = 3
	var blocks := _their_attack_blocked_by(ai, [giant.id])
	assert_true(blocks.has(negator.id), "three permanents are cheaper than the game")


func test_the_null_arm_keeps_the_negators_block() -> void:
	var ai := _ai(false)
	var negator := put_battlefield(0, "Phyrexian Negator")
	var giant := put_battlefield(1, "Hill Giant")
	var map := {negator.id: giant.id}
	assert_eq(UT.price_blocks(g, ai, map), map)
