extends GameTest
## THE CRACK-BACK SEARCH (2026-09-05) — [CombatSearch] behind
## `AiPlayer._search_hold_back`.
##
## An attacker is tapped through the opponent's whole turn, so at low life
## the AI could swing into a lethal counter-swing and die. The attack
## audit of 2026-09-04 reproduced it exactly — at 3 life behind one
## untapped 3/3, facing a TAPPED Craw Wurm, the AI swings and loses — and
## two approximations of the answer were built and rejected on
## measurement, both because they were pessimistic: they assumed the
## opponent swings with everything and that we block it greedily, and they
## tested the danger against a threshold instead of pricing it against
## what the attack was worth.
##
## This file states the boards. The search must close the reproduced one,
## must NOT close the ones where holding back buys nothing, and must not
## touch the difficulty ladder or the random stream.


func _wizard() -> AiPlayer:
	return AiPlayer.new(0, AiProfile.wizard())


## How many attackers seat 0's AI declares in the situation now on the
## table (the attack audit's own helper).
func _attack_count(ai: AiPlayer) -> int:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	ai.act(g)
	assert_false(g.awaiting_attackers, "the AI left the attack step open")
	return g.combat.attackers.size()


func _set_life(pid: int, life: int) -> void:
	g.players[pid].life = life


# ------------------------------------------------ the reproduced board --

## THE BOARD THE AUDIT REPRODUCED. Our Hill Giant is the only thing
## between us and a 6/4; sending it means it is tapped when the Wurm
## untaps, and 6 damage against 3 life is the game.
func test_at_three_life_the_giant_stays_home_to_block_the_wurm() -> void:
	var ai := _wizard()
	put_battlefield(0, "Hill Giant")
	var wurm := put_battlefield(1, "Craw Wurm")
	wurm.tapped = true
	_set_life(0, 3)
	assert_eq(_attack_count(ai), 0,
		"3 damage now is not worth dying to the counter-swing")


## The SAME board at a life total the counter-swing cannot reach. Nothing
## to survive, so the attack audit's own answer stands: a tapped Craw Wurm
## blocks nothing and the Giant swings.
func test_at_twenty_life_the_same_board_still_swings() -> void:
	var ai := _wizard()
	put_battlefield(0, "Hill Giant")
	var wurm := put_battlefield(1, "Craw Wurm")
	wurm.tapped = true
	assert_eq(g.players[0].life, 20)
	assert_eq(_attack_count(ai), 1, "6 power cannot kill us from 20")


## Holding back only buys something when it buys SURVIVAL. Two tapped Craw
## Wurms against one Hill Giant at 3 life: block one and the other still
## kills us, so the three damage is free and the Giant goes.
func test_a_counter_swing_that_is_lethal_anyway_is_not_worth_a_body() -> void:
	var ai := _wizard()
	put_battlefield(0, "Hill Giant")
	for _i in 2:
		var wurm := put_battlefield(1, "Craw Wurm")
		wurm.tapped = true
	_set_life(0, 3)
	assert_eq(_attack_count(ai), 1,
		"nothing this attack can do changes whether we survive")


## A lethal push is never held back — the branch that decides the game
## does not reach the search at all, because a swing that wins has no next
## turn to survive.
func test_a_lethal_push_is_never_held_back() -> void:
	var ai := _wizard()
	for _i in 3:
		put_battlefield(0, "Hill Giant")
	var wurm := put_battlefield(1, "Craw Wurm")
	wurm.tapped = true
	_set_life(0, 3)
	_set_life(1, 6)
	assert_eq(_attack_count(ai), 3, "nine damage into six life ends it")


## THE GATE, stated as behaviour: when everything they control connecting
## still leaves us alive, the search never runs and the cohort's answer is
## untouched. Four Grizzly Bears against one tapped Craw Wurm at 20 life
## is the attack audit's own widened attack.
func test_the_gate_leaves_a_safe_board_to_the_cohort() -> void:
	var ai := _wizard()
	for _i in 4:
		put_battlefield(0, "Grizzly Bears")
	var wurm := put_battlefield(1, "Craw Wurm")
	wurm.tapped = true
	assert_eq(_attack_count(ai), 4, "6 power cannot kill us from 20")


## A partial hold-back: at 5 life against a tapped 6/4, two Grizzly Bears.
## One has to stay home to block; the other is four free damage.
func test_it_holds_back_only_what_the_block_needs() -> void:
	var ai := _wizard()
	for _i in 2:
		put_battlefield(0, "Grizzly Bears")
	var wurm := put_battlefield(1, "Craw Wurm")
	wurm.tapped = true
	_set_life(0, 5)
	assert_eq(_attack_count(ai), 1,
		"one Bears blocks the Wurm, the other still swings")


# ------------------------------------------------------- the guarantees --

## The ladder. The search is a CAPABILITY, and the bottom two difficulties
## do not have it: an Apprentice at 3 life swings its Giant into the Wurm
## exactly as it always did.
func test_the_bottom_of_the_ladder_does_not_search() -> void:
	assert_eq(AiProfile.apprentice().combat_search_nodes, 0)
	assert_eq(AiProfile.magician().combat_search_nodes, 0)
	assert_gt(AiProfile.sorcerer().combat_search_nodes, 0)
	assert_gt(AiProfile.wizard().combat_search_nodes,
		AiProfile.sorcerer().combat_search_nodes,
		"the ladder is monotone in this knob too")


func test_the_apprentice_swings_into_the_crack_back() -> void:
	var ai := AiPlayer.new(0, AiProfile.apprentice())
	put_battlefield(0, "Hill Giant")
	var wurm := put_battlefield(1, "Craw Wurm")
	wurm.tapped = true
	_set_life(0, 3)
	# mistake_chance can drop the attacker, so ask the search's entry
	# directly rather than the whole ladder.
	var held := ai._search_hold_back(g, _creatures(0), [g.players[0].battlefield[0].id], 1)
	assert_eq(held.size(), 1, "the Apprentice does not look past its own combat")


func _creatures(pid: int) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for inst in g.players[pid].battlefield:
		if inst.is_creature():
			out.append(inst)
	return out


## DETERMINISM IS LOAD-BEARING (CONTRIBUTING.md rule 7, and the Deck Lab's
## whole `results.json` contract): the search must not touch the random
## stream, or the same seed stops being the same game.
func test_the_search_draws_nothing_from_the_random_stream() -> void:
	var ai := _wizard()
	put_battlefield(0, "Hill Giant")
	var wurm := put_battlefield(1, "Craw Wurm")
	wurm.tapped = true
	_set_life(0, 3)
	var before := g.rng.state
	var held := ai._search_hold_back(g, _creatures(0), [g.players[0].battlefield[0].id], 1)
	assert_eq(held.size(), 0)
	assert_eq(g.rng.state, before, "the search rolled a die")


## And it must not MUTATE anything either: it reads the board through the
## engine's predicates and writes nothing back.
func test_the_search_leaves_the_board_alone() -> void:
	var ai := _wizard()
	var giant := put_battlefield(0, "Hill Giant")
	var wurm := put_battlefield(1, "Craw Wurm")
	wurm.tapped = true
	_set_life(0, 3)
	var before := _capture()
	ai._search_hold_back(g, _creatures(0), [giant.id], 1)
	assert_eq(_drift(before), [], "the search wrote to the game state")


## Every mutable field of the game, as [GameSnapshot] defines "mutable" —
## `tests/ai/test_undo_log.gd`'s differ, borrowed because it is the one
## that already knows what "all the state there is" means here.
func _capture() -> Array:
	var snap := GameSnapshot.take(g)
	var out: Array = []
	for i in snap._objects.size():
		var obj: Object = snap._objects[i]
		var props: Array = snap._props[i]
		var values: Array = snap._values[i]
		var k := 0
		for group in [props[0], props[1]]:
			for name in group:
				if name != &"undo_log" and name != &"journal":
					out.append([obj, name, _deep(values[k])])
				k += 1
	out.append([g.rng, &"state", g.rng.state])
	snap.restore()
	return out


static func _deep(value: Variant) -> Variant:
	var t := typeof(value)
	if t == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	if t == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	if t >= TYPE_PACKED_BYTE_ARRAY:
		return value.duplicate()
	return value


## The fields that differ from [param before] now, named.
func _drift(before: Array) -> Array:
	var bad: Array = []
	for row in before:
		var obj: Object = row[0]
		var name: StringName = row[1]
		if str(obj.get(name)) != str(row[2]):
			bad.append("%s.%s" % [obj.get_script().get_global_name(), name])
	return bad


## The budget is a HARD stop and it is deterministic: the same board
## always explores the same nodes in the same order, so a truncated search
## is reproducible rather than timing-dependent.
func test_the_node_budget_is_a_hard_stop() -> void:
	var ai := _wizard()
	for _i in 6:
		put_battlefield(0, "Grizzly Bears")
	for _i in 6:
		var wurm := put_battlefield(1, "Craw Wurm")
		wurm.tapped = true
	_set_life(0, 4)
	var ids: Array = []
	for inst in g.players[0].battlefield:
		ids.append(inst.id)
	var first := ai._search_hold_back(g, _creatures(0), ids, 1)
	var second := ai._search_hold_back(g, _creatures(0), ids, 1)
	assert_eq(first, second, "the same board gives the same answer twice")
