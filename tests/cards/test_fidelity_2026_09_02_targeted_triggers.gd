extends GameTest
## The eight cards whose triggered abilities TARGET — lifted from the
## fidelity ledger's "triggers that pick their own victim" row on
## TriggeredAbility.targeting (CR 603.3d; tests/unit/test_targeted_triggers.gd
## pins the mechanism). Each card here is pinned on what the row denied
## it: the controller's OWN choice is honoured (a seat that names a card
## the old heuristic would never have picked), shroud keeps a creature off
## the list, the trigger fizzles when its target leaves in response (CR
## 608.2b), and with nothing legal it never goes on the stack. Oubliette
## and Relic Bind also pin the human seat's hold, Relic Bind its mode
## announced before its target (CR 603.3c), Halfdane the printed "until
## the end of your next upkeep".


## Picks named cards, in order; records what it was offered.
class ListSeat extends DecisionAgent:
	var picks: Array = []
	var offered: Array = []

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		var names: Array = []
		for inst in candidates:
			names.append(inst.data.card_name)
		offered.append(names)
		if picks.is_empty():
			return null
		var wanted := String(picks.pop_front())
		for inst in candidates:
			if inst.data.card_name == wanted:
				return inst
		return null


## Answers OPTION questions by label, in order; records prompts and
## options; says yes to everything.
class LabelSeat extends DecisionAgent:
	var picks: Array = []
	var asked: Array = []   # [prompt, options] per question

	func answer_option(_game: MtgGame, _pid: int, prompt: String,
			options: Array[String], hint: int) -> int:
		asked.append([prompt, options.duplicate()])
		if picks.is_empty():
			return hint
		var wanted := String(picks.pop_front())
		var at := options.find(wanted)
		return at if at >= 0 else hint

	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String,
			_hint: bool) -> bool:
		return true


func _human_seat(pid := 0) -> HumanAgent:
	var human := HumanAgent.new()
	g.agents[pid] = human
	g.interactive_choices = true
	return human


func _last_log() -> String:
	return String(g.log_lines[g.log_lines.size() - 1])


func _log_has(text: String) -> bool:
	for line in g.log_lines:
		if String(line).contains(text):
			return true
	return false


func _shroud(inst: CardInstance, pid: int) -> void:
	g.attach_aura_from_anywhere(give_hand(pid, "Spectral Cloak"), inst, pid)
	g.recalculate()


func _cast_enchantment(name: String) -> CardInstance:
	var card := give_hand(0, name)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 3)
	add_mana(0, Mtg.ManaColor.U, 3)
	assert_ok(g.cast_spell(0, card, []))
	return card


# ---------------------------------------------------------------- Oubliette --

func test_oubliette_imprisons_the_creature_its_controller_targets() -> void:
	var seat := ListSeat.new()
	seat.picks = ["Grizzly Bears"]
	g.set_agent(0, seat)
	var giant := put_battlefield(1, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	_cast_enchantment("Oubliette")
	resolve_stack()
	assert_true(bear.phased_out, "the chosen creature, not the biggest")
	assert_false(giant.phased_out)
	assert_eq(seat.offered, [["Hill Giant", "Grizzly Bears"]],
		"ranked the opponent's biggest first")


func test_oubliette_may_target_your_own_creature() -> void:
	var seat := ListSeat.new()
	seat.picks = ["Grizzly Bears"]
	g.set_agent(0, seat)
	put_battlefield(1, "Hill Giant")
	var mine := put_battlefield(0, "Grizzly Bears")
	_cast_enchantment("Oubliette")
	resolve_stack()
	assert_true(mine.phased_out, "'target creature' — yours is legal")
	assert_eq(seat.offered, [["Hill Giant", "Grizzly Bears"]],
		"the opponent's first, then your own")


func test_oubliette_cannot_target_a_creature_with_shroud() -> void:
	var seat := ListSeat.new()
	g.set_agent(0, seat)
	var giant := put_battlefield(1, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	_shroud(giant, 1)
	_cast_enchantment("Oubliette")
	resolve_stack()
	assert_eq(seat.offered, [["Grizzly Bears"]], "the cloaked Giant is off the list")
	assert_true(bear.phased_out)
	assert_false(giant.phased_out)


func test_oubliette_fizzles_when_its_target_dies_in_response() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var oubliette := _cast_enchantment("Oubliette")
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))   # the spell resolves; the trigger goes on
	assert_eq(g.stack.size(), 1)
	assert_true(g.stack.back().description.contains("targeting Grizzly Bears"))
	assert_ok(g.pass_priority(0))
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_true(_log_has("fizzles"), "CR 608.2b")
	assert_eq(oubliette.zone, Mtg.Zone.BATTLEFIELD, "the Oubliette stays, empty")
	assert_false(oubliette.memory.has("prisoner"))


func test_oubliette_with_no_creature_never_goes_on_the_stack() -> void:
	var oubliette := _cast_enchantment("Oubliette")
	resolve_stack()
	assert_eq(oubliette.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(_log_has("no legal target, removed"), "CR 603.3d")
	assert_true(g.stack.is_empty())


func test_oubliette_holds_a_human_seat_on_the_target() -> void:
	_human_seat(0)
	var giant := put_battlefield(1, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	_cast_enchantment("Oubliette")
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))   # the spell resolves; the trigger is held
	assert_not_null(g.awaiting_choice, "the seat is asked as it would get priority")
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.CARD)
	assert_eq(g.awaiting_choice.source, "Oubliette")
	assert_eq(g.awaiting_choice.prompt, "Select a creature.")
	assert_eq(g.awaiting_choice.candidates, [giant, bear] as Array[CardInstance])
	assert_refused(g.pass_priority(0), "waiting for a choice")
	assert_ok(g.answer_choice("Grizzly Bears"))
	assert_null(g.awaiting_choice)
	assert_true(g.stack.back().description.contains("targeting Grizzly Bears"))
	resolve_stack()
	assert_true(bear.phased_out)
	assert_false(giant.phased_out)
	assert_true(g.unanswered_choices.is_empty())


# ----------------------------------------------------------------- Halfdane --

func _to_own_upkeep() -> void:
	# From turn 1's first main phase to turn 3 — P0's next upkeep — with
	# P0 holding priority over the upkeep trigger.
	advance_to_next_turn()
	advance_to_step(Mtg.Step.UPKEEP)
	assert_eq(g.active_player, 0)


func test_halfdane_takes_the_body_its_controller_targets() -> void:
	var seat := ListSeat.new()
	seat.picks = ["Grizzly Bears"]
	g.set_agent(0, seat)
	var halfdane := put_battlefield(0, "Halfdane")
	put_battlefield(1, "Serra Angel")        # 4/4
	put_battlefield(1, "Grizzly Bears")      # 2/2
	_to_own_upkeep()
	resolve_stack()
	assert_eq(halfdane.cur_power, 2, "the chosen body, not the biggest")
	assert_eq(halfdane.cur_toughness, 2)
	assert_eq(seat.offered, [["Serra Angel", "Grizzly Bears"]], "biggest first")


func test_halfdane_cannot_target_itself() -> void:
	var halfdane := put_battlefield(0, "Halfdane")
	_to_own_upkeep()
	assert_true(g.stack.is_empty(), "no other creature: the trigger is removed")
	assert_true(_log_has("no legal target, removed"))
	resolve_stack()
	assert_eq(halfdane.cur_power, 3)


func test_halfdane_fizzles_when_its_model_dies_in_response() -> void:
	var halfdane := put_battlefield(0, "Halfdane")
	var bear := put_battlefield(1, "Grizzly Bears")
	_to_own_upkeep()
	assert_eq(g.stack.size(), 1)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_true(_log_has("fizzles"))
	assert_eq(halfdane.cur_power, 3, "still its own 3/3")


func test_halfdanes_shape_lasts_until_the_end_of_its_next_upkeep() -> void:
	var halfdane := put_battlefield(0, "Halfdane")
	var angel := put_battlefield(1, "Serra Angel")
	_to_own_upkeep()
	resolve_stack()
	assert_eq(halfdane.cur_power, 4)
	g.destroy(angel, false)
	g.check_state_based_actions()
	advance_to_next_turn()   # the opponent's turn
	assert_eq(halfdane.cur_power, 4, "the shape crosses the cleanup step")
	advance_to_step(Mtg.Step.UPKEEP)   # P0's next upkeep — nothing to copy
	assert_eq(g.active_player, 0)
	assert_eq(halfdane.cur_power, 4, "still worn DURING that upkeep")
	advance_to_step(Mtg.Step.DRAW)
	assert_eq(halfdane.cur_power, 3, "and gone as the upkeep ends (CR 611.2b)")
	assert_eq(halfdane.cur_toughness, 3)


func test_halfdane_renews_the_shape_each_upkeep() -> void:
	var halfdane := put_battlefield(0, "Halfdane")
	var angel := put_battlefield(1, "Serra Angel")
	_to_own_upkeep()
	resolve_stack()
	assert_eq(halfdane.cur_power, 4)
	g.destroy(angel, false)
	g.check_state_based_actions()
	put_battlefield(1, "Grizzly Bears")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(halfdane.cur_power, 2, "the new shape replaced the old")


# ------------------------------------------------------------ Dance of Many --

func test_dance_of_many_copies_the_creature_its_controller_targets() -> void:
	var seat := ListSeat.new()
	seat.picks = ["Grizzly Bears"]
	g.set_agent(0, seat)
	put_battlefield(1, "Serra Angel")
	put_battlefield(0, "Grizzly Bears")
	var dance := _cast_enchantment("Dance of Many")
	resolve_stack()
	var token := g.find_instance(int(dance.memory.get("token", -1)))
	assert_not_null(token)
	assert_eq(token.data.card_name, "Grizzly Bears", "the chosen one, not the best")
	assert_true(token.is_token)
	assert_eq(seat.offered, [["Serra Angel", "Grizzly Bears"]], "biggest first")


func test_dance_of_many_cannot_target_a_token() -> void:
	var seat := ListSeat.new()
	g.set_agent(0, seat)
	g.create_token(1, CardRegistry.get_card("Serra Angel"))
	put_battlefield(1, "Grizzly Bears")
	_cast_enchantment("Dance of Many")
	resolve_stack()
	assert_eq(seat.offered, [["Grizzly Bears"]], "'nontoken': the Angel token is off the list")


func test_dance_of_many_fizzles_when_its_target_dies_in_response() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var dance := _cast_enchantment("Dance of Many")
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_ok(g.pass_priority(0))
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(_log_has("fizzles"))
	assert_false(dance.memory.has("token"), "no token was made")
	assert_eq(dance.zone, Mtg.Zone.BATTLEFIELD)
	for inst in g.all_battlefield():
		assert_false(inst.is_token)


func test_dance_of_many_with_no_nontoken_creature_never_triggers() -> void:
	g.create_token(1, CardRegistry.get_card("Serra Angel"))
	_cast_enchantment("Dance of Many")
	resolve_stack()
	assert_true(_log_has("no legal target, removed"))
	assert_eq(g.all_battlefield().size(), 2, "the token and the Dance — no copy")


# ------------------------------------------------------------ Blazing Effigy --

func test_blazing_effigy_shoots_the_creature_its_controller_targets() -> void:
	var seat := ListSeat.new()
	seat.picks = ["Grizzly Bears"]
	g.set_agent(0, seat)
	var effigy := put_battlefield(0, "Blazing Effigy")
	var giant := put_battlefield(1, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	g.destroy(effigy, false)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the chosen one")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(seat.offered, [["Hill Giant", "Grizzly Bears"]],
		"the opponent's biggest first")


func test_blazing_effigy_cannot_target_a_creature_with_shroud() -> void:
	var seat := ListSeat.new()
	g.set_agent(0, seat)
	var effigy := put_battlefield(0, "Blazing Effigy")
	var giant := put_battlefield(1, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	_shroud(giant, 1)
	advance_to_step(Mtg.Step.MAIN1)
	g.destroy(effigy, false)
	resolve_stack()
	assert_eq(seat.offered, [["Grizzly Bears"]])
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)


func test_blazing_effigy_fizzles_when_its_target_leaves() -> void:
	var effigy := put_battlefield(0, "Blazing Effigy")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	g.destroy(effigy, false)
	assert_eq(g.stack.size(), 1)
	assert_true(g.stack.back().description.contains("targeting Hill Giant"))
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(giant)]))
	resolve_stack()
	assert_true(_log_has("fizzles"))
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "the Bolt killed it, not the Effigy")


func test_blazing_effigy_with_no_creature_never_goes_on_the_stack() -> void:
	var effigy := put_battlefield(0, "Blazing Effigy")
	advance_to_step(Mtg.Step.MAIN1)
	g.destroy(effigy, false)
	assert_true(g.stack.is_empty())
	assert_true(_log_has("no legal target, removed"))


# ---------------------------------------------------------- Axelrod Gunnarson --

func _axelrod_kill() -> void:
	var axelrod := put_battlefield(0, "Axelrod Gunnarson")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	g.deal_damage(axelrod, TargetRef.card(giant), 1)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)


func test_axelrod_shoots_the_player_its_controller_targets() -> void:
	var seat := LabelSeat.new()
	seat.picks = ["P0"]   # himself
	g.set_agent(0, seat)
	_axelrod_kill()
	assert_eq(g.players[0].life, 20, "gained 1, shot himself for 1")
	assert_eq(g.players[1].life, 20)
	assert_eq(seat.asked.size(), 1)
	assert_eq(seat.asked[0][0], "Select target player.")
	assert_eq(seat.asked[0][1], ["P1", "P0"] as Array[String], "the opponent first")


func test_axelrod_targets_the_opponent_by_default() -> void:
	_axelrod_kill()
	assert_eq(g.players[0].life, 21)
	assert_eq(g.players[1].life, 19)


# ------------------------------------------------------------ Floral Spuzzem --

func test_floral_spuzzem_destroys_the_artifact_its_controller_targets() -> void:
	var seat := ListSeat.new()
	seat.picks = ["Sol Ring"]
	g.set_agent(0, seat)
	var spuzzem := put_battlefield(0, "Floral Spuzzem")
	var disk := put_battlefield(1, "Nevinyrral's Disk")
	var ring := put_battlefield(1, "Sol Ring")
	run_combat([spuzzem.id])
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD, "the chosen one, not the dearest")
	assert_eq(disk.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[1].life, 20, "and it dealt no combat damage")
	assert_eq(seat.offered, [["Nevinyrral's Disk", "Sol Ring"]], "dearest first")


func test_floral_spuzzem_cannot_target_your_own_artifact() -> void:
	var spuzzem := put_battlefield(0, "Floral Spuzzem")
	var mine := put_battlefield(0, "Sol Ring")
	run_combat([spuzzem.id])
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(_log_has("no legal target, removed"), "no artifact on their side")
	assert_eq(g.players[1].life, 18, "so it simply swings")


func test_floral_spuzzem_fizzles_when_the_artifact_leaves() -> void:
	var spuzzem := put_battlefield(0, "Floral Spuzzem")
	var disk := put_battlefield(1, "Nevinyrral's Disk")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [spuzzem.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	assert_eq(g.stack.size(), 1, "unblocked: the trigger is on the stack")
	assert_true(g.stack.back().description.contains("targeting Nevinyrral's Disk"))
	assert_ok(g.pass_priority(0))
	var shatter := give_hand(1, "Shatter")
	add_mana(1, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(1, shatter, [TargetRef.card(disk)]))
	resolve_stack()
	assert_eq(disk.zone, Mtg.Zone.GRAVEYARD, "Shattered by its owner")
	assert_true(_log_has("fizzles"))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 18, "nothing was traded: the Spuzzem hit")


# ---------------------------------------------------------------- Relic Bind --

func _bound_ring() -> CardInstance:
	var ring := put_battlefield(1, "Sol Ring")
	var aura := give_hand(0, "Relic Bind")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(ring)]))
	resolve_stack()
	return ring


func test_relic_bind_announces_its_mode_then_its_target() -> void:
	var seat := LabelSeat.new()
	g.set_agent(0, seat)
	var ring := _bound_ring()
	assert_ok(g.tap_for_mana(1, ring))
	assert_eq(seat.asked.size(), 2, "two questions as the trigger went on the stack")
	assert_eq(seat.asked[0][1], ["Gain life.", "Take damage."] as Array[String],
		"the mode first (CR 603.3c), in the original's words")
	assert_eq(seat.asked[1][0], "Select target player.")
	assert_eq(seat.asked[1][1], ["P1", "P0"] as Array[String], "then the target")
	assert_eq(g.stack.size(), 1)
	assert_true(g.stack.back().description.contains("Take damage., targeting P1"),
		"both on the stack for the opponent to see")
	resolve_stack()
	assert_eq(g.players[1].life, 19)


func test_relic_bind_can_heal_the_player_of_your_choice() -> void:
	var seat := LabelSeat.new()
	seat.picks = ["Gain life.", "P0"]
	g.set_agent(0, seat)
	var ring := _bound_ring()
	assert_ok(g.tap_for_mana(1, ring))
	resolve_stack()
	assert_eq(g.players[0].life, 21)
	assert_eq(g.players[1].life, 20)


func test_relic_bind_can_burn_its_own_controller() -> void:
	var seat := LabelSeat.new()
	seat.picks = ["Take damage.", "P0"]
	g.set_agent(0, seat)
	var ring := _bound_ring()
	assert_ok(g.tap_for_mana(1, ring))
	resolve_stack()
	assert_eq(g.players[0].life, 19, "'target player' — yourself is legal")
	assert_eq(g.players[1].life, 20)


func test_relic_bind_holds_a_human_seat_on_mode_then_target() -> void:
	var ring := _bound_ring()
	_human_seat(0)
	advance_to_next_turn()   # P1's turn: they tap the Ring for mana
	assert_ok(g.tap_for_mana(1, ring))
	assert_not_null(g.awaiting_choice, "held as the tapper would keep priority")
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.OPTION)
	assert_eq(g.awaiting_choice.pid, 0, "the Aura's controller chooses")
	assert_eq(g.awaiting_choice.source, "Relic Bind")
	assert_eq(g.awaiting_choice.options, ["Gain life.", "Take damage."] as Array[String])
	assert_ok(g.answer_choice(0))   # Gain life.
	assert_not_null(g.awaiting_choice, "and then the target")
	assert_eq(g.awaiting_choice.prompt, "Select target player.")
	assert_eq(g.awaiting_choice.options, ["P1", "P0"] as Array[String])
	assert_ok(g.answer_choice(1))   # P0 — themselves
	assert_null(g.awaiting_choice)
	assert_eq(g.priority_player, 1, "priority stayed with the tapper")
	assert_true(g.stack.back().description.contains("Gain life., targeting P0"))
	resolve_stack()
	assert_eq(g.players[0].life, 21)
	assert_true(g.unanswered_choices.is_empty())


# -------------------------------------------------------------- Erhnam Djinn --

func test_erhnam_djinn_gifts_the_creature_its_controller_targets() -> void:
	var seat := ListSeat.new()
	seat.picks = ["Hill Giant"]
	g.set_agent(0, seat)
	put_battlefield(0, "Erhnam Djinn")
	var giant := put_battlefield(1, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	_to_own_upkeep()
	resolve_stack()
	assert_true(giant.cur_landwalk.has("forest"), "the chosen one, not the weakest")
	assert_false(bear.cur_landwalk.has("forest"))
	assert_eq(seat.offered, [["Grizzly Bears", "Hill Giant"]], "weakest first")


func test_erhnam_djinn_cannot_target_a_wall_or_a_shrouded_creature() -> void:
	var seat := ListSeat.new()
	g.set_agent(0, seat)
	put_battlefield(0, "Erhnam Djinn")
	var giant := put_battlefield(1, "Hill Giant")
	put_battlefield(1, "Wall of Stone")
	put_battlefield(1, "Grizzly Bears")
	_shroud(giant, 1)
	_to_own_upkeep()
	resolve_stack()
	assert_eq(seat.offered, [["Grizzly Bears"]])


func test_erhnam_djinn_fizzles_when_its_target_dies_in_response() -> void:
	put_battlefield(0, "Erhnam Djinn")
	var bear := put_battlefield(1, "Grizzly Bears")
	_to_own_upkeep()
	assert_eq(g.stack.size(), 1)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(_log_has("fizzles"))


func test_erhnam_djinn_with_only_walls_across_never_triggers() -> void:
	put_battlefield(0, "Erhnam Djinn")
	var wall := put_battlefield(1, "Wall of Stone")
	_to_own_upkeep()
	assert_true(g.stack.is_empty())
	assert_true(_log_has("no legal target, removed"))
	assert_false(wall.cur_landwalk.has("forest"))
