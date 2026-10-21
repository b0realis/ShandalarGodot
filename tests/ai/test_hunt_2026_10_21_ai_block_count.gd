extends GameTest
## THE GANG THE RULES FORBID (bug hunt 2026-10-21, ai).
##
## The combat model ([CombatSearch], read by [AiCombatStudy]) drew its gang
## blocks from per-pair legality alone; it had no field for an attacker's
## "can't be blocked by more than one creature" (Stalking Tiger, Charging
## Rhino: [member CardInstance.cur_max_blockers]), "can't be blocked except
## by two or more" ([member CardInstance.cur_min_blockers]) or the table's
## cap (Caverns of Despair, [member MtgGame.max_blockers]). Against a
## Stalking Tiger the Wizard's study planned both of its Grizzly Bears —
## the Tiger dies, one Bear dies — and the declaration's repair
## ([method CombatDeclaration.repair_blocks]) trimmed the second Bear: one
## Bear chump-blocked a 3/3 at 20 life, the block the plan priced worst.
##
## Each attacker carries its block-count bounds in the model now
## ([method CombatSearch.gang_bounds]), and no gang outside them is drawn.

func before_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, id == "pack-6")


func after_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func after_each() -> void:
	g = null


## Our two Grizzly Bears; their [param attacker_name] attacks; the
## Wizard's blocks.
func _blocks_against(attacker_name: String) -> Dictionary:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Grizzly Bears")
	var attacker := put_battlefield(1, attacker_name)
	var guard := 0
	while not (g.active_player == 1 and g.awaiting_attackers) and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.declare_attackers(1, [attacker.id]))
	guard = 0
	while not g.awaiting_blockers and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	ai.act(g)
	assert_false(g.awaiting_blockers, "the blocks were declared")
	return g.combat.blocks


func test_no_lone_chump_on_a_stalking_tiger() -> void:
	assert_true(_blocks_against("Stalking Tiger").is_empty(),
		"one Bear would die for nothing; two may not block it")


## THE CONTROL: a Hill Giant may meet both Bears, and does.
func test_a_hill_giant_still_meets_the_gang() -> void:
	assert_eq(_blocks_against("Hill Giant").size(), 2, "two Bears kill the Giant")


func test_the_bounds_shape_the_gangs() -> void:
	var model := CombatSearch.new()
	var legal: Array[int] = [0, 1, 2]
	assert_eq(model._gangs_of(legal).size(), 3 + 3 + 1, "singles, pairs, the trio")
	assert_eq(model._gangs_of(legal, Vector2i(0, 1)).size(), 3, "no more than one: singles alone")
	assert_eq(model._gangs_of(legal, Vector2i(2, 0)).size(), 3 + 1, "two or more: no single")
	assert_eq(model._gangs_of(legal, Vector2i(2, 2)).size(), 3, "exactly two")
	assert_eq(model.gang_bounds(0, true), Vector2i.ZERO, "a hand-built model bounds nothing")
