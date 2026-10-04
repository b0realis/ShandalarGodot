extends GameTest
## THE OPTIONS OFFER ONLY WHAT THE ENGINE WOULD TAKE (2026-10-04, the MCP
## play-through). The lead played a whole game through the release's MCP
## server: a Knight of Valor's "Activate only once each turn" ability stayed
## in the seat's options after its use, `prepare` + `autopay` tapped two
## lands for it and only the `submit` was refused — the mana floated and
## burned for 2 life; tapped lands stayed listed as mana sources; and the
## phantom ability counted as "holding something", so the server's passing
## stopped at every opponent step.
##
## Pinned here, at the referee (`SgPracticeMatch`, `SgDuelActions.options`,
## `SgDuelPresentation`), each through the engine's own refusal
## (MtgGame.ability_announce_refusal, MtgGame.mana_ability_refusal):
##  * a used once-a-turn ability, a tapped or summoning-sick {T} source, an
##    ability outside its printed timing, an ability or a spell with nothing
##    to aim at, and an ability the reachable mana cannot pay are not
##    offered; nor is a tapped land or a sick Elf as a mana source;
##  * `prepare` and `autoprepare` refuse them before any mana is made, in
##    the engine's words, with nothing tapped;
##  * on the opponent's turn a seat holding only a sorcery and an exhausted
##    Knight has nothing to respond with — no cast, no ability, `respond`
##    false — and an instant it can pay and aim is all three;
##  * the source of a {T} ability is never auto-tapped for that ability's
##    own mana.

const REFEREE := "res://DeckLab/referee.gd"

var referee: SgPracticeMatch
var Referee: Script


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	super.before_each()
	referee = SgPracticeMatch.new(42)
	referee.game = g
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	Referee = load(REFEREE)


func after_each() -> void:
	referee = null
	CardPacks.set_enabled("pack-8", false)
	CardPacks.set_enabled("pack-3", false)
	CardPacks.set_enabled("pack-5", false)
	CardRegistry.ensure_loaded()


# ---------------------------------------------------------------- fixture --

func _h(card: CardInstance, seat := 0) -> String:
	return referee._handle(seat, card)


## The card's `actions` as the seat's view lists them (hand or any board).
func _actions(view: Dictionary, card: CardInstance, seat := 0) -> Array:
	var handle := _h(card, seat)
	var faces: Array = view.hand.duplicate()
	for player in view.players:
		for zone in ["battlefield", "graveyard", "exile", "phased_out"]:
			faces.append_array(player.get(zone, []))
	for face in faces:
		if face.id == handle: return face.actions
	return []


func _offers(view: Dictionary, card: CardInstance, kind: String, seat := 0) -> bool:
	for option in _actions(view, card, seat):
		if option.kind == kind: return true
	return false


func _row(view: Dictionary, card: CardInstance, seat := 0) -> Dictionary:
	for row in view.presentation.cards:
		if row.id == _h(card, seat): return row
	return {}


func _options(seat := 0) -> Dictionary:
	return Referee.options_for(referee.view(seat), seat)


func _untapped(lands: Array) -> int:
	return lands.filter(func(land: CardInstance) -> bool: return not land.tapped).size()


func _prepare(card: CardInstance, kind := "ability", index := 0) -> String:
	return referee.act(0, {"op": "prepare", "card": _h(card), "kind": kind, "index": index, "x": 0, "mode": 0})


func _autoprepare(card: CardInstance, kind := "ability", index := 0) -> String:
	return referee.act(0, {"op": "autoprepare", "card": _h(card), "kind": kind, "index": index,
		"mode": 0, "excluded": [], "count": 1})


## Activate [param card]'s ability through the referee as a program does.
func _activate(card: CardInstance, targets: Array = []) -> void:
	assert_ok(_prepare(card))
	assert_ok(referee.act(0, {"op": "autopay", "excluded": [], "count": 1}))
	assert_ok(referee.act(0, {"op": "submit", "targets": targets}))


static func _druid() -> CardData:
	return CardData.new("Test Druid", "{G}", Mtg.CardType.CREATURE).pt(1, 1) \
		.mana(ManaAbility.new(Mtg.ManaColor.G, 1)) \
		.activated(ActivatedAbility.new("{G}", true, [PumpEffect.new(1, 1)],
			"{G}, {T}: Target creature gets +1/+1 until end of turn."))


static func _wand() -> CardData:
	return CardData.new("Test Wand", "{1}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("{0}", false, [PumpEffect.new(1, 1)],
			"{0}: Target creature gets +1/+1 until end of turn."))


# ================================================= once each turn: Knight --

func test_a_used_once_a_turn_ability_is_offered_no_more() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var knight := put_battlefield(0, "Knight of Valor")
	for i in 4: put_battlefield(0, "Plains")
	var view := referee.view(0)
	assert_true(_offers(view, knight, "ability"), "unused, {1}{W} reachable: offered")
	assert_true(view.presentation.respond, "an ability it can use is something to respond with")
	_activate(knight)
	resolve_stack()
	view = referee.view(0)
	assert_eq(int(knight.ability_uses.get(0, 0)), 1, "used once this turn")
	assert_false(_offers(view, knight, "ability"), "used once this turn: not offered")
	assert_eq(_row(view, knight).abilities, [], "nor priced in its presentation row")
	assert_false(view.presentation.respond, "the used ability holds no window open")
	assert_eq(_options().prepare.abilities, [], "the program's options list nothing")


func test_a_forced_prepare_of_the_used_ability_is_refused_with_nothing_tapped() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var knight := put_battlefield(0, "Knight of Valor")
	var plains: Array = []
	for i in 4: plains.append(put_battlefield(0, "Plains"))
	_activate(knight)
	resolve_stack()
	assert_eq(_untapped(plains), 2)
	assert_refused(_prepare(knight), "activate only once each turn")
	assert_true(referee.actions.draft.is_empty(), "no announcement was opened")
	assert_refused(_autoprepare(knight), "activate only once each turn")
	assert_eq(_untapped(plains), 2, "nothing was tapped for it")
	assert_eq(g.players[0].mana_pool.total(), 0, "and nothing floats to burn")


# ============================================================ mana sources --

func test_a_tapped_land_and_a_sick_elf_are_no_mana_sources() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var plains := put_battlefield(0, "Plains")
	var elves := put_battlefield(0, "Llanowar Elves", true)
	var view := referee.view(0)
	assert_true(_offers(view, plains, "mana"), "an untapped land is a source")
	assert_false(_offers(view, elves, "mana"), "a summoning-sick Elf is not (CR 302.6)")
	assert_ok(g.tap_for_mana(0, plains))
	elves.summoning_sick = false
	view = referee.view(0)
	assert_false(_offers(view, plains, "mana"), "a TAPPED land is no source")
	assert_true(_offers(view, elves, "mana"), "the Elf past its sickness is")
	var sources: Array = _options().mana.sources
	assert_eq(sources.map(func(row: Dictionary) -> String: return row.card), [_h(elves)],
		"the program's mana sources are the usable ones alone")


# ======================================================= {T} and timing --

func test_a_sick_or_tapped_tap_ability_is_not_offered() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer", true)
	assert_false(_offers(referee.view(0), sorcerer, "ability"), "summoning-sick: {T} can't be paid")
	assert_refused(_prepare(sorcerer), "summoning sickness")
	sorcerer.summoning_sick = false
	assert_true(_offers(referee.view(0), sorcerer, "ability"))
	assert_ok(_prepare(sorcerer))
	var request := referee.actions.request(0)
	var player_token := ""
	for target in request.slots[0].targets:
		if target.label == "Opponent": player_token = target.id
	assert_ok(referee.act(0, {"op": "submit", "targets": [[player_token, 0]]}))
	resolve_stack()
	assert_true(sorcerer.tapped)
	assert_false(_offers(referee.view(0), sorcerer, "ability"), "tapped: not offered")


func test_an_ability_outside_its_printed_timing_is_not_offered() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var statue := put_battlefield(0, "Jade Statue")
	for i in 2: put_battlefield(0, "Forest")
	assert_false(_offers(referee.view(0), statue, "ability"), "activate only during combat")
	assert_refused(_prepare(statue), "activate only during combat")
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	assert_eq(g.priority_player, 0)
	assert_true(_offers(referee.view(0), statue, "ability"), "in combat it is offered")


# ========================================================= nothing to aim --

func test_an_ability_with_nothing_to_aim_at_is_not_offered() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var wand := put_synthetic(0, _wand())
	assert_false(_offers(referee.view(0), wand, "ability"), "no creature on the table to aim at")
	assert_refused(_prepare(wand), "nothing to aim")
	put_battlefield(1, "Grizzly Bears")
	assert_true(_offers(referee.view(0), wand, "ability"), "a creature to aim at")


## THE COST BODIES (the decide worker, 2026-10-04): Zuran Orb's "{0},
## Sacrifice a land: You gain 2 life" stayed offered after an Armageddon,
## `prepare` took it and only the submit said "no land to sacrifice".
## MtgGame.ability_cost_bodies — the very check activate_ability makes
## before any mana — now decides the option too.
func test_zuran_orb_with_no_land_to_sacrifice_is_not_offered() -> void:
	CardPacks.set_enabled("pack-3", true)
	CardRegistry.ensure_loaded()
	advance_to_step(Mtg.Step.MAIN1)
	var orb := put_battlefield(0, "Zuran Orb")
	assert_false(_offers(referee.view(0), orb, "ability"), "no land to sacrifice")
	assert_eq(_options().prepare.abilities, [])
	assert_refused(_prepare(orb), "no land to sacrifice")
	assert_true(referee.actions.draft.is_empty())
	var swamp := put_battlefield(0, "Swamp")
	assert_true(_offers(referee.view(0), orb, "ability"), "a land to sacrifice: offered")
	assert_ok(_prepare(orb))
	assert_ok(referee.act(0, {"op": "submit", "targets": []}))
	if g.awaiting_choice != null:
		assert_ok(referee.act(0, {"op": "choice", "picks": [0]}))
	assert_eq(swamp.zone, Mtg.Zone.GRAVEYARD, "the land paid for it")
	resolve_stack()
	assert_eq(g.players[0].life, 22)


func test_an_ability_short_of_life_or_cards_to_discard_is_not_offered() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bargain := put_synthetic(0, CardData.new("Test Bargain", "{1}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("{0}", false, [GainLifeEffect.new(1)],
			"Discard a card: You gain 1 life.").with_discard_cost(1)))
	assert_false(_offers(referee.view(0), bargain, "ability"), "an empty hand has nothing to discard")
	assert_refused(_prepare(bargain), "not enough cards in hand to discard")
	give_hand(0, "Forest")
	assert_true(_offers(referee.view(0), bargain, "ability"), "a card to discard: offered")


func test_a_spell_with_nothing_to_aim_at_is_not_offered_nor_paid_for() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var plains: Array = []
	for i in 2: plains.append(put_battlefield(0, "Plains"))
	var disenchant := give_hand(0, "Disenchant")
	var view := referee.view(0)
	assert_false(_row(view, disenchant).castable, "no artifact or enchantment to destroy")
	assert_eq(_options().prepare.casts, [])
	assert_false(view.presentation.respond)
	assert_refused(_prepare(disenchant, "spell"), "nothing to aim Disenchant at")
	assert_refused(_autoprepare(disenchant, "spell"), "nothing to aim Disenchant at")
	assert_eq(_untapped(plains), 2, "nothing was tapped for it")
	assert_true(referee.actions.draft.is_empty())
	put_battlefield(1, "Howling Mine")
	view = referee.view(0)
	assert_true(_row(view, disenchant).castable, "something to destroy: castable")
	var casts: Array = _options().prepare.casts
	assert_eq(casts.map(func(row: Dictionary) -> String: return row.card), [_h(disenchant)])


## TARGETS THAT READ X (the full gate, 2026-10-04): Detonate's "target
## artifact with mana value X" has a target at X = 1 and none at X = 0.
## With no X announced the options ask SOME payable X; a `prepare` is
## judged at the X it announces.
func test_detonate_is_aimed_at_the_x_it_will_be_cast_for() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(1, "Sol Ring")
	var detonate := give_hand(0, "Detonate")
	add_mana(0, Mtg.ManaColor.R)
	assert_false(_row(referee.view(0), detonate).castable, "only X = 0 is payable, and nothing has mana value 0")
	assert_refused(_prepare(detonate, "spell"), "nothing to aim Detonate at")
	add_mana(0, Mtg.ManaColor.R)
	assert_true(_row(referee.view(0), detonate).castable, "X = 1 is payable and finds the Sol Ring")
	assert_eq(_options().prepare.casts.size(), 1)
	assert_refused(_prepare(detonate, "spell"), "nothing to aim Detonate at")
	assert_ok(referee.act(0, {"op": "prepare", "card": _h(detonate), "kind": "spell", "index": 0, "x": 1, "mode": 0}))
	assert_eq(referee.actions.request(0).slots[0].targets.size(), 1, "the Sol Ring, at X = 1")


## THE ROW AND ITS COST STAY (the mcp worker, 2026-10-04): a spell with
## nothing to aim at is no cast, but every board still reads its cost off
## its presentation row — the LAN screen showed an Agility with no {1}{R}
## while no creature was out.
func test_an_aura_with_no_creature_keeps_its_row_and_cost_but_is_no_cast() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Plains")
	var strength := give_hand(0, "Holy Strength")
	var view := referee.view(0)
	var row := _row(view, strength)
	assert_false(row.is_empty(), "the hand card has its presentation row")
	var spell_rows: Array = row.abilities.filter(func(entry: Dictionary) -> bool: return entry.kind == "spell")
	assert_eq(spell_rows.size(), 1, "its spell row is there")
	assert_eq(String(spell_rows[0].cost), "{W}", "with its cost")
	assert_true(_offers(view, strength, "spell"), "the face keeps its Cast action")
	assert_false(row.castable, "no creature to enchant: not castable")
	assert_eq(_options().prepare.casts, [], "and no cast for the program")
	assert_false(view.presentation.respond)
	assert_refused(_prepare(strength, "spell"), "nothing to aim Holy Strength at")
	put_battlefield(0, "Grizzly Bears")
	assert_true(_row(referee.view(0), strength).castable, "a creature to enchant: castable")
	assert_eq(_options().prepare.casts.size(), 1)


# ========================================== payment rows and modes --

func _cast_entry(card: CardInstance) -> Dictionary:
	for entry in _options().prepare.casts:
		if entry.card == _h(card): return entry
	return {}


## PAYMENT ROWS ONE BY ONE (the decide worker, 2026-10-04): Fireblast's
## "sacrifice two Mountains" was offered with one Mountain, and `prepare`
## in that mode was refused "not enough distinct eligible cards". `modes`
## keeps every label at its index; `usable_modes` names the rows the seat
## can pay, and the cast is listed only when one of them is.
func test_fireblast_offers_only_the_payment_rows_it_can_make() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var mountain := put_battlefield(0, "Mountain")
	var blast := give_hand(0, "Fireblast")
	assert_false(_row(referee.view(0), blast).castable, "one Mountain: neither row can be paid")
	assert_eq(_cast_entry(blast), {}, "no cast is listed")
	assert_refused(referee.act(0, {"op": "prepare", "card": _h(blast), "kind": "spell", "index": 0, "x": 0, "mode": 1}),
		"not enough distinct eligible cards")
	assert_false(mountain.tapped)
	assert_eq(mountain.zone, Mtg.Zone.BATTLEFIELD, "nothing was paid for the refused row")
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	var entry := _cast_entry(blast)
	assert_eq(entry.get("modes", []).size(), 2, "every label stays at its index")
	assert_eq(entry.get("usable_modes", []), [0], "{4}{R}{R} in reach: the printed row, not the Mountains")
	var spell_rows: Array = _row(referee.view(0), blast).abilities.filter(
		func(row: Dictionary) -> bool: return row.kind == "spell")
	assert_eq(String(spell_rows[0].cost), "{4}{R}{R}", "the first row is the printed cost")
	put_battlefield(0, "Mountain")
	assert_eq(_cast_entry(blast).get("usable_modes", []), [0, 1], "two Mountains: the alternative row too")


func test_force_of_will_has_no_pitch_row_without_another_blue_card() -> void:
	CardPacks.set_enabled("pack-5", true)
	CardRegistry.ensure_loaded()
	advance_to_step(Mtg.Step.MAIN1)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)
	var force := give_hand(1, "Force of Will")
	var row := _row(referee.view(1), force, 1)
	assert_false(row.castable, "no mana and no other blue card: no row can be paid")
	assert_eq(Referee.options_for(referee.view(1), 1).prepare.casts, [])
	give_hand(1, "Storm Crow")
	var casts: Array = Referee.options_for(referee.view(1), 1).prepare.casts
	assert_eq(casts.size(), 1)
	assert_eq(casts[0].get("usable_modes", []), [1], "a blue card to exile: the pitch row alone")
	assert_true(referee.view(1).presentation.respond)


## THE NETWORK SCREEN READS THE ROWS SENSIBLY (the lead, 2026-10-04): the
## extra spell rows for open modes change nothing a LAN player sees — the
## card's one Cast action opens the mode window with the card's own
## labelled rows, each once; the X dialog's cost and budget come from the
## chosen row; a plain spell has exactly one cast row and one spell row.
func test_the_network_screen_offers_fireblasts_rows_once_each_and_a_bolt_once() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	for i in 2: put_battlefield(0, "Mountain")
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C, 4)
	var blast := give_hand(0, "Fireblast")
	var bolt := give_hand(0, "Lightning Bolt")
	var view := referee.view(0)
	assert_eq(_actions(view, blast).filter(func(o: Dictionary) -> bool: return o.kind == "spell").size(), 1,
		"one Cast action, whatever the rows")
	var rows: Array = _row(view, blast).abilities.filter(func(r: Dictionary) -> bool: return r.kind == "spell")
	assert_eq(rows.map(func(r: Dictionary) -> String: return "%d %s" % [int(r.index), r.cost]),
		["0 {4}{R}{R}", "0 {4}{R}{R}", "1 {0}"], "the printed cost first, then one row per open mode (the Mountains row costs no mana)")
	assert_eq(_actions(view, bolt).filter(func(o: Dictionary) -> bool: return o.kind == "spell").size(), 1)
	assert_eq(_row(view, bolt).abilities.filter(func(r: Dictionary) -> bool: return r.kind == "spell").size(), 1,
		"a plain spell keeps exactly one spell row")
	var screen := _screen()
	await _pump()
	screen._click_hand_card(_local(screen, blast))
	assert_not_null(screen._mode_overlay, "the payment rows are asked")
	var lines: Array = []
	for button in screen._mode_overlay.find_children("*", "Button", true, false):
		if button.text != "Cancel": lines.append(button.text)
	assert_eq(lines.size(), 2, "two lines, one per row: %s" % [lines])
	assert_eq(lines[0], "Pay {4}{R}{R}")
	assert_true(lines[1].contains("Mountain"), "the alternative row says what it costs: %s" % lines[1])
	assert_false(lines.has("Cast Fireblast"), "no bare Cast line")
	screen._on_mode_chosen(1)
	screen._pending_mode = 1
	assert_eq(String(screen._option_detail().get("cost", "?")), "{0}", "mode 1 reads its own row")
	screen._pending_mode = 0
	assert_eq(String(screen._option_detail().get("cost", "?")), "{4}{R}{R}")


func _room(seat := 0) -> Dictionary:
	return {"id": "r1", "name": "Options", "seat": seat,
		"names": ["Azure Fox", "Amber Owl"], "revision": 1,
		"ready": [true, true], "connected": [true, true], "game": referee.view(seat),
		"deck_names": referee.deck_names.duplicate(), "deck": {}}


func _screen(seat := 0) -> SgDuelView:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var screen := SgDuelView.new()
	screen.stops.from_masks(PackedInt32Array([255, 255, 255, 255]))
	viewport.add_child(screen)
	screen.present(_room(seat), true, false)
	return screen


func _pump() -> void:
	for i in 8: await get_tree().process_frame


func _local(screen: SgDuelView, card: CardInstance) -> CardInstance:
	return screen.game.find_instance(screen.projection.local_id(referee._handle(int(screen._room.seat), card)))


# ===================================================== mana it can reach --

func test_an_ability_the_reachable_mana_cannot_pay_is_not_offered() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var druid := put_synthetic(0, _druid())
	assert_false(_offers(referee.view(0), druid, "ability"),
		"its only {G} is the Druid itself, which the {T} ability taps")
	assert_refused(_prepare(druid), "not enough mana")
	var forest := put_battlefield(0, "Forest")
	assert_true(_offers(referee.view(0), druid, "ability"), "a Forest pays the {G}")
	assert_ok(_prepare(druid))
	var token: String = referee.actions.request(0).slots[0].targets[0].id
	assert_ok(referee.act(0, {"op": "autopay", "excluded": [], "count": 1}))
	assert_true(forest.tapped, "the auto-pay tapped the Forest")
	assert_false(druid.tapped, "never the Druid, whose {T} the ability itself pays")
	assert_ok(referee.act(0, {"op": "submit", "targets": [[token, 0]]}))
	assert_eq(g.stack.size(), 1)


# ============================================ the opponent's turn: respond --

func test_the_opponents_turn_offers_nothing_to_a_sorcery_and_a_used_knight() -> void:
	var knight := put_battlefield(0, "Knight of Valor")
	for i in 4: put_battlefield(0, "Plains")
	give_hand(0, "Stone Rain")
	put_battlefield(1, "Forest")
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0, "seat 0 holds priority in the opponent's main phase")
	assert_true(_options().prepare.abilities.size() == 1, "the Knight's ability, unused, is offered")
	_activate(knight)
	resolve_stack()
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	var options := _options()
	assert_eq(options.mode, "priority")
	assert_eq(options.prepare.casts, [], "a sorcery is no cast on the opponent's turn")
	assert_eq(options.prepare.abilities, [], "the used Knight is no ability")
	assert_false(bool(options.respond), "nothing to respond with: the passing need not stop")
	# The control: an instant it can pay and aim is a cast and a response.
	var bolt := give_hand(0, "Lightning Bolt")
	put_battlefield(0, "Mountain")
	options = _options()
	assert_eq(options.prepare.casts.map(func(row: Dictionary) -> String: return row.card), [_h(bolt)])
	assert_true(bool(options.respond))
