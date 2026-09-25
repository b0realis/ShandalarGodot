extends GameTest
## Full-pool announcements use real rules APIs, including private questions.

func _match() -> SgPracticeMatch:
	var duel := SgPracticeMatch.new(42)
	duel.game = g
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	g.interactive_choices = true
	duel.view(0)
	return duel


func _prepare(duel: SgPracticeMatch, card: CardInstance, kind := "spell", index := 0, x := 0, mode := 0) -> Dictionary:
	assert_ok(duel.act(card.controller_id, {"op": "prepare", "card": duel._handle(card.controller_id, card),
		"kind": kind, "index": index, "x": x, "mode": mode}))
	return duel.view(card.controller_id).announcement


func _target(request: Dictionary, label: String, slot := 0) -> String:
	for target in request.slots[slot].targets:
		if target.label.contains(label): return target.id
	fail_test("Target not offered: " + label)
	return "missing"


func _resolve_until_question() -> void:
	for i in 20:
		if g.stack.is_empty() or g.awaiting_choice != null: return
		assert_ok(g.pass_priority(g.priority_player))
	fail_test("Resolution did not reach a decision")


func test_registry_wide_presentation_roundtrips_every_printed_card() -> void:
	var duel := _match()
	var names := CardRegistry.all_names()
	assert_gt(names.size(), 890)
	for card_name in names:
		var card := CardInstance.new(CardRegistry.get_card(card_name), 90000, 0)
		card.zone = Mtg.Zone.HAND
		var cards := duel._cards(0, [card])
		var decoded := SgProtocol.decode_payload(SgProtocol.encode({"cards": cards}).to_ascii_buffer())
		assert_true(SgViewProtocol.cards(decoded.cards), card_name)
		assert_eq(SgCardPresentation.make(decoded.cards[0], 0, Mtg.Zone.HAND).data.card_name, card_name)
	assert_gt(SgDeckCatalog.available().size(), 100)


func test_a_deck_row_s_group_is_its_shelf_or_the_player_s_own_folder() -> void:
	# The lobby's tooltip: a shipped deck names its shelf under the
	# shipped folder; a deck of the player's own names the folder as the
	# player sees it, not the literal `user://decks` (2026-09-17, item 6).
	assert_eq(SgDeckCatalog._group(DeckStore.SHIPPED_DIR + "/1997/knights.deck"), "/1997")
	assert_eq(SgDeckCatalog._group(DeckStore.SHIPPED_DIR + "/tournament/x/y.deck"), "/tournament/x")
	var own := SgDeckCatalog._group(DeckStore.USER_DIR + "/mine.deck")
	assert_false(own.begins_with("user://"), own)
	assert_eq(own, GamePaths.shown(DeckStore.USER_DIR))
	# A friendly table is casual since 2026-09-24 (eight cards and a
	# warning); the tournament's referee still asks for forty.
	assert_true(SgDeckCatalog.validate([]).begins_with("Choose a deck with %d-250 cards" % DeckModel.CASUAL_MIN_CARDS))
	assert_true(SgDeckCatalog.validate([], [], false).begins_with("Choose a deck with %d-250 cards" % DeckModel.MIN_CARDS))


func test_targeted_spell_counterspell_and_private_announcements() -> void:
	var duel := _match()
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	var counter := give_hand(1, "Counterspell")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(1, Mtg.ManaColor.U, 2)
	var request := _prepare(duel, bolt)
	assert_true(duel.view(1).announcement.is_empty())
	assert_refused(duel.act(0, {"op": "submit", "targets": [["t9999", 1]]}))
	assert_eq(bolt.zone, Mtg.Zone.HAND)
	assert_ok(duel.act(0, {"op": "submit", "targets": [[_target(request, "Grizzly Bears"), 1]]}))
	assert_true(duel.view(1).stack.back().targets[0].contains("Grizzly Bears"))
	assert_false(duel.view(1).stack.back().targets[0].contains("points"), "nondivided damage is not a target allocation")
	assert_true(SgViewProtocol.game(duel.view(1)))
	assert_ok(duel.act(0, {"op": "pass"}))
	request = _prepare(duel, counter)
	assert_ok(duel.act(1, {"op": "submit", "targets": [[_target(request, "Lightning Bolt"), 1]]}))
	_resolve_until_question()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.damage, 0)


func test_aura_modal_spell_x_and_regeneration_activation() -> void:
	var duel := _match()
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := give_hand(0, "Holy Strength")
	add_mana(0, Mtg.ManaColor.W, 2)
	var request := _prepare(duel, aura)
	assert_ok(duel.act(0, {"op": "submit", "targets": [[_target(request, "Grizzly Bears"), 1]]}))
	_resolve_until_question()
	assert_eq(bear.cur_power, 3)
	assert_false(duel.view(0).players[0].battlefield[1].attached.is_empty())
	var salve := give_hand(0, "Healing Salve")
	request = _prepare(duel, salve, "spell", 0, 0, 0)
	assert_ok(duel.act(0, {"op": "submit", "targets": [[_target(request, "You"), 1]]}))
	_resolve_until_question()
	assert_eq(g.players[0].life, 23)
	var skeleton := put_battlefield(0, "Drudge Skeletons")
	add_mana(0, Mtg.ManaColor.B)
	_prepare(duel, skeleton, "ability")
	assert_ok(duel.act(0, {"op": "submit", "targets": []}))
	_resolve_until_question()
	assert_eq(skeleton.regeneration_shields, 1)
	var fireball := give_hand(0, "Fireball")
	add_mana(0, Mtg.ManaColor.R, 5)
	request = _prepare(duel, fireball, "spell", 0, 4)
	assert_ok(duel.act(0, {"op": "submit", "targets": [[_target(request, "Opponent"), 4]]}))
	_resolve_until_question()
	assert_eq(g.players[1].life, 16)


func test_tutor_choices_hide_order_and_validate_answers_before_engine() -> void:
	var duel := _match()
	advance_to_step(Mtg.Step.MAIN1)
	var tutor := give_hand(0, "Demonic Tutor")
	add_mana(0, Mtg.ManaColor.B, 2)
	_prepare(duel, tutor)
	assert_ok(duel.act(0, {"op": "submit", "targets": []}))
	_resolve_until_question()
	assert_not_null(g.awaiting_choice)
	var question: Dictionary = duel.view(0).choice
	assert_eq(question.options, ["Forest", "Choose none"])
	assert_true(duel.view(1).choice.is_empty())
	assert_refused(duel.act(1, {"op": "choice", "picks": [0]}))
	assert_refused(duel.act(0, {"op": "choice", "picks": [999]}))
	assert_not_null(g.awaiting_choice)
	assert_ok(duel.act(0, {"op": "choice", "picks": [0]}))
	_resolve_until_question()
	assert_eq(g.players[0].hand.back().data.card_name, "Forest")
	assert_false(SgProtocol.encode(duel.view(1)).contains("Demonic Tutor searches"))


func test_masked_cards_hide_printed_identity_and_retire_hidden_handles() -> void:
	var angel := put_battlefield(0, "Serra Angel")
	g.turn_face_down(angel)
	# The fixture starts concealed; a real prior public reveal belongs in history.
	var duel := _match()
	var view := duel.view(1)
	assert_false(SgProtocol.encode(view).contains("Serra Angel"))
	assert_eq(view.players[0].battlefield[0].name, "Face-down creature")
	var old: String = view.players[0].battlefield[0].id
	g.return_to_hand(angel)
	duel.view(1)
	assert_null(duel._card(1, old))
	assert_false(SgProtocol.encode(duel.view(1)).contains("Serra Angel"))


func test_private_information_effects_disclose_only_to_the_authorized_seat() -> void:
	var duel := _match()
	var glasses := put_battlefield(0, "Glasses of Urza")
	give_hand(1, "Shivan Dragon")
	var request := _prepare(duel, glasses, "ability")
	assert_ok(duel.act(0, {"op": "submit", "targets": [[_target(request, "Opponent"), 1]]}))
	_resolve_until_question()
	assert_string_contains(JSON.stringify(duel.view(0).information), "Shivan Dragon")
	assert_true(duel.view(1).information.is_empty())


func test_preflight_reveal_arrives_before_the_related_question_not_after_it() -> void:
	var duel := _match()
	advance_to_step(Mtg.Step.MAIN1)
	var card := give_hand(0, "Visions")
	add_mana(0, Mtg.ManaColor.W)
	var request := _prepare(duel, card)
	assert_ok(duel.act(0, {"op": "submit", "targets": [[_target(request, "Opponent"), 1]]}))
	_resolve_until_question()
	var shown: Dictionary = duel.view(0).choice
	assert_eq(shown.information.size(), 1)
	assert_eq(shown.information[0].cards.size(), 5)
	assert_true(duel.view(1).choice.is_empty())
	assert_true(duel.view(1).information.is_empty())
	assert_ok(duel.act(0, {"op": "choice", "picks": [1]}))
	assert_true(duel.view(1).information.is_empty())
	assert_eq(duel.view(0).information.size(), 1)


func test_face_down_exile_reveals_neither_types_nor_stats() -> void:
	var duel := _match()
	var card := give_hand(0, "Shivan Dragon")
	g.put_from_hand_on_top_of_library(card)
	g.exile_top_of_library(0)
	var view: Dictionary = duel.view(1)
	assert_false(JSON.stringify(view).contains("Shivan"))
	assert_eq(view.players[0].exile[0].power, 0)
	assert_eq(view.players[0].exile[0].colors, 0)
	assert_eq(view.players[0].exile[0].types, 0)
	assert_true(view.players[0].exile[0].keywords.is_empty())


func test_mana_sacrifice_and_divided_targets_use_engine_validation() -> void:
	var duel := _match()
	advance_to_step(Mtg.Step.MAIN1)
	var altar := put_battlefield(0, "Ashnod's Altar")
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Grizzly Bears")
	_prepare(duel, altar, "mana")
	assert_ok(duel.act(0, {"op": "submit", "targets": []}))
	var question: Dictionary = duel.view(0).choice
	assert_eq(question.options.size(), 2)
	assert_ne(question.options[0], question.options[1])
	assert_ok(duel.act(0, {"op": "choice", "picks": [1]}))
	assert_eq(g.players[0].mana_pool.total(), 2)
	var pyro := give_hand(0, "Pyrotechnics")
	add_mana(0, Mtg.ManaColor.R, 5)
	var target := put_battlefield(1, "Craw Wurm")
	var request := _prepare(duel, pyro)
	var points := [[_target(request, "Opponent"), 2], [_target(request, "Craw Wurm"), 2]]
	assert_ok(duel.act(0, {"op": "submit", "targets": points}))
	assert_true(duel.view(1).stack.back().targets[0].contains("2 points"))
	_resolve_until_question()
	assert_eq(target.damage, 2)
	assert_eq(g.players[1].life, 18)


func test_targets_are_enumerated_at_announced_x_and_specials_check_priority() -> void:
	var duel := _match()
	advance_to_step(Mtg.Step.MAIN1)
	var ring := put_battlefield(1, "Sol Ring")
	var detonate := give_hand(0, "Detonate")
	add_mana(0, Mtg.ManaColor.R, 2)
	var request := _prepare(duel, detonate, "spell", 0, 1)
	assert_ok(duel.act(0, {"op": "submit", "targets": [[_target(request, "Sol Ring"), 1]]}))
	_resolve_until_question()
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)
	var channel := give_hand(0, "Channel")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(duel.act(0, {"op": "play", "card": duel._handle(0, channel)}))
	_resolve_until_question()
	assert_eq(duel.view(0).specials.size(), 1)
	assert_ok(duel.act(0, {"op": "special", "index": 0}))
	assert_eq(g.players[0].life, 19)
	assert_eq(g.players[0].mana_pool.total(), 1)
	assert_ok(duel.act(0, {"op": "pass"}))
	assert_refused(duel.act(0, {"op": "special", "index": 0}))


func test_revelation_discloses_hands_only_while_active() -> void:
	var duel := _match()
	give_hand(1, "Counterspell")
	assert_true(duel.view(0).players[1].revealed.is_empty())
	var revelation := put_battlefield(0, "Revelation")
	var revealed: Array = duel.view(0).players[1].revealed
	assert_eq(revealed.size(), 1)
	assert_eq(revealed[0].name, "Counterspell")
	assert_eq(AiObservation.capture(g, 0).players[1].known_hand.size(), 1)
	g.sacrifice_permanent(revelation)
	assert_true(duel.view(0).players[1].revealed.is_empty())
	assert_true(AiObservation.capture(g, 0).players[1].known_hand.is_empty())
	assert_null(duel._card(0, revealed[0].id), "a formerly public hand handle loses authority")
	var hidden_draw := give_hand(1, "Lightning Bolt")
	assert_false(JSON.stringify(duel.view(0)).contains(hidden_draw.data.card_name))


func test_land_tax_choices_stay_private_but_found_lands_are_revealed() -> void:
	var duel := _match()
	put_battlefield(0, "Land Tax")
	put_battlefield(1, "Swamp")
	for i in 150:
		if g.awaiting_choice != null: break
		if g.awaiting_attackers: g.declare_attackers(g.active_player, [])
		elif g.awaiting_blockers: g.declare_blockers(g.opponent_of(g.active_player), {})
		else: assert_ok(duel.act(g.priority_player, {"op": "pass"}))
	assert_not_null(g.awaiting_choice)
	var choice: Dictionary = duel.view(0).choice
	assert_eq(choice.source, "Land Tax")
	assert_true(duel.view(1).choice.is_empty())
	assert_ok(duel.act(0, {"op": "choice", "picks": [choice.options.find("1")]}))
	choice = duel.view(0).choice
	assert_ok(duel.act(0, {"op": "choice", "picks": [choice.options.find("Forest")]}))
	_resolve_until_question()
	assert_eq(duel.view(1).information.back().cards, ["Forest"])
	assert_eq(duel.view(0).information, duel.view(1).information)
	assert_true(duel.view(1).players[0].revealed.is_empty(), "a past reveal is not continuous hand access")
