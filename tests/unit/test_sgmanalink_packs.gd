extends GameTest
## Pack mechanics must cross the referee boundary without client simulation.

func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-3", true)
	CardPacks.set_enabled("pack-5", true)
	super()

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func referee() -> SgPracticeMatch:
	var duel := SgPracticeMatch.new(42)
	duel.game = g
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	g.interactive_choices = true
	duel.view(0)
	return duel

func room(duel: SgPracticeMatch, seat: int) -> Dictionary:
	return {"id": "r1", "name": "Pack integration", "seat": seat,
		"names": ["One", "Two"], "revision": 1, "ready": [true, true],
		"connected": [true, true], "game": duel.view(seat),
		"deck_names": duel.deck_names.duplicate(), "deck": {}}

func prepare(duel: SgPracticeMatch, pid: int, card: CardInstance, kind := "spell", mode := 0) -> String:
	return duel.act(pid, {"op": "prepare", "card": duel._handle(pid, card),
		"kind": kind, "index": 0, "x": 0, "mode": mode})

func test_fingerprint_tracks_pack_toggles_and_returns_to_same_catalogue() -> void:
	var enabled := SgCompatibility.fingerprint()
	CardPacks.set_enabled("pack-5", false)
	var disabled := SgCompatibility.fingerprint()
	assert_ne(enabled, disabled, "disabling Alliances must change the handshake")
	CardPacks.set_enabled("pack-5", true)
	assert_eq(SgCompatibility.fingerprint(), enabled, "same catalogue, not reload count")
	CardPacks.rescan()
	assert_eq(SgCompatibility.fingerprint(), enabled, "rescan with identical content")

func test_pitch_payment_and_atomic_private_choice_use_selected_mode() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_ok(g.pass_priority(0))
	var force := give_hand(1, "Force of Will")
	var crow := give_hand(1, "Storm Crow")
	var duel := referee()
	assert_ok(prepare(duel, 1, force, "spell", 1))
	assert_eq(str(duel.actions.payment().cost), "{0}", "pitch announcement must not demand {3}{U}{U}")
	assert_true(duel.actions.payment_reachable())
	assert_true(duel.view(1).presentation.respond, "zero-mana pitch is a response")
	var target: String = duel.view(1).announcement.slots[0].targets[0].id
	assert_ok(duel.act(1, {"op": "submit", "targets": [[target, 1]]}))
	assert_eq(force.zone, Mtg.Zone.HAND)
	assert_eq(g.players[1].life, 20)
	assert_true(duel.view(0).choice.is_empty(), "pitch identity stays private until paid")
	assert_ok(duel.act(1, {"op": "cancel"}))
	assert_eq(crow.zone, Mtg.Zone.HAND)
	assert_eq(g.players[1].life, 20)
	assert_ok(prepare(duel, 1, force, "spell", 1))
	target = duel.view(1).announcement.slots[0].targets[0].id
	assert_ok(duel.act(1, {"op": "submit", "targets": [[target, 1]]}))
	assert_ok(duel.act(1, {"op": "choice", "picks": [0]}))
	assert_eq(force.zone, Mtg.Zone.STACK)
	assert_eq(crow.zone, Mtg.Zone.EXILE)
	assert_eq(g.players[1].life, 19)

func test_graveyard_activation_is_offered_only_in_its_source_zone() -> void:
	var ghoul := put_battlefield(0, "Ashen Ghoul")
	assert_true(SgDuelActions.options(ghoul, 0).is_empty(), "not a battlefield ability")
	g.sacrifice_permanent(ghoul)
	for i in 3: g.sacrifice_permanent(put_battlefield(0, "Grizzly Bears"))
	g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.UPKEEP)
	add_mana(0, Mtg.ManaColor.B)
	var duel := referee()
	assert_eq(duel._cards(0, [ghoul])[0].actions.size(), 1)
	assert_true(duel._cards(1, [ghoul])[0].actions.is_empty())
	var error := prepare(duel, 0, ghoul, "ability")
	assert_ok(error)
	if not error.is_empty(): return
	assert_ok(duel.act(0, {"op": "submit", "targets": []}))
	resolve_stack()
	assert_eq(ghoul.zone, Mtg.Zone.BATTLEFIELD)

func test_spirit_guide_mana_is_offered_from_hand_not_battlefield() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var guide := give_hand(0, "Elvish Spirit Guide")
	var duel := referee()
	var mana := SgDuelActions.options(guide, 0).filter(func(option: Dictionary) -> bool: return option.kind == "mana")
	assert_eq(mana.size(), 1, "the hand menu must expose the exiling mana ability")
	assert_true(SgDuelActions.options(guide, 1).is_empty())
	assert_ok(duel.act(0, {"op": "mana", "card": duel._handle(0, guide), "index": 0}))
	assert_eq(guide.zone, Mtg.Zone.EXILE)
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.G), 1)
	var permanent := put_battlefield(0, "Elvish Spirit Guide")
	mana = SgDuelActions.options(permanent, 0).filter(func(option: Dictionary) -> bool: return option.kind == "mana")
	assert_true(mana.is_empty(), "cannot exile a battlefield Guide as a hand cost")

func test_all_six_pack_catalogues_cross_the_strict_card_dto_boundary() -> void:
	for id in CardPacks.available_ids(): assert_true(CardPacks.set_enabled(id, true))
	assert_eq(CardRegistry.size(), 1898)
	var duel := referee()
	for name in CardRegistry.all_names():
		var card := CardInstance.new(CardRegistry.get_card(name), 90000, 0)
		card.zone = Mtg.Zone.HAND
		var cards := duel._cards(0, [card])
		var decoded := SgProtocol.decode_payload(SgProtocol.encode({"cards": cards}).to_utf8_buffer())
		assert_true(SgViewProtocol.cards(decoded.cards), name)
		assert_eq(SgCardPresentation.make(decoded.cards[0], 0, Mtg.Zone.HAND).data.card_name, name)

func test_tournament_checkpoint_requires_the_same_enabled_packs() -> void:
	var event := SgTournament.new()
	assert_eq(event.configure({"name": "Pack tournament", "limit": 8, "wins": 1, "policy": "own", "decks": []}, 42), "")
	var checkpoint := event.checkpoint()
	CardPacks.set_enabled("pack-5", false)
	assert_string_contains(SgTournament.new().restore(checkpoint), "enabled card packs")
	CardPacks.set_enabled("pack-5", true)
	assert_eq(SgTournament.new().restore(checkpoint), "")

func test_bottle_land_is_playable_and_exile_permission_reaches_projection() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bottle := put_battlefield(0, "Elkin Bottle")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, bottle, 0))
	resolve_stack()
	var land: CardInstance = g.players[0].exile.back()
	var duel := referee()
	var dto := room(duel, 0)
	assert_true(SgViewProtocol.room(dto))
	var projection := SgDuelProjection.new()
	projection.ingest(dto)
	assert_true(projection.can_play_from_exile(0, projection.players[0].exile[0]))
	assert_true(dto.game.players[0].exile[0].playable)
	assert_ok(duel.act(0, {"op": "play", "card": duel._handle(0, land)}))
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD)

func test_private_exile_is_named_only_for_authorized_viewer() -> void:
	var card := give_hand(0, "Storm Crow")
	g.exile_from_hand(card)
	card.face_down = true
	card.exile_visible_to = 0
	var duel := referee()
	assert_eq(duel.view(0).players[0].exile[0].name, "Storm Crow")
	assert_eq(duel.view(1).players[0].exile[0].name, "Face-down card")
	assert_true(SgViewProtocol.game(duel.view(0)))
	assert_true(SgViewProtocol.game(duel.view(1)))
	card.exile_visible_to = -1
	assert_eq(duel.view(0).players[0].exile[0].name, "Face-down card")

func test_melee_changes_actor_block_matrix_and_projection_chooser() -> void:
	var attacker := put_battlefield(0, "Hill Giant")
	var blocker := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	var melee := give_hand(0, "Melee")
	add_mana(0, Mtg.ManaColor.R, 5)
	assert_ok(g.cast_spell(0, melee))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	var duel := referee()
	assert_eq(duel.decision_state().actor, 0)
	var dto := room(duel, 0)
	assert_true(SgViewProtocol.room(dto))
	assert_false(dto.game.presentation.blockable.is_empty())
	var projection := SgDuelProjection.new()
	projection.ingest(dto)
	assert_eq(projection.block_chooser(), 0)
	assert_refused(duel.act(1, {"op": "block", "pairs": []}))
	assert_ok(duel.act(0, {"op": "block", "pairs": [[duel._handle(0, blocker), duel._handle(0, attacker)]]}))
	assert_eq(g.combat.blocks.get(blocker.id), attacker.id)

func test_network_bot_scheduler_lets_melee_attacker_choose_opposing_blocks() -> void:
	var attacker := put_battlefield(0, "Scaled Wurm")
	var blocker := put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	var melee := give_hand(0, "Melee")
	add_mana(0, Mtg.ManaColor.R, 5)
	assert_ok(g.cast_spell(0, melee))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	var duel := referee()
	var pilot := SgBotPlayer.create(0, SgBotPlayer.defaults())
	g.set_agent(0, pilot)
	SgBotPlayer.step(duel, pilot)
	assert_false(g.awaiting_blockers)
	assert_eq(g.combat.blocks.get(blocker.id), attacker.id)

func test_repeated_additional_payment_is_an_announced_variable() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var spell := give_hand(0, "Taste of Paradise")
	add_mana(0, Mtg.ManaColor.G, 3)
	add_mana(0, Mtg.ManaColor.C, 5)
	var duel := referee()
	assert_true(SgDuelActions.options(spell, 0)[0].x)
	assert_eq(SgPayment.budget(g, 0, spell, "spell", 0, ManaPlanner.sources(g, 0)), 2)
	var error := duel.act(0, {"op": "prepare", "card": duel._handle(0, spell), "kind": "spell", "index": 0, "x": 2, "mode": 0})
	assert_ok(error)
	if not error.is_empty(): return
	assert_ok(duel.act(0, {"op": "submit", "targets": []}))
	assert_eq(g.players[0].mana_pool.total(), 0)
	resolve_stack()
	assert_eq(g.players[0].life, 29)

func test_life_x_is_bounded_and_never_auto_announced() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	g.players[0].life = 17
	var spell := give_hand(0, "Fire Covenant")
	for color in [Mtg.ManaColor.B, Mtg.ManaColor.R, Mtg.ManaColor.C]: add_mana(0, color)
	var duel := referee()
	assert_eq(SgPayment.budget(g, 0, spell, "spell", 0, ManaPlanner.sources(g, 0)), 17)
	assert_refused(duel.act(0, {"op": "autoprepare", "card": duel._handle(0, spell), "kind": "spell", "index": 0, "mode": 0, "excluded": [], "count": 1}))
	assert_true(duel.actions.draft.is_empty())
	assert_eq(g.players[0].life, 17)
	assert_eq(g.players[0].mana_pool.total(), 3)

func test_floating_mana_substitutions_reach_the_host_payment_budget() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Sunglasses of Urza")
	var spell := give_hand(0, "Disintegrate")
	add_mana(0, Mtg.ManaColor.W, 5)
	var duel := referee()
	assert_eq(SgPayment.budget(g, 0, spell, "spell", 0, ManaPlanner.sources(g, 0)), 4)
	assert_ok(duel.act(0, {"op": "prepare", "card": duel._handle(0, spell), "kind": "spell", "index": 0, "x": 4, "mode": 0}))
	assert_true(duel.actions.payment_reachable())

func test_auto_repetitions_respect_reserved_colored_sources() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var spell := give_hand(0, "Taste of Paradise")
	var reserved: Array[CardInstance] = []
	for i in 3:
		var forest := put_battlefield(0, "Forest")
		if i < 2: reserved.append(forest)
	for i in 5: put_battlefield(0, "Mountain")
	var duel := referee()
	var excluded: Array = []
	for land in reserved: excluded.append(duel._handle(0, land))
	assert_ok(duel.act(0, {"op": "autoprepare", "card": duel._handle(0, spell), "kind": "spell", "index": 0, "mode": 0, "excluded": excluded, "count": 1}))
	assert_eq(duel.actions.draft.x, 0, "no spare green after the base payment")
	for land in reserved: assert_false(land.tapped)
	assert_ok(duel.act(0, {"op": "submit", "targets": []}))
	resolve_stack()
	assert_eq(g.players[0].life, 23)

func test_north_star_floating_permission_is_for_spells_not_abilities() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	g.players[0].any_color_spells = 1
	add_mana(0, Mtg.ManaColor.G, 3)
	var spell := give_hand(0, "Disintegrate")
	var shade := put_battlefield(0, "Frozen Shade")
	assert_eq(SgPayment.budget(g, 0, spell, "spell", 0, ManaPlanner.sources(g, 0)), 2)
	assert_true(SgPayment.can_pay_now(g, 0, SgPayment.due(g, 0, spell, "spell", 0, 2), "spell"))
	assert_false(SgPayment.can_pay_now(g, 0, SgPayment.due(g, 0, shade, "ability", 0, 0), "ability"))
	assert_eq(g.players[0].any_color_spells, 1, "an estimate never consumes the charge")
