extends GameTest
## THE PACK 9 BUG PASS, fix-ai-2 — activations, read by the fair AI
## ([member AiProfile.forecasts_tactics]):
##  * h6-8: the shared `self_bounce` reader (alliances_tactics.gd
##    `takes_self`) answers only an object that would take the permanent —
##    a removal, a steal, damage or a shrink that kills, a hostile Aura — and
##    a bounce only when it costs them a buyback or our answer keeps the
##    permanent in place (shroud, protection). Hibernation Sliver's grant no
##    longer pays 2 life to dodge a Twiddle or to do what a Capsize does;
##    the Ephemeron-shaped cards keep their answer to removal.
##  * h6-10: an activated reanimation (tempest_tactics.gd `reanimate_option`)
##    is priced: Coffin Queen and Recurring Nightmare raise the best creature
##    card, Volrath's Stronghold stacks one at their end step.
## Null arms (gate off) and hidden-information permutations.


const AT := preload("res://engine/ai/alliances_tactics.gd")


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(on := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.mistake_chance = 0.0
	p.develops_late = false
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _their_main() -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.MAIN1) and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)


## Seat 1 casts [param spell] (row [param mode]) at [param target]; seat 0
## holds priority over it.
func _they_cast_at(spell: String, target: CardInstance, mana: Array, mode := 0) -> CardInstance:
	_their_main()
	var card := give_hand(1, spell)
	for c in mana: add_mana(1, c)
	assert_ok(g.cast_spell(1, card, [TargetRef.card(target)], 0, mode))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	return card


func _buyback_row(spell: String) -> int:
	var data := CardRegistry.get_card(spell)
	for mode in data.modes.size():
		if bool((data.modes[mode] as Dictionary).get("payment", {}).get("buyback", false)):
			return mode
	return -1


# ------------------------------------------------------- h6-8: Hibernation Sliver --

func test_hibernation_sliver_does_not_dodge_a_twiddle() -> void:
	var ai := _ai()
	put_battlefield(0, "Hibernation Sliver")
	var muscle := put_battlefield(0, "Muscle Sliver")
	_they_cast_at("Twiddle", muscle, [Mtg.ManaColor.U])
	var did := ai.act(g)
	resolve_stack()
	assert_eq(g.players[0].life, 20, "paid 2 life (%s) to dodge a tap" % did)
	assert_eq(muscle.zone, Mtg.Zone.BATTLEFIELD)


func test_hibernation_sliver_does_not_pay_to_do_what_capsize_does() -> void:
	var ai := _ai()
	put_battlefield(0, "Hibernation Sliver")
	var muscle := put_battlefield(0, "Muscle Sliver")
	_they_cast_at("Capsize", muscle, [Mtg.ManaColor.U, Mtg.ManaColor.U, Mtg.ManaColor.C])
	var did := ai.act(g)
	resolve_stack()
	assert_eq(muscle.zone, Mtg.Zone.HAND, "Capsize returns it either way")
	assert_eq(g.players[0].life, 20, "paid 2 life (%s) for the same bounce" % did)


func test_hibernation_sliver_denies_a_capsize_its_buyback() -> void:
	var ai := _ai()
	put_battlefield(0, "Hibernation Sliver")
	var muscle := put_battlefield(0, "Muscle Sliver")
	var row := _buyback_row("Capsize")
	assert_gt(row, 0, "precondition: Capsize has a buyback row")
	var capsize := _they_cast_at("Capsize", muscle,
		[Mtg.ManaColor.U, Mtg.ManaColor.U, Mtg.ManaColor.C, Mtg.ManaColor.C, Mtg.ManaColor.C, Mtg.ManaColor.C], row)
	assert_string_contains(ai.act(g), "Muscle Sliver")
	resolve_stack()
	assert_eq(muscle.zone, Mtg.Zone.HAND)
	assert_eq(capsize.zone, Mtg.Zone.GRAVEYARD, "fizzled: no buyback")


func test_hibernation_sliver_still_saves_a_sliver_from_a_bolt() -> void:
	var ai := _ai()
	put_battlefield(0, "Hibernation Sliver")
	var metallic := put_battlefield(0, "Metallic Sliver")
	_they_cast_at("Lightning Bolt", metallic, [Mtg.ManaColor.R])
	assert_string_contains(ai.act(g), "Metallic Sliver")
	resolve_stack()
	assert_eq(metallic.zone, Mtg.Zone.HAND)


# ------------------------------------------- the Ephemeron-shaped regressions --

## The shared reader's answer for Ephemeron's "Discard a card: return
## this creature to its owner's hand" (its discard is a cost the pilot's
## gate prices separately; the READING is what this pins).
func _ephemeron_reading(spell: String, mana: Array, mode := 0) -> Variant:
	var ai := _ai()
	var eph := put_battlefield(0, "Ephemeron")
	give_hand(0, "Island")
	_they_cast_at(spell, eph, mana, mode)
	return AT.option(g, ai, eph, 0, "RESPONSE")


func _answers(read: Variant) -> bool:
	return read is Dictionary and not (read as Dictionary).is_empty()


func test_ephemeron_reads_a_terror_as_one_to_escape() -> void:
	assert_true(_answers(_ephemeron_reading("Terror", [Mtg.ManaColor.B, Mtg.ManaColor.C])))


func test_ephemeron_reads_a_twiddle_as_nothing_to_escape() -> void:
	assert_false(_answers(_ephemeron_reading("Twiddle", [Mtg.ManaColor.U])))


func test_ephemeron_reads_a_plain_capsize_as_nothing_to_escape() -> void:
	assert_false(_answers(_ephemeron_reading("Capsize",
		[Mtg.ManaColor.U, Mtg.ManaColor.U, Mtg.ManaColor.C])))


func test_ephemeron_reads_a_buyback_capsize_as_one_to_deny() -> void:
	assert_true(_answers(_ephemeron_reading("Capsize", [Mtg.ManaColor.U, Mtg.ManaColor.U,
		Mtg.ManaColor.C, Mtg.ManaColor.C, Mtg.ManaColor.C, Mtg.ManaColor.C], _buyback_row("Capsize"))))


func test_ephemeron_reads_a_bolt_it_survives_as_nothing_to_escape() -> void:
	assert_false(_answers(_ephemeron_reading("Lightning Bolt", [Mtg.ManaColor.R])), "a 4/4 lives through 3")


func test_giant_crab_shrouds_itself_from_a_plain_capsize() -> void:
	var ai := _ai()
	var crab := put_battlefield(0, "Giant Crab")
	put_battlefield(0, "Island")
	_they_cast_at("Capsize", crab, [Mtg.ManaColor.U, Mtg.ManaColor.U, Mtg.ManaColor.C])
	assert_eq(ai.act(g), "activated Giant Crab", "shroud keeps it where it is")
	resolve_stack()
	assert_eq(crab.zone, Mtg.Zone.BATTLEFIELD)


func test_giant_crab_lets_a_shock_it_survives_through() -> void:
	var ai := _ai()
	var crab := put_battlefield(0, "Giant Crab")
	put_battlefield(0, "Island")
	_they_cast_at("Shock", crab, [Mtg.ManaColor.R])
	assert_ne(ai.act(g), "activated Giant Crab", "a 3/3 lives through 2 damage")


func test_the_null_arm_never_answers_from_the_sliver() -> void:
	var ai := _ai(false)
	put_battlefield(0, "Hibernation Sliver")
	var metallic := put_battlefield(0, "Metallic Sliver")
	_they_cast_at("Lightning Bolt", metallic, [Mtg.ManaColor.R])
	assert_false(ai.act(g).contains("Metallic Sliver"))


func test_the_self_bounce_answer_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		put_battlefield(0, "Hibernation Sliver")
		var muscle := put_battlefield(0, "Muscle Sliver")
		give_hand(1, "Shivan Dragon" if variant == 0 else "Fog")
		if variant == 1: g.players[1].library.reverse()
		_they_cast_at("Twiddle", muscle, [Mtg.ManaColor.U])
		answers.append(ai.act(g))
	assert_eq(answers[0], answers[1])


# ------------------------------------------------------- h6-10: the reanimators --

func _dead(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(inst)
	return inst


func _play_step(ai: AiPlayer) -> Array:
	var lines: Array = []
	var turn := g.turn_number
	var step := g.current_step()
	for k in 20:
		if g.game_over or g.turn_number != turn or g.current_step() != step: break
		if g.priority_player == 0:
			var did := ai.act(g)
			lines.append(did)
			if did == "" or did == "pass": break
		else:
			g.pass_priority(g.priority_player)
	resolve_stack()
	return lines


func _their_end_step() -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.END) and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.pass_priority(1))


func test_coffin_queen_raises_a_dragon() -> void:
	var ai := _ai()
	put_battlefield(0, "Coffin Queen")
	for k in 3: put_battlefield(0, "Swamp")
	var dragon := _dead(0, "Shivan Dragon")
	_play_step(ai)
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(dragon.controller_id, 0)


func test_coffin_queen_raises_their_dragon_too() -> void:
	var ai := _ai()
	put_battlefield(0, "Coffin Queen")
	for k in 3: put_battlefield(0, "Swamp")
	_dead(0, "Grizzly Bears")
	var dragon := _dead(1, "Shivan Dragon")
	_play_step(ai)
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD, "from a graveyard: theirs is public too")
	assert_eq(dragon.controller_id, 0)


func test_recurring_nightmare_trades_elves_for_a_dragon() -> void:
	var ai := _ai()
	put_battlefield(0, "Recurring Nightmare")
	var elves := put_battlefield(0, "Llanowar Elves")
	var dragon := _dead(0, "Shivan Dragon")
	_play_step(ai)
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)


func test_recurring_nightmare_never_trades_down() -> void:
	var ai := _ai()
	var nightmare := put_battlefield(0, "Recurring Nightmare")
	var dragon := put_battlefield(0, "Shivan Dragon")
	var elves := _dead(0, "Llanowar Elves")
	_play_step(ai)
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(nightmare.zone, Mtg.Zone.BATTLEFIELD)


func test_volraths_stronghold_stacks_a_dragon_at_their_end_step() -> void:
	var ai := _ai()
	put_battlefield(0, "Volrath's Stronghold")
	for k in 3: put_battlefield(0, "Swamp")
	var dragon := _dead(0, "Shivan Dragon")
	_their_end_step()
	_play_step(ai)
	assert_eq(dragon.zone, Mtg.Zone.LIBRARY)


func test_volraths_stronghold_waits_in_our_main_phase() -> void:
	var ai := _ai()
	put_battlefield(0, "Volrath's Stronghold")
	for k in 3: put_battlefield(0, "Swamp")
	var dragon := _dead(0, "Shivan Dragon")
	_play_step(ai)
	assert_eq(dragon.zone, Mtg.Zone.GRAVEYARD, "the draw it replaces is tomorrow's: their end step")


func test_the_null_arm_raises_nothing() -> void:
	var ai := _ai(false)
	put_battlefield(0, "Coffin Queen")
	for k in 3: put_battlefield(0, "Swamp")
	var dragon := _dead(0, "Shivan Dragon")
	_play_step(ai)
	assert_eq(dragon.zone, Mtg.Zone.GRAVEYARD)


func test_the_reanimation_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		put_battlefield(0, "Coffin Queen")
		for k in 3: put_battlefield(0, "Swamp")
		_dead(0, "Shivan Dragon")
		give_hand(1, "Terror" if variant == 0 else "Island")
		if variant == 1: g.players[1].library.reverse()
		answers.append(ai.act(g))
	assert_eq(answers[0], answers[1])
