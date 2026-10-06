extends GameTest
## TEMPEST BUG PASS (Pack 9) — the SGManalink table's rows, pinned through
## the referee (`SgPracticeMatch`), its presentation and the wire
## validator (`SgViewProtocol`):
##
##  * a ransom row whose source has CEASED TO EXIST (a token Sabertooth
##    Cobra, CR 111.7) names no card: the referee hands out no handle for
##    an object no zone holds, and the bitten seat's view still validates
##    (it used to fail, and the seat was disconnected);
##  * the X budget the referee publishes for a GRANTED row of an X spell
##    (Dream Halls' discard; Aluren's free cast) is 0 — that row fixes X
##    at 0 (CR 107.3b) — never the search's ceiling of 1000.

const OC := preload("res://engine/additional_object_costs.gd")

var referee: SgPracticeMatch


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardPacks.set_enabled("pack-9", true)
	CardRegistry.ensure_loaded()
	super.before_each()
	referee = SgPracticeMatch.new(42)
	referee.game = g
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())


func after_each() -> void:
	referee = null
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ransom_at(view: Dictionary) -> int:
	for i in view.specials.size():
		if String(view.specials[i]).begins_with("Pay {2}"): return i
	return -1


## Seat 1's Sabertooth Cobra (a token when [param token]) bites seat 0.
func _bitten_by_cobra(token: bool) -> CardInstance:
	advance_to_next_turn()                       # seat 1's turn
	assert_eq(g.active_player, 1)
	var cobra: CardInstance
	if token:
		cobra = g.create_token(1, CardRegistry.get_card("Sabertooth Cobra"))[0]
	else:
		cobra = put_battlefield(1, "Sabertooth Cobra")
	cobra.summoning_sick = false
	run_combat([cobra.id])
	assert_eq(g.players[0].poison, 1, "bitten")
	assert_eq(g.settleable_delayed_triggers(0).size(), 1, "the ransom is owed")
	return cobra


# ---------------------------------------------------------------------------
# h3-1 (HIGH). The ransom row's card is the token itself (`entry.source`),
# which has ceased to exist — though its instance still says EXILE. The
# referee called it visible and the presentation's `special_rows` handed
# out a handle no zone of the view carries, so SgViewProtocol.game()
# rejected the bitten seat's whole view.
func test_a_token_cobras_ransom_row_names_no_card_once_the_token_is_gone() -> void:
	var cobra := _bitten_by_cobra(true)
	g.destroy(cobra)                             # the token ceases to exist
	assert_null(g.find_instance(cobra.id))
	assert_false(referee._visible(0, cobra), "a card that no longer exists is seen by no seat")
	assert_false(referee._visible(1, cobra))
	var view := referee.view(0)
	var at := _ransom_at(view)
	assert_ne(at, -1, "the ransom is still on offer to the bitten seat")
	if at >= 0:
		assert_eq(String(view.presentation.special_rows[at][1]), "",
			"a card that no longer exists has no handle")
	assert_true(SgViewProtocol.game(view), "the bitten seat's view validates")
	assert_true(SgViewProtocol.game(referee.view(1)), "and the other seat's")
	# The ransom is still the seat's to pay, by the same index.
	if g.priority_player == 1: assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	add_mana(0, Mtg.ManaColor.C, 2)
	at = _ransom_at(referee.view(0))
	assert_ok(referee.act(0, {"op": "special", "index": at}))
	assert_eq(g.settleable_delayed_triggers(0).size(), 0, "paid")


# The same while the token is still on the battlefield: the row names it.
func test_a_live_token_cobras_ransom_row_names_the_token() -> void:
	var cobra := _bitten_by_cobra(true)
	var view := referee.view(0)
	var at := _ransom_at(view)
	assert_ne(at, -1)
	if at >= 0:
		assert_eq(String(view.presentation.special_rows[at][1]), referee._handle(0, cobra),
			"the ransom belongs to the Cobra on the table")
	assert_true(SgViewProtocol.game(view))


# A CARD Cobra that died is a new object in a graveyard (CR 400.7) the view
# carries: the row may name it, and the view validates either way.
func test_a_dead_card_cobras_ransom_row_validates() -> void:
	var cobra := _bitten_by_cobra(false)
	g.destroy(cobra)
	assert_eq(cobra.zone, Mtg.Zone.GRAVEYARD)
	var view := referee.view(0)
	assert_ne(_ransom_at(view), -1)
	assert_true(SgViewProtocol.game(view), "the bitten seat's view validates")


# ---------------------------------------------------------------------------
# h2-5. A granted row of an X spell prices every X at the row's own cost,
# so the budget search ran to its ceiling: 1000, the MCP decision menu
# then offering X = 1..1000 only, every one refused by the engine.

static func _halls() -> CardData:
	return CardData.new("Test Halls", "{3}{U}{U}", Mtg.CardType.ENCHANTMENT) \
		.with_granted_alternative_cost(_halls_rows)


static func _shares_color(_g: MtgGame, card: CardInstance, spell: CardInstance) -> bool:
	return spell != null and (card.cur_colors & spell.cur_colors) != 0


static func _halls_rows(_g: MtgGame, _pid: int, spell: CardInstance, _src: CardInstance) -> Array:
	if spell.cur_colors == 0:
		return []
	var group := OC.discarding("card that shares a color with it")
	group["source_filter"] = _shares_color
	return [{"label": "Discard a card that shares a color with it", "object_costs": [group]}]


static func _blue_x() -> CardData:
	return CardData.new("Test Blue X", "{X}{U}", Mtg.CardType.SORCERY).spell(DrawEffect.new(1))


static func _insight() -> CardData:
	return CardData.new("Test Insight", "{2}{U}", Mtg.CardType.SORCERY).spell(DrawEffect.new(1))


func _row(view: Dictionary, card: CardInstance) -> Dictionary:
	var handle := referee._handle(0, card)
	for row in view.presentation.cards:
		if row.id == handle: return row
	return {}


func test_a_granted_row_of_an_x_spell_publishes_budget_zero() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_synthetic(0, _halls())
	var spell := give_synthetic(0, _blue_x())
	give_synthetic(0, _insight())
	for i in 3: put_battlefield(0, "Island")
	assert_eq(g.payment_rows(0, spell).size(), 2)
	assert_eq(g.payment_row_refusal(0, spell, 1), "", "the Dream Halls row is payable")
	assert_ne(g.spell_announce_refusal(0, spell, 1, 1), "", "the engine: X must be 0 through it")
	var sources := ManaPlanner.sources(g, 0)
	assert_eq(SgPayment.budget(g, 0, spell, "spell", 0, sources, 1, 1), 0,
		"the granted row's X budget is 0")
	assert_eq(SgPayment.budget(g, 0, spell, "spell", 0, sources, 1, 0), 2,
		"the printed row's is what three Islands pay: {U} and X = 2")
	var view := referee.view(0)
	var mode_budget := -1
	var first := true
	for option in _row(view, spell).get("abilities", []):
		if option.kind != "spell": continue
		if first:
			first = false
			continue
		if int(option.index) == 1: mode_budget = int(option.budget)
	assert_eq(mode_budget, 0, "the presentation's budget for the granted row")
	assert_true(SgViewProtocol.game(view))
	# X = 0 through the row is what the engine takes.
	assert_ne(referee.act(0, {"op": "prepare", "card": referee._handle(0, spell), "kind": "spell",
		"index": 0, "x": 1, "mode": 1}), "", "X = 1 through the granted row is refused")


# ---------------------------------------------------------------------------
# h2-4, the NETWORK half. The local row menu now also greys a row the engine
# refuses to announce (MtgGame.spell_announce_refusal); a networked seat's
# screen runs on SgDuelProjection, whose rows are the referee's — so there
# the referee's open rows decide, and Aluren's own row stays open at
# instant speed (the projection never knows that row's flash).

var _revision := 1


func _room(seat := 0) -> Dictionary:
	_revision += 1
	return {"id": "r1", "name": "Bug pass", "seat": seat,
		"names": ["Azure Fox", "Amber Owl"], "revision": _revision,
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


func _end_step_of_seat_1() -> void:
	g._probing = true
	g.active_player = 1
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.END))
	g.awaiting_attackers = false
	g.awaiting_blockers = false
	g.priority_player = 0
	g._passes = 1
	g._probing = false


func test_the_clients_aluren_row_stays_open_at_instant_speed() -> void:
	put_battlefield(1, "Aluren")
	var bears := give_hand(0, "Grizzly Bears")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	_end_step_of_seat_1()
	assert_eq(SgDuelActions.open_modes(g, 0, bears), [1], "the referee: only Aluren's row now")
	var screen := _screen()
	await _pump()
	var local := screen.game.find_instance(screen.projection.local_id(referee._handle(0, bears)))
	assert_not_null(local)
	if local == null: return
	screen._start_cast(local)
	assert_not_null(screen._mode_overlay, "two rows: the question")
	if screen._mode_overlay == null: return
	var lines: Array = []
	for button in screen._mode_overlay.find_children("*", "Button", true, false):
		if button.text != "Cancel": lines.append(button)
	assert_eq(lines.size(), 2)
	if lines.size() == 2:
		assert_true(lines[0].disabled, "the printed row is not open")
		assert_false(lines[1].disabled, "Aluren's row is")
	screen._on_mode_canceled()
