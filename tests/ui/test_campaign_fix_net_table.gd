extends GameTest
## THE SGMANALINK TABLE'S HOLES FROM THE WHOLE-GAME CAMPAIGN (2026-10-07 —
## fix-net), each pinned through the referee (`SgPracticeMatch`), the wire
## validator (`SgViewProtocol`), the program's options (DeckLab/referee.gd
## `options_for`) or the networked seat's screen (`SgDuelView`).
##
##  * A PAYMENT ON THE SEAT IS A RESPONSE (w7-3): Sabertooth Cobra's ransom
##    and Guardian Angel's paid point of prevention set the presentation's
##    `respond`, as the local screen's _could_respond counts them (Mirage
##    bug pass H1-F1) — the networked screen walked the bitten seat past
##    the opponent's end step. Channel is mana, never a response.
##  * USABLE ONLY (w7-14): a ransom, a point of prevention or Channel the
##    seat cannot pay right now is not offered (`specials`, `special_rows`);
##    a paid point of prevention taps for its {1} like the local screen.
##  * NAMESAKES (w7-4, protocol 29): a choice's lines name the board card
##    each stands for (`choice.cards`), and the networked screen labels
##    namesakes by the card's own ID tag, as the local screen does.
##  * THE 1997 WINDOW (w7-12): no land is `playable` while the damage-
##    prevention or regeneration window is open.
##  * THE HAND'S SPECIAL DISCARD (w7 LOW): Circling Vultures is an option.
##  * THE ANNOUNCEMENT BRACKET'S CALL SITES (w7-5; the engine's half is
##    fix-engine's MtgGame.begin_announcement): the referee's autopay and a
##    hand tap for an open announcement open it, so City of Brass's
##    triggers wait above the spell; `cancel` closes it.
##  * THE AUTOPAY STOPS AT THE BILL (fix-mana's w1-1 relay): bonus mana
##    from a mana trigger (Mana Flare) ends the tapping once the pool pays.
##  * THE 1997 DAMAGE STEPS (fix-engine's w4-3 relay): in the damage-
##    prevention step a Lightning Bolt is not `castable` and neither it nor
##    a ransom lights `respond`; a Circle of Protection does.

const REFEREE := "res://DeckLab/referee.gd"

var referee: SgPracticeMatch


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	super.before_each()
	referee = SgPracticeMatch.new(42)
	referee.game = g
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())


func after_each() -> void:
	referee = null
	CardPacks.set_enabled("pack-8", false)


func _room(seat := 0) -> Dictionary:
	return {"id": "r1", "name": "Campaign", "seat": seat,
		"names": ["Azure Fox", "Amber Owl"], "revision": 1,
		"ready": [true, true], "connected": [true, true], "game": referee.view(seat),
		"deck_names": referee.deck_names.duplicate(), "deck": {}}


func _screen(seat := 0) -> SgDuelView:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var screen := SgDuelView.new()
	screen.stops.from_masks(PackedInt32Array([0, 0, 0, 0]))
	viewport.add_child(screen)
	return screen


func _options(view: Dictionary, seat := 0) -> Dictionary:
	var ref = autofree(load(REFEREE).new())
	return ref.options_for(view, seat)


## Seat 1's Cobra bites seat 0 (with [param islands] untapped Islands);
## play walks on to seat 1's END step, seat 0 holding priority.
func _bitten_at_the_end_step(islands: int) -> CardInstance:
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	var cobra := put_battlefield(1, "Sabertooth Cobra")
	for i in islands: put_battlefield(0, "Island")
	run_combat([cobra.id])
	assert_eq(g.players[0].poison, 1, "bitten")
	assert_eq(g.settleable_delayed_triggers(0).size(), 1, "the ransom is owed")
	for i in 30:
		if g.current_step() == Mtg.Step.END and g.priority_player == 0 and g.stack.is_empty(): break
		assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.current_step(), Mtg.Step.END)
	assert_eq(g.priority_player, 0)
	return cobra


# ============================================= a payment is a response --

func test_a_payable_ransom_is_a_response_at_the_end_step() -> void:
	_bitten_at_the_end_step(2)
	var view := referee.view(0)
	assert_true(SgViewProtocol.game(view), "the view validates")
	assert_eq(view.specials.size(), 1)
	assert_true(String(view.specials[0]).begins_with("Pay {2}"))
	assert_true(bool(view.presentation.respond), "two Islands pay the ransom: a response (local H1-F1)")
	assert_true(bool(_options(view).respond), "the program's options say so too")
	var sent: Array = []
	var screen := _screen(0)
	screen.action_requested.connect(func(action: Dictionary) -> void: sent.append(action.duplicate()))
	screen.present(_room(0), true, false)
	await get_tree().process_frame
	assert_true(screen._could_respond(0))
	assert_false(screen._auto_pass_applies(), "the end step is held for the ransom")
	assert_false(sent.has({"op": "pass"}), "the screen did not pass past it: %s" % str(sent))


func test_an_unpayable_ransom_is_neither_offered_nor_a_response() -> void:
	_bitten_at_the_end_step(0)
	assert_false(g.can_afford_cost(0, ManaCost.parse("{2}")), "control: no mana at all")
	var view := referee.view(0)
	assert_true(SgViewProtocol.game(view))
	assert_eq(view.specials, [], "a ransom the seat cannot pay is not offered")
	assert_eq(view.presentation.special_rows, [])
	assert_false(bool(view.presentation.respond))
	assert_eq(_options(view).special.specials, [])
	assert_eq(referee.act(0, {"op": "special", "index": 0}), "That special action is no longer available.")


func test_a_paid_point_of_prevention_is_offered_payable_and_taps_for_itself() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	g.grant_paid_prevention(0, TargetRef.player(0), "Guardian Angel")
	assert_eq(g.priority_player, 0)
	var bare := referee.view(0)
	assert_eq(bare.specials, [], "no mana: not offered")
	assert_false(bool(bare.presentation.respond))
	var plains := put_battlefield(0, "Plains")
	var view := referee.view(0)
	assert_true(SgViewProtocol.game(view))
	assert_eq(view.specials.size(), 1)
	assert_true(String(view.specials[0]).begins_with("Pay {1}: prevent 1 damage"))
	assert_true(bool(view.presentation.respond), "a point of prevention is a response")
	assert_eq(referee.act(0, {"op": "special", "index": 0}), "", "the referee taps for it, as the local screen does")
	assert_true(plains.tapped)
	assert_eq(g.players[0].damage_prevention, 1)
	assert_eq(g.players[0].mana_pool.total(), 0, "nothing left floating")


func test_channel_is_offered_but_never_a_response() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var channel := give_hand(0, "Channel")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, channel))
	resolve_stack()
	assert_true(g.players[0].life_for_mana)
	var view := referee.view(0)
	assert_eq(view.specials.size(), 1, "Channel is listed while the seat has life to pay")
	assert_false(bool(view.presentation.respond), "Channel is mana, not a response")


# ================================================ the 1997 prevention window --

func test_no_land_is_playable_while_the_prevention_window_is_open() -> void:
	g.rules.damage_prevention_window = true
	advance_to_step(Mtg.Step.MAIN1)
	var mountain := give_hand(0, "Mountain")
	put_battlefield(1, "Circle of Protection: Red")
	put_battlefield(1, "Plains")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	for i in 6:
		if g.awaiting_damage_prevention: break
		assert_ok(g.pass_priority(g.priority_player))
	assert_true(g.awaiting_damage_prevention, "control: the window is open")
	if g.priority_player != 0: assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.priority_player, 0)
	var view := referee.view(0)
	var face := {}
	for card in view.hand:
		if card.id == referee._handle(0, mountain): face = card
	assert_false(bool(face.get("playable", true)), "the window admits prevention effects only")
	assert_eq(_options(view).play.lands, [])
	assert_refused(referee.act(0, {"op": "play", "card": referee._handle(0, mountain)}), "damage prevention")
	# Control: the window closed, the land is playable again.
	while g.awaiting_damage_prevention: assert_ok(g.pass_priority(g.priority_player))
	resolve_stack()
	if g.priority_player == 0 and g.stack.is_empty():
		for card in referee.view(0).hand:
			if card.id == referee._handle(0, mountain): face = card
		assert_true(bool(face.get("playable", false)), "once the window has closed")


# =========================================================== namesakes --

func _namesakes() -> Array:
	advance_to_step(Mtg.Step.MAIN1)
	var altar := put_battlefield(0, "Ashnod's Altar")
	var plain := put_battlefield(0, "Grizzly Bears")
	var pumped := put_battlefield(0, "Grizzly Bears")
	g.add_counters(pumped, "+1/+1", 3)
	referee.view(0)
	assert_eq(referee.act(0, {"op": "mana", "card": referee._handle(0, altar), "index": 0}), "")
	return [plain, pumped]


func test_a_choice_names_the_board_card_of_each_line() -> void:
	var bears := _namesakes()
	var view := referee.view(0)
	assert_eq(view.mode, "choice")
	assert_true(SgViewProtocol.game(view), "protocol 29's choice validates")
	var choice: Dictionary = view.choice
	assert_eq(choice.options.size(), 2)
	assert_eq(choice.cards.size(), choice.options.size(), "one card per line")
	var handles := [referee._handle(0, bears[0]), referee._handle(0, bears[1])]
	var named: Array = choice.cards.duplicate()
	named.sort()
	handles.sort()
	assert_eq(named, handles, "each line names its own Grizzly Bears")
	# The line picked is the card named: sacrifice the 5/5.
	var at: int = choice.cards.find(referee._handle(0, bears[1]))
	assert_eq(referee.act(0, {"op": "choice", "picks": [at]}), "")
	assert_eq(bears[1].zone, Mtg.Zone.GRAVEYARD, "the pumped Bears went")
	assert_eq(bears[0].zone, Mtg.Zone.BATTLEFIELD)
	# The program's options carry the cards beside the lines.
	var options := _options(view)
	assert_eq(options.choice.cards, choice.cards)


func test_the_wire_refuses_a_choice_whose_cards_do_not_match_its_lines() -> void:
	var base := {"prompt": "Pick", "source": "", "options": ["A", "B"], "count": 1, "cancel": false,
		"information": [], "cards": ["c1", ""]}
	assert_true(SgViewProtocol.choice(base))
	assert_false(SgViewProtocol.choice(base.merged({"cards": ["c1"]}, true)), "one card per line")
	assert_false(SgViewProtocol.choice(base.merged({"cards": [1, ""]}, true)), "handles are text")
	var old := base.duplicate()
	old.erase("cards")
	assert_false(SgViewProtocol.choice(old), "protocol 29 always says")


func test_the_networked_screen_labels_namesakes_by_their_id_tags() -> void:
	var bears := _namesakes()
	var screen := _screen(0)
	screen.present(_room(0), true, false)
	await get_tree().process_frame
	var question: PlayerChoice = screen.game.awaiting_choice
	assert_not_null(question)
	var choice: Dictionary = referee.view(0).choice
	for i in choice.options.size():
		var local := screen.projection.local_id(String(choice.cards[i]))
		var line := String(question.options[i])
		assert_true(line.contains("#%d" % local), "line %d names the ID tag #%d: %s" % [i, local, line])
		assert_false(line.contains("[choice"), "the referee's ordinal gives way to the tag: %s" % line)
	assert_ne(question.options[0], question.options[1])
	var projected := screen.game.find_instance(screen.projection.local_id(referee._handle(0, bears[1])))
	assert_not_null(projected, "the tag is the very card on the seat's board")


# =================================================== the special discard --

func test_the_special_discard_is_an_option_outside_the_window() -> void:
	var vultures := give_hand(0, "Circling Vultures")
	advance_to_step(Mtg.Step.MAIN1)
	var options := _options(referee.view(0))
	assert_eq(options.discard_special.cards, [{"card": referee._handle(0, vultures), "name": "Circling Vultures"}])
	var ref = autofree(load(REFEREE).new())
	var parsed: Dictionary = ref._parse_action(JSON.stringify({"op": "discard_special", "card": referee._handle(0, vultures)}), 0)
	assert_false(parsed.has("refusal"), str(parsed))
	assert_eq(referee.act(0, parsed.action), "")
	assert_eq(vultures.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(_options(referee.view(0)).discard_special.cards, [])


# ===================================================== the version stamp --

func test_protocol_29_and_the_campaign_rules_revision() -> void:
	assert_eq(SgProtocol.VERSION, 29)
	assert_eq(SgProtocol.SUBPROTOCOL, "sgmanalink-local-v29")
	assert_eq(SgCompatibility.RULES_REVISION, "sgmanalink-campaign-2026-10-07")
	assert_true(SgCompatibility.valid_stamp(SgCompatibility.stamp()), "the stamp's rules text fits the wire")
	assert_true(SgProtocol.subprotocols().has("sgmanalink-local-v28"),
		"the last protocol is still named, so a 28 build is told, not hung up on")


# ================================ the announcement bracket (w7-5, F1's API) --

func _city_paid_bears() -> CardInstance:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "City of Brass")
	put_battlefield(0, "City of Brass")
	var bears := give_hand(0, "Grizzly Bears")
	referee.view(0)
	var handle := referee._handle(0, bears)
	assert_eq(referee.act(0, {"op": "prepare", "card": handle, "kind": "spell", "index": 0, "x": 0, "mode": 0}), "")
	return bears


func test_city_of_brass_pays_for_an_announced_creature() -> void:
	var bears := _city_paid_bears()
	assert_eq(referee.act(0, {"op": "autopay", "excluded": [], "count": 1}), "")
	assert_true(g.stack.is_empty(), "the City triggers wait for the spell (CR 603.3)")
	assert_eq(referee.act(0, {"op": "submit", "targets": []}), "", "the paid-for creature is cast")
	assert_eq(bears.zone, Mtg.Zone.STACK)
	assert_eq(g.stack.size(), 3, "the Bears and, above them, two City triggers")
	assert_eq(g.stack[0].card, bears, "the spell is at the bottom")


func test_a_withdrawn_announcement_lets_the_triggers_go_on() -> void:
	var bears := _city_paid_bears()
	assert_eq(referee.act(0, {"op": "autopay", "excluded": [], "count": 1}), "")
	assert_true(g.stack.is_empty())
	assert_eq(referee.act(0, {"op": "cancel"}), "")
	assert_eq(bears.zone, Mtg.Zone.HAND)
	assert_eq(g.stack.size(), 2, "withdrawn: the City triggers go on the stack")
	assert_eq(g.priority_player, 0, "the seat keeps priority")
	assert_eq(g.players[0].mana_pool.total(), 2, "with the mana it made")


# ========================= the autopay stops at the bill (fix-mana's w1-1) --

## A mana trigger the planner has no description of (a "Test Flare": every
## land tapped for mana adds one more of its colour) — the planner then
## plans a Mountain per pip, and the autopay must stop once the pool covers
## the bill (relay from fix-mana: it tapped on and the spare mana burned).
static func _undescribed_flare() -> CardData:
	var trigger := TriggeredAbility.new(Mtg.EventType.TAPPED_FOR_MANA, _flare_mana,
		"Whenever a player taps a land for mana, that player adds one mana of any type that land produced.") \
		.as_mana_trigger()
	return CardData.new("Test Flare", "{2}{R}", Mtg.CardType.ENCHANTMENT).triggered(trigger)


static func _flare_mana(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	game.players[int(event.data["player"])].mana_pool.add(int(event.data["color"]), 1)


func _giant_paid_under(flare: Variant) -> Array:
	advance_to_step(Mtg.Step.MAIN1)
	if flare is CardData: put_synthetic(0, flare)
	else: put_battlefield(0, String(flare))
	var mountains: Array = []
	for i in 4: mountains.append(put_battlefield(0, "Mountain"))
	var giant := give_hand(0, "Hill Giant")
	referee.view(0)
	var handle := referee._handle(0, giant)
	assert_eq(referee.act(0, {"op": "prepare", "card": handle, "kind": "spell", "index": 0, "x": 0, "mode": 0}), "")
	assert_eq(referee.act(0, {"op": "autopay", "excluded": [], "count": 1}), "")
	return [giant, mountains.filter(func(m: CardInstance) -> bool: return m.tapped).size()]


func test_the_autopay_stops_once_bonus_mana_covers_the_bill() -> void:
	var paid := _giant_paid_under(_undescribed_flare())
	assert_eq(paid[1], 2, "two doubled Mountains pay {3}{R}; the other two stay untapped")
	assert_eq(referee.act(0, {"op": "submit", "targets": []}), "")
	assert_eq((paid[0] as CardInstance).zone, Mtg.Zone.STACK)
	assert_eq(g.players[0].mana_pool.total(), 0, "nothing left floating to burn")


func test_the_real_mana_flare_too() -> void:
	var paid := _giant_paid_under("Mana Flare")
	assert_eq(paid[1], 2)
	assert_eq(referee.act(0, {"op": "submit", "targets": []}), "")
	assert_eq(g.players[0].mana_pool.total(), 0)


# ============== the 1997 damage step counts only what it admits (F1 relay) --

## Under the fifth rules the damage-prevention step opens whenever damage
## is pending and a hand holds a card (fix-engine w4-3). An answer the
## step does not admit — a Lightning Bolt, a ransom — must not light
## `respond` there, or a network seat is held at every damage step.
func _giant_damage_waits(defender_cards: Callable) -> void:
	defender_cards.call()
	g.rules.damage_prevention_window = true
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [giant.id]))
	for i in 20:
		if g.awaiting_blockers: break
		assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.declare_blockers(0, {}))
	for i in 20:
		if (g.awaiting_damage_prevention and g.priority_player == 0) or g.game_over: break
		assert_ok(g.pass_priority(g.priority_player))
	assert_true(g.awaiting_damage_prevention, "control: the window is open")
	assert_eq(g.priority_player, 0)


func test_a_bolt_in_hand_is_no_response_in_the_damage_step() -> void:
	var bolt: Array = []
	_giant_damage_waits(func() -> void:
		put_battlefield(0, "Mountain")
		bolt.append(give_hand(0, "Lightning Bolt")))
	var view := referee.view(0)
	var row := {}
	for r in view.presentation.cards:
		if r.id == referee._handle(0, bolt[0]): row = r
	assert_false(bool(row.get("castable", true)), "the step admits prevention effects only")
	assert_false(bool(view.presentation.respond), "nothing the step admits: no response")
	assert_false(bool(view.presentation.floating))
	assert_eq(_options(view).prepare.casts, [])
	# Control: out of the window the Bolt is a response again.
	while g.awaiting_damage_prevention: assert_ok(g.pass_priority(g.priority_player))


func test_a_circle_of_protection_is_a_response_in_the_damage_step() -> void:
	_giant_damage_waits(func() -> void:
		put_battlefield(0, "Circle of Protection: Red")
		put_battlefield(0, "Plains")
		give_hand(0, "Lightning Bolt"))
	var view := referee.view(0)
	assert_true(bool(view.presentation.respond), "a prevention effect is what the step is for")


func test_a_payable_ransom_is_no_response_in_the_damage_step() -> void:
	_giant_damage_waits(func() -> void:
		put_battlefield(0, "Island")
		put_battlefield(0, "Island")
		give_hand(0, "Lightning Bolt")
		# Seat 1's Cobra bites first: the ransom is due before seat 0's
		# next upkeep, payable all through seat 1's coming turn.
		advance_to_step(Mtg.Step.MAIN1)
		var cobra := put_battlefield(1, "Sabertooth Cobra")
		g.deal_damage(cobra, TargetRef.player(0), 2)
		resolve_stack()
		assert_eq(g.settleable_delayed_triggers(0).size(), 1, "control: the ransom is owed"))
	var view := referee.view(0)
	var offered := false
	for line in view.specials: offered = offered or String(line).begins_with("Pay {2}")
	assert_true(offered, "control: the ransom is payable and offered in the step")
	assert_false(bool(view.presentation.respond), "a ransom is not a prevention effect")
	# Control: out of the window it is a response again (H1-F1).
	while g.awaiting_damage_prevention: assert_ok(g.pass_priority(g.priority_player))
	if g.priority_player == 0 and not g.awaiting_regeneration and g.settleable_delayed_triggers(0).size() == 1 \
			and not g.awaiting_damage_prevention:
		assert_true(bool(referee.view(0).presentation.respond))
