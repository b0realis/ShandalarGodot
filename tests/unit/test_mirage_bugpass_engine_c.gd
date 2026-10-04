extends GameTest
## The Mirage bug pass (Pack 8, 0.50.11), engine batch C — three findings:
##
## (a) A LAND'S ENTRY PAYMENT IS THE PLAYER'S (H5-F4). Lotus Vale and
##     Scorched Ruins ("If this land would enter, sacrifice two untapped
##     lands instead. If you do, put this land onto the battlefield. If you
##     don't, put it into its owner's graveyard.") and Pack 5's entry lands
##     (Lake of the Dead, Soldevi Excavations, …) ask which land goes from
##     inside [method MtgGame.play_land] — a special action (CR 305.1), so
##     neither the resolution pre-flight nor the cost hold reached them and
##     a human seat's questions were answered by the heuristic and ledgered.
##     `play_land` now PROBES the payment over a rewind point before anything
##     moves and holds the land drop open on the first unanswered question
##     (a `land` pending action, replayed by `answer_choice`). The player
##     may pay with the lands they pick, DECLINE (the Oracle's "if you
##     don't": the land goes to the graveyard and the drop is spent), or
##     WITHDRAW the play (`cancel_choice`, CR 728.1 — nothing was moved, the
##     land stays in hand and the drop unspent). Pinned on the engine, on the
##     local duel screen's own overlay handlers and through the SGManalink
##     referee.
## (b) A SPELL CAST FROM A GRAVEYARD IS A SPELL (H5-F2). Dense Foliage's
##     "Creatures can't be the targets of spells" stopped a spell cast from
##     the hand or sitting on the stack, but not one cast from the graveyard
##     with Bösium Strip's permission: `cast_spell` validates targets while
##     the card is still in its old zone, and CR 601.2a has already put it
##     on the stack by then (targets are chosen at 601.2c).
## (c) …AND IT NEVER TARGETS ITSELF (H5-F3, CR 115.5). A Strip-cast Relearn
##     could name itself as its "target instant or sorcery card in your
##     graveyard". An ABILITY activated from a graveyard is still an ability:
##     it may aim at its own source and a "can't be the target of spells"
##     ban does not stop it (`MtgGame.targeting_kind`).


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)
	CardPacks.set_enabled("pack-5", false)


func _human_seat(pid := 0) -> HumanAgent:
	var human := HumanAgent.new()
	g.agents[pid] = human
	g.interactive_choices = true
	return human


func _ids(cards: Array) -> Array:
	return cards.map(func(c: CardInstance) -> int: return c.id)


# =================================================== (a) the entry payment --

func test_a_lotus_vale_play_is_held_on_its_first_sacrifice_question() -> void:
	var forest := put_battlefield(0, "Forest")
	var plains := put_battlefield(0, "Plains")
	var island := put_battlefield(0, "Island")
	_human_seat(0)
	var vale := give_hand(0, "Lotus Vale")
	assert_ok(g.play_land(0, vale))
	var asked: PlayerChoice = g.awaiting_choice
	assert_not_null(asked, "the human is asked which untapped land goes first")
	if asked == null:
		return
	assert_eq(asked.pid, 0)
	assert_eq(asked.kind, PlayerChoice.Kind.CARD)
	assert_true(asked.is_cost, "held like a cost: nothing is paid until it is all known")
	assert_true(asked.optional, "the Oracle's 'if you don't' — declining is legal")
	assert_false(asked.adverse)
	assert_eq(asked.source, "Lotus Vale", "wearing the land that asked")
	assert_eq(_ids(asked.candidates), _ids([forest, plains, island]))
	# Nothing has happened yet: the land is in hand, the drop unspent, no land
	# sacrificed, nothing on the record.
	assert_eq(vale.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].lands_played_this_turn, 0)
	for land in [forest, plains, island]:
		assert_eq(land.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(g.unanswered_choices.is_empty(), "nothing decided on the seat's behalf")
	assert_true(g.choice_log.is_empty(), "and nothing on the record yet")
	assert_refused(g.pass_priority(0), "choice")


func test_a_lotus_vale_sacrifices_the_two_lands_the_player_picks() -> void:
	var forest := put_battlefield(0, "Forest")
	var plains := put_battlefield(0, "Plains")
	var island := put_battlefield(0, "Island")
	var human := _human_seat(0)
	var vale := give_hand(0, "Lotus Vale")
	assert_ok(g.play_land(0, vale))
	assert_ok(g.answer_choice(island.id))
	var second: PlayerChoice = g.awaiting_choice
	assert_not_null(second, "then which land goes second")
	if second == null:
		return
	assert_eq(_ids(second.candidates), _ids([forest, plains]), "the first pick is not offered again")
	assert_eq(vale.zone, Mtg.Zone.HAND, "still nothing moved")
	assert_eq(island.zone, Mtg.Zone.BATTLEFIELD)
	assert_ok(g.answer_choice(plains.id))
	assert_null(g.awaiting_choice, "the hold is released")
	assert_eq(vale.zone, Mtg.Zone.BATTLEFIELD, "paid for")
	assert_eq(island.zone, Mtg.Zone.GRAVEYARD, "the player's first pick")
	assert_eq(plains.zone, Mtg.Zone.GRAVEYARD, "and second")
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD, "the heuristic's first candidate stays")
	assert_eq(g.players[0].lands_played_this_turn, 1)
	assert_true(g.unanswered_choices.is_empty())
	assert_eq(g.choice_log.size(), 2, "each question on the record once")
	for c in g.choice_log:
		assert_true(c.answered_by_player)
	assert_false(human.has_parked(), "no answer is left in the mailbox")


func test_a_declined_vale_goes_to_the_graveyard_and_spends_the_drop() -> void:
	var forest := put_battlefield(0, "Forest")
	var plains := put_battlefield(0, "Plains")
	_human_seat(0)
	var vale := give_hand(0, "Lotus Vale")
	assert_ok(g.play_land(0, vale))
	assert_ok(g.answer_choice(""))
	assert_null(g.awaiting_choice)
	assert_eq(vale.zone, Mtg.Zone.GRAVEYARD, "Oracle: if you don't, put it into its owner's graveyard")
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(plains.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].lands_played_this_turn, 1, "the land WAS played")
	assert_true(g.unanswered_choices.is_empty())


func test_declining_the_second_pick_keeps_the_first_land() -> void:
	var forest := put_battlefield(0, "Forest")
	var plains := put_battlefield(0, "Plains")
	var human := _human_seat(0)
	var ruins := give_hand(0, "Scorched Ruins")
	assert_ok(g.play_land(0, ruins))
	assert_ok(g.answer_choice(plains.id))
	assert_not_null(g.awaiting_choice)
	assert_ok(g.answer_choice(""))
	assert_null(g.awaiting_choice)
	assert_eq(ruins.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(plains.zone, Mtg.Zone.BATTLEFIELD, "both lands are chosen before either is sacrificed")
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(g.unanswered_choices.is_empty())
	assert_false(human.has_parked())


func test_a_withdrawn_land_play_stays_in_hand_with_the_drop_unspent() -> void:
	var forest := put_battlefield(0, "Forest")
	var plains := put_battlefield(0, "Plains")
	var human := _human_seat(0)
	var vale := give_hand(0, "Lotus Vale")
	assert_ok(g.play_land(0, vale))
	assert_ok(g.answer_choice(forest.id))
	assert_not_null(g.awaiting_choice)
	assert_ok(g.cancel_choice())   # the player's own land play can be backed out of
	assert_null(g.awaiting_choice)
	assert_eq(vale.zone, Mtg.Zone.HAND, "the land never left the hand")
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(plains.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].lands_played_this_turn, 0)
	assert_true(g.land_drop_available(0))
	assert_false(human.has_parked(), "the first answer was dropped with the play")
	assert_true(g.choice_log.is_empty())
	# And the drop is still there: a plain land goes down unasked.
	var mountain := give_hand(0, "Mountain")
	assert_ok(g.play_land(0, mountain))
	assert_eq(mountain.zone, Mtg.Zone.BATTLEFIELD)


func test_a_vale_with_one_untapped_land_asks_nothing() -> void:
	var forest := put_battlefield(0, "Forest")
	_human_seat(0)
	var vale := give_hand(0, "Lotus Vale")
	assert_ok(g.play_land(0, vale))
	assert_null(g.awaiting_choice, "there is nothing to choose")
	assert_eq(vale.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(g.choice_log.is_empty())


func test_a_seat_that_answers_itself_is_never_held() -> void:
	# The heuristic and AI seats are never asked: the Vale pays at once, as
	# it always did (tests/cards/test_pack_8_b9_lands.gd).
	var forest := put_battlefield(0, "Forest")
	var plains := put_battlefield(0, "Plains")
	g.interactive_choices = true
	var vale := give_hand(0, "Lotus Vale")
	assert_ok(g.play_land(0, vale))
	assert_null(g.awaiting_choice)
	assert_eq(vale.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(plains.zone, Mtg.Zone.GRAVEYARD)


func test_a_pack_5_entry_land_is_the_players_own_choice_too() -> void:
	CardPacks.set_enabled("pack-5", true)   # Alliances
	CardRegistry.ensure_loaded()
	var first := put_battlefield(0, "Swamp")
	var second := put_battlefield(0, "Swamp")
	_human_seat(0)
	var lake := give_hand(0, "Lake of the Dead")
	assert_ok(g.play_land(0, lake))
	var asked: PlayerChoice = g.awaiting_choice
	assert_not_null(asked, "which Swamp is the player's")
	if asked == null:
		return
	assert_true(asked.optional)
	assert_true(asked.is_cost)
	assert_false(asked.adverse, "the seat chooses for itself, so it may back out")
	assert_eq(lake.zone, Mtg.Zone.HAND)
	assert_ok(g.answer_choice(second.id))
	assert_null(g.awaiting_choice)
	assert_eq(lake.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD, "the Swamp the player named")
	assert_eq(first.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(g.unanswered_choices.is_empty())


# ------------------------------------------- the same, on the duel screen --

var _screen: DuelScreen


func _open_screen() -> MtgGame:
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 0.0
	_screen = load("res://game/duel/duel_screen.tscn").instantiate()
	_screen.config = config
	add_child_autofree(_screen)
	await get_tree().process_frame
	var sg: MtgGame = _screen.game
	sg.players[0].hand.clear()
	sg.players[1].hand.clear()
	# Our own first main phase, with priority (the screen's own pins do the
	# same: tests/ui/test_pack_8_choice_flows.gd `_window`).
	sg._probing = true
	sg.active_player = 0
	sg._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	sg.priority_player = 0
	sg._passes = 0
	sg._probing = false
	_screen.mode = DuelScreen.Mode.NORMAL
	return sg


func _screen_card(sg: MtgGame, card_name: String, zone: int) -> CardInstance:
	var inst := CardInstance.new(CardRegistry.get_card(card_name), sg._next_instance_id, 0)
	sg._next_instance_id += 1
	sg._probing = true
	sg._instances[inst.id] = inst
	if zone == Mtg.Zone.HAND:
		inst.zone = Mtg.Zone.HAND
		sg.players[0].hand.append(inst)
	else:
		sg._put_on_battlefield(inst, 0)
	sg.recalculate()
	sg._probing = false
	return inst


func _overlay_line(choice: PlayerChoice, inst: CardInstance) -> int:
	var lines := DuelScreen.choice_card_lines(choice)
	for i in lines.size():
		if lines[i]["answer"] is int and int(lines[i]["answer"]) == inst.id:
			return i
	return -1


func test_the_duel_screen_pays_a_vale_with_the_lands_the_player_clicks() -> void:
	var sg: MtgGame = await _open_screen()
	var forest := _screen_card(sg, "Forest", Mtg.Zone.BATTLEFIELD)
	var plains := _screen_card(sg, "Plains", Mtg.Zone.BATTLEFIELD)
	var island := _screen_card(sg, "Island", Mtg.Zone.BATTLEFIELD)
	var vale := _screen_card(sg, "Lotus Vale", Mtg.Zone.HAND)
	_screen._click_hand_card(vale)
	var held: PlayerChoice = sg.awaiting_choice
	assert_not_null(held, "the screen's land click is held on the question")
	if held == null:
		return
	# The decline line says what declining COSTS — not "Cancel.", which sat
	# beside the Cancel button that withdraws the play (DuelScreen._decline_label).
	assert_eq(DuelScreen.choice_options(held, _screen._decline_label(held)).back(),
		"Put Lotus Vale into its owner's graveyard.", "the overlay offers the decline")
	assert_true(_screen._choice_withdrawable(), "and the Cancel button that withdraws the play")
	_screen._on_choice_option(_overlay_line(held, island))
	assert_not_null(sg.awaiting_choice)
	_screen._on_choice_option(_overlay_line(sg.awaiting_choice, forest))
	assert_null(sg.awaiting_choice)
	assert_eq(vale.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(island.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(plains.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(sg.unanswered_choices.is_empty())


func test_the_duel_screen_can_decline_or_withdraw_a_vale() -> void:
	var sg: MtgGame = await _open_screen()
	var forest := _screen_card(sg, "Forest", Mtg.Zone.BATTLEFIELD)
	var plains := _screen_card(sg, "Plains", Mtg.Zone.BATTLEFIELD)
	var vale := _screen_card(sg, "Lotus Vale", Mtg.Zone.HAND)
	# Withdraw: the Cancel button.
	_screen._click_hand_card(vale)
	assert_not_null(sg.awaiting_choice)
	_screen._withdraw_choice()
	assert_null(sg.awaiting_choice)
	assert_eq(vale.zone, Mtg.Zone.HAND, "withdrawn: back in hand")
	assert_eq(sg.players[0].lands_played_this_turn, 0)
	# Decline: the overlay's last line.
	_screen._click_hand_card(vale)
	var held: PlayerChoice = sg.awaiting_choice
	assert_not_null(held)
	if held == null:
		return
	var lines := DuelScreen.choice_options(held, _screen._decline_label(held))
	assert_eq(lines.back(), "Put Lotus Vale into its owner's graveyard.")
	_screen._on_choice_option(lines.size() - 1)   # the decline: the last line
	assert_null(sg.awaiting_choice)
	assert_eq(vale.zone, Mtg.Zone.GRAVEYARD, "declined: into the graveyard")
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(plains.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(sg.unanswered_choices.is_empty())


# -------------------------------------- the same, at an SGManalink table --

func test_the_sgmanalink_referee_asks_declines_and_withdraws_an_entry_payment() -> void:
	var referee := SgPracticeMatch.new(42)
	referee.game = g
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	var forest := put_battlefield(0, "Forest")
	var plains := put_battlefield(0, "Plains")
	var vale := give_hand(0, "Lotus Vale")
	assert_ok(referee.act(0, {"op": "play", "card": referee._handle(0, vale)}))
	var view: Dictionary = referee.actions.choice_view(0)
	assert_false(view.is_empty(), "the seat is shown the question")
	if view.is_empty():
		return
	assert_true(bool(view["cancel"]), "with a Cancel that withdraws the play")
	assert_eq(String((view["options"] as Array).back()), "Put Lotus Vale into its owner's graveyard.",
		"and a decline line that says what declining costs (SgDuelActions.decline_label)")
	# Withdraw.
	assert_ok(referee.act(0, {"op": "cancel"}))
	assert_null(g.awaiting_choice)
	assert_eq(vale.zone, Mtg.Zone.HAND)
	# Pay: two picks, whichever the lines are.
	assert_ok(referee.act(0, {"op": "play", "card": referee._handle(0, vale)}))
	assert_ok(referee.act(0, {"op": "choice", "picks": [0]}))
	assert_ok(referee.act(0, {"op": "choice", "picks": [0]}))
	assert_null(g.awaiting_choice)
	assert_eq(vale.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(plains.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.unanswered_choices.is_empty())


func test_the_sgmanalink_referee_declines_an_entry_payment() -> void:
	var referee := SgPracticeMatch.new(42)
	referee.game = g
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	put_battlefield(0, "Forest")
	put_battlefield(0, "Plains")
	var ruins := give_hand(0, "Scorched Ruins")
	assert_ok(referee.act(0, {"op": "play", "card": referee._handle(0, ruins)}))
	var options: Array = referee.actions.choice_view(0).get("options", [])
	assert_false(options.is_empty())
	assert_ok(referee.act(0, {"op": "choice", "picks": [options.size() - 1]}))
	assert_null(g.awaiting_choice)
	assert_eq(ruins.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.unanswered_choices.is_empty())


# ========================================= (b)+(c) a spell cast from a graveyard --

func _to_graveyard(pid: int, card_name: String) -> CardInstance:
	var inst := give_hand(pid, card_name)
	g.card_to_graveyard_from_anywhere(inst)
	return inst


func _strip(pid: int) -> void:
	var strip := put_battlefield(pid, "Bösium Strip")
	add_mana(pid, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(pid, strip, 0))
	resolve_stack()


func test_b_dense_foliage_stops_a_graveyard_cast_bolt() -> void:
	put_battlefield(1, "Dense Foliage")
	var bear := put_battlefield(1, "Grizzly Bears")
	_strip(0)
	var bolt := _to_graveyard(0, "Lightning Bolt")
	assert_true(g.can_cast_from_graveyard(0, bolt), "precondition: the Strip's permission")
	var spec: TargetSpec = bolt.data.spell_effects[0].target_spec
	assert_eq(spec.refusal_reason(g, TargetRef.card(bear), bolt), TargetSpec.WHY["spell"],
		"CR 601.2a: it is a spell on the stack before its targets are chosen")
	assert_false(spec.legal_targets(g, bolt).any(func(r: TargetRef) -> bool:
		return r.instance_id == bear.id), "the Bears are not offered")
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD, "a refused cast leaves it where it was")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	# The player is still a legal target, wherever the Bolt is cast from.
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 17)


func test_b_a_graveyard_ability_is_not_a_spell() -> void:
	# An ABILITY activated from the graveyard is still an ability: "can't be
	# the targets of spells" does not stop it, and it may aim at its own
	# source (CR 115.5 bars only the object on the stack from targeting itself).
	put_battlefield(1, "Dense Foliage")
	var bear := put_battlefield(1, "Grizzly Bears")
	var data := CardData.new("Test Grave Sniper", "{1}", Mtg.CardType.CREATURE).pt(1, 1)
	data.activated(ActivatedAbility.new("{1}", false, [DamageEffect.new(1).target_creature()],
		"{1}: This card deals 1 damage to target creature. Activate only from your graveyard.").from_graveyard())
	var regrow := ReturnFromGraveyardEffect.new()
	regrow.target_spec = TargetSpec.new(TargetSpec.Kind.CARD_IN_YOUR_GRAVEYARD, "target card in your graveyard")
	data.activated(ActivatedAbility.new("{1}", false, [regrow],
		"{1}: Return target card from your graveyard to your hand. Activate only from your graveyard.").from_graveyard())
	var sniper := give_synthetic(0, data)
	g.card_to_graveyard_from_anywhere(sniper)
	assert_eq(sniper.zone, Mtg.Zone.GRAVEYARD)
	var shot: TargetSpec = data.activated_abilities[0].effects[0].target_spec
	assert_eq(shot.refusal_reason(g, TargetRef.card(bear), sniper), "",
		"Dense Foliage does not stop an ability")
	var dig: TargetSpec = data.activated_abilities[1].effects[0].target_spec
	assert_eq(dig.refusal_reason(g, TargetRef.card(sniper), sniper), "",
		"an ability may target its own source")


func test_c_a_graveyard_cast_relearn_cannot_target_itself() -> void:
	var bolt := _to_graveyard(0, "Lightning Bolt")
	_strip(0)
	var relearn := _to_graveyard(0, "Relearn")
	assert_true(g.can_cast_from_graveyard(0, relearn), "precondition: Relearn is on top")
	var spec: TargetSpec = relearn.data.spell_effects[0].target_spec
	assert_eq(spec.refusal_reason(g, TargetRef.card(relearn), relearn), TargetSpec.WHY["cant_target"],
		"CR 115.5: a spell is never a legal target for itself")
	var legal := spec.legal_targets(g, relearn)
	assert_false(legal.any(func(r: TargetRef) -> bool: return r.instance_id == relearn.id))
	assert_true(legal.any(func(r: TargetRef) -> bool: return r.instance_id == bolt.id),
		"the Bolt beneath it is still a legal target")
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_refused(g.cast_spell(0, relearn, [TargetRef.card(relearn)]))
	assert_eq(relearn.zone, Mtg.Zone.GRAVEYARD)
	assert_ok(g.cast_spell(0, relearn, [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.HAND, "Relearn returned the Bolt")
	assert_eq(relearn.zone, Mtg.Zone.EXILE, "and, cast from the graveyard by the Strip, was exiled")
