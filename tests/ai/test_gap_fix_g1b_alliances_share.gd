extends GameTest
## Gap review 2026-11-10, r1b-2 in alliances_tactics.gd: the two readers
## there still took a divided spell's whole total as what each target
## takes.
##  * `takes_self` (the `self_bounce` answer): 1 point of Pyrotechnics at a
##    4/4 Ephemeron read as the 4 that kills it — a bounce (and the card
##    its cost discards) priced as saving a creature that lives.
##  * Force of Will's lethal check in `special_spell`: Pyrotechnics' 4 read
##    as lethal at our face when 1 of it was aimed there — and Fireball,
##    read without its name, as no damage at all, so half a Fireball for
##    our last life went unanswered.


const AT := preload("res://engine/ai/alliances_tactics.gd")


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-5", true)
	CardPacks.set_enabled("pack-9", true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(on := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


## A Wizard whose counters fire only on the lethal line: the bar out of
## reach and no shape reading, so Force of Will's own lethal check is the
## only reason it is cast.
func _lethal_only_ai() -> AiPlayer:
	var ai := _ai(true)
	ai.profile.counter_threshold = 99.0
	ai.profile.counters_by_shape = false
	return ai


func _their_main() -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.MAIN1) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)


## Seat 0 (the AI) answers; seat 1 only passes; until the stack is empty.
func _play_out_stack(ai: AiPlayer) -> Array:
	var lines: Array = []
	var guard := 0
	while not g.stack.is_empty() and not g.game_over and guard < 60:
		guard += 1
		if g.priority_player == 0:
			var did := ai.act(g)
			if did != "pass" and did != "":
				lines.append(did)
		else:
			assert_ok(g.pass_priority(1))
	return lines


func _cast(card_name: String, targets: Array, x := 0) -> void:
	_their_main()
	var spell := give_hand(1, card_name)
	add_mana(1, Mtg.ManaColor.R, 24)
	assert_ok(g.cast_spell(1, spell, targets, x))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


func _any_line_has(lines: Array, word: String) -> bool:
	for line in lines:
		if str(line).contains(word):
			return true
	return false


# ------------------------------------------------------ takes_self (self_bounce)

## Ephemeron ("Discard a card: Return this creature to its owner's hand",
## role `self_bounce`) under their Pyrotechnics: [param share] of its 4 at
## the 4/4, the rest at our face. The Alliances reading of the bounce in
## the response window.
func _ephemeron_reading(share: int, on := true) -> Variant:
	var ai := _ai(on)
	var eph := put_battlefield(0, "Ephemeron")
	give_hand(0, "Forest")   # the card its "Discard a card" cost would take
	var targets := [TargetRef.card(eph, share)]
	if share < 4:
		targets.append(TargetRef.player(0, 4 - share))
	_cast("Pyrotechnics", targets)
	var a: ActivatedAbility = eph.cur_activated_abilities[0]
	assert_eq(a.effects[0].ai_role, &"self_bounce")
	return AT.option(g, ai, eph, 0, "RESPONSE")


func test_ephemeron_is_not_bounced_from_one_point() -> void:
	var got: Variant = _ephemeron_reading(1)
	gut.p("Ephemeron, 1 point: %s" % [got])
	assert_true(got is Dictionary and (got as Dictionary).is_empty(),
		"a 4/4 taking 1 lives — no reason to bounce it: %s" % [got])


## Control: all 4 of it kill the 4/4, and the bounce saves it.
func test_ephemeron_is_bounced_from_the_whole_four() -> void:
	var got: Variant = _ephemeron_reading(4)
	gut.p("Ephemeron, 4 points: %s" % [got])
	assert_true(got is Dictionary and not (got as Dictionary).is_empty(), str(got))


## The gate off reads nothing.
func test_gate_off_reads_no_bounce() -> void:
	assert_null(_ephemeron_reading(1, false))


# ----------------------------------------------------- Force of Will's lethal check

func _force_of_will() -> void:
	for _i in 5: put_battlefield(0, "Island")
	give_hand(0, "Force of Will")


## 1 of Pyrotechnics at our face (4 life), 3 at our Bears: not lethal.
func test_force_of_will_is_not_forced_by_a_share_that_does_not_kill() -> void:
	var ai := _lethal_only_ai()
	_force_of_will()
	var bears := put_battlefield(0, "Grizzly Bears")
	g.players[0].life = 4
	_cast("Pyrotechnics", [TargetRef.player(0, 1), TargetRef.card(bears, 3)])
	var lines := _play_out_stack(ai)
	gut.p("FoW v 1 at our face: %s; life %d" % [lines, g.players[0].life])
	assert_false(_any_line_has(lines, "Force of Will"), "1 at 4 life is not lethal: %s" % [lines])
	assert_eq(g.players[0].life, 3)


## Fireball X=8 at our face and our Bears: 4 each, our last 4 life.
func test_force_of_will_answers_half_a_fireball_that_kills() -> void:
	var ai := _lethal_only_ai()
	_force_of_will()
	var bears := put_battlefield(0, "Grizzly Bears")
	g.players[0].life = 4
	_cast("Fireball", [TargetRef.player(0), TargetRef.card(bears)], 8)
	var lines := _play_out_stack(ai)
	gut.p("FoW v half a Fireball: %s; life %d" % [lines, g.players[0].life])
	assert_true(_any_line_has(lines, "Force of Will"), "4 of it at 4 life is lethal: %s" % [lines])
	assert_false(g.game_over)


## ...and not the 3 of an X=6 split two ways.
func test_force_of_will_lets_half_a_smaller_fireball_through() -> void:
	var ai := _lethal_only_ai()
	_force_of_will()
	var bears := put_battlefield(0, "Grizzly Bears")
	g.players[0].life = 4
	_cast("Fireball", [TargetRef.player(0), TargetRef.card(bears)], 6)
	var lines := _play_out_stack(ai)
	gut.p("FoW v X=6 split: %s; life %d" % [lines, g.players[0].life])
	assert_false(_any_line_has(lines, "Force of Will"), "3 at 4 life is not lethal: %s" % [lines])
	assert_eq(g.players[0].life, 1)


## Control: all 4 of Pyrotechnics at our 4 life.
func test_force_of_will_answers_a_lethal_pyrotechnics() -> void:
	var ai := _lethal_only_ai()
	_force_of_will()
	g.players[0].life = 4
	_cast("Pyrotechnics", [TargetRef.player(0, 4)])
	var lines := _play_out_stack(ai)
	assert_true(_any_line_has(lines, "Force of Will"), str(lines))
	assert_false(g.game_over)
