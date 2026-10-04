extends GameTest
## THE MIRAGE BUG PASS AT AN SGMANALINK TABLE (2026-10-04, protocol 27) —
## what the read-only hunt of 0.50.11 found in the network half of Pack 8,
## each pinned through the referee (`SgPracticeMatch`), the wire validator
## (`SgViewProtocol`), the client's projection or the real host.
##
##  * Heat Wave's block taxes (H8-1): protocol 26 sent one row per
##    blocker × legal attacker × tax, capped at `SgProtocol.MAX_CARDS`, so two
##    Heat Waves, 17 attackers and 16 blockers (544 rows) made the defender's
##    view invalid — the guest was cut off ("Host sent an invalid response")
##    and a host screen dropped the room without a word. 27 sends ONE row per
##    imposing tax naming the attackers it protects and the blockers that owe
##    it; the client prices the pencilled lineup exactly as the engine
##    charges it. A view the host's own check refuses is never sent silently.
##  * Circling Vultures (H8-3): the referee discarded the very card whose
##    cast was being announced, leaving a dead announcement.
##  * Firestorm (H8-7): the X window's bound counted the hand only; "each of
##    X targets" also needs X targets to name (CR 601.2c).
##  * The graveyard/exile ring (H8-6, network half): the networked view
##    rang an exiled Three Wishes land on the opponent's turn on the
##    projection's timing-only reading; it now asks the referee's own
##    `playable` / `castable`. The network Special actions window still
##    lists Channel, the local screen's own door staying shut there.
##  * A land's entry payment (Lotus Vale) is held on an optional cost
##    question: its decline line names the graveyard, apart from the
##    `cancel` op that withdraws the play.

const DECLARATION := preload("res://engine/core/combat_declaration.gd")

var referee: SgPracticeMatch


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	super.before_each()
	referee = SgPracticeMatch.new(42)
	referee.game = g
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())


func after_each() -> void:
	referee = null
	CardPacks.set_enabled("pack-8", false)


# ---------------------------------------------------------------- fixture --

func _room(seat := 0, revision := 1) -> Dictionary:
	return {"id": "r1", "name": "Pack eight", "seat": seat,
		"names": ["Azure Fox", "Amber Owl"], "revision": revision,
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


func _row(view: Dictionary, card: CardInstance, viewer := 0) -> Dictionary:
	var handle := referee._handle(viewer, card)
	for row in view.presentation.cards:
		if row.id == handle: return row
	return {}


func _spell_budget(view: Dictionary, card: CardInstance) -> int:
	for ability in _row(view, card).abilities:
		if ability.kind == "spell": return int(ability.budget)
	return -1


## Seat 1 attacks with [param attackers]; play stops at seat 0's block
## declaration.
func _attack_into_blocks(attackers: Array) -> void:
	g._probing = true
	g.active_player = 1
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS))
	g.awaiting_attackers = true
	g._probing = false
	var ids: Array = []
	for card: CardInstance in attackers: ids.append(card.id)
	assert_eq(g.declare_attackers(1, ids), "")
	for _i in 10:
		if g.awaiting_blockers: break
		g.pass_priority(g.priority_player)
	assert_true(g.awaiting_blockers, "control: seat 0 declares blockers")


static func _green(blocker: CardInstance) -> bool:
	return blocker.has_color(Mtg.ManaColor.G)


## A second, DIFFERENT life tax: 2 life, and only a green blocker owes it.
static func _toll(game: MtgGame, source: CardInstance) -> void:
	for inst in game.players[source.controller_id].battlefield:
		if inst.is_creature(): CombatState.add_block_life_tax(inst, source, 2, _green, "pay 2 life")


static func _green_toll() -> CardData:
	return CardData.new("Test Green Toll", "{2}{R}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_toll, "Green creatures can't block creatures you control unless their controller pays 2 life for each blocking creature they control."))


static func _knight() -> CardData:
	return CardData.new("Test Knight", "{1}{W}", Mtg.CardType.CREATURE).pt(2, 2)


## A host referee whose view of one seat fails the wire validator, the way
## protocol 26's Heat Wave rows did on a big board.
class InvalidViews extends SgPracticeMatch:
	var broken_seat := 1

	func view(pid: int) -> Dictionary:
		var result := super.view(pid)
		if pid == broken_seat: result.presentation.block_taxes = [["o1", 0, [], []]]
		return result


# ===================================================== H8-1 Heat Wave rows --

func test_two_heat_waves_and_a_big_board_send_one_row_per_tax() -> void:
	var waves := [put_battlefield(1, "Heat Wave"), put_battlefield(1, "Heat Wave")]
	var attackers: Array = []
	for i in 17: attackers.append(put_battlefield(1, "Gray Ogre"))
	var blockers: Array = []
	for i in 16: blockers.append(put_battlefield(0, "Grizzly Bears"))
	_attack_into_blocks(attackers)
	var view := referee.view(0)
	var rows: Array = view.presentation.block_taxes
	assert_eq(rows.size(), 2, "one row per Heat Wave, not per blocker × attacker × tax (was 544)")
	assert_true(SgViewProtocol.game(view), "the defender's view passes the protocol's own check")
	assert_true(SgViewProtocol.room(_room(0)), "and so does the room carrying it")
	var wire: Dictionary = SgProtocol.decode_payload(SgProtocol.encode(view).to_ascii_buffer())
	assert_true(SgViewProtocol.game(wire), "after the trip through the codec too")
	var attacker_handles: Array = []
	for card: CardInstance in attackers: attacker_handles.append(referee._handle(0, card))
	var blocker_handles: Array = []
	for card: CardInstance in blockers: blocker_handles.append(referee._handle(0, card))
	attacker_handles.sort()
	blocker_handles.sort()
	var taxes := {}
	for row in rows:
		assert_eq(row.size(), 4, "[tax, life, attackers, blockers]")
		taxes[row[0]] = true
		assert_eq(int(row[1]), 1, "1 life per blocking creature")
		var named: Array = row[2].duplicate()
		named.sort()
		assert_eq(named, attacker_handles, "every creature the Heat Wave protects")
		var owing: Array = row[3].duplicate()
		owing.sort()
		assert_eq(owing, blocker_handles, "every nonblue blocker owes it")
	assert_eq(taxes.size(), 2, "two Heat Waves are two taxes (two payments)")
	assert_eq(referee.view(1).presentation.block_taxes, [], "the attacking seat is told no lineup prices")
	var screen := _screen()
	await _pump()
	assert_false(screen.game.players[0].battlefield.is_empty(), "the big board reaches the networked screen")
	var fee := screen._block_life_fee({screen.projection.local_id(blocker_handles[0]): screen.projection.local_id(attacker_handles[0])})
	assert_eq(fee, 2, "one blocker, two Heat Waves: 2 life")
	for wave: CardInstance in waves: assert_eq(wave.zone, Mtg.Zone.BATTLEFIELD)


func test_the_networked_price_of_every_lineup_is_the_engines() -> void:
	put_battlefield(1, "Heat Wave")
	put_battlefield(1, "Heat Wave")
	put_synthetic(1, _green_toll())
	var ogres := [put_battlefield(1, "Gray Ogre"), put_battlefield(1, "Gray Ogre")]
	var bear := put_battlefield(0, "Grizzly Bears")
	var knight := put_synthetic(0, _knight())
	_attack_into_blocks(ogres)
	var view := referee.view(0)
	assert_true(SgViewProtocol.game(view))
	assert_eq(view.presentation.block_taxes.size(), 3, "two Heat Waves and the toll")
	for row in view.presentation.block_taxes:
		var knight_owes: bool = row[3].has(referee._handle(0, knight))
		assert_eq(knight_owes, int(row[1]) == 1, "the white blocker owes the Heat Waves, never the green toll")
		assert_true(row[3].has(referee._handle(0, bear)), "the green blocker owes all three")
	var projection := SgDuelProjection.new()
	projection.ingest(_room(0))
	var local := func(card: CardInstance) -> int: return projection.local_id(referee._handle(0, card))
	var lineups := [
		{},
		{bear.id: ogres[0].id},
		{knight.id: ogres[1].id},
		{bear.id: ogres[0].id, knight.id: ogres[0].id},
		# One creature blocking two: each tax is owed once per BLOCKER.
		{bear.id: [ogres[0].id, ogres[1].id], knight.id: [ogres[1].id]},
	]
	var expected := [0, 4, 2, 6, 6]
	for i in lineups.size():
		var engine_map: Dictionary = lineups[i]
		var screen_map := {}
		for id in engine_map:
			var value: Variant = engine_map[id]
			if value is Array:
				var mapped: Array = []
				for attacker in value: mapped.append(local.call(g.find_instance(attacker)))
				screen_map[local.call(g.find_instance(id))] = mapped
			else:
				screen_map[local.call(g.find_instance(id))] = local.call(g.find_instance(value))
		var engine_fee: int = DECLARATION.block_life_fee(g, engine_map)
		assert_eq(engine_fee, expected[i], "control: the engine's price of lineup %d" % i)
		assert_eq(projection.block_life_fee(screen_map), engine_fee, "lineup %d priced as the referee charges it" % i)


func test_the_wire_refuses_a_tax_row_naming_a_card_the_view_lacks() -> void:
	put_battlefield(1, "Heat Wave")
	var ogre := put_battlefield(1, "Gray Ogre")
	put_battlefield(0, "Grizzly Bears")
	_attack_into_blocks([ogre])
	var view := referee.view(0)
	assert_true(SgViewProtocol.game(view), "control")
	var row: Array = view.presentation.block_taxes[0]
	var forged := view.duplicate(true)
	forged.presentation.block_taxes[0][2] = row[2] + ["c999"]
	assert_false(SgViewProtocol.game(forged), "an attacker the view never carried")
	forged = view.duplicate(true)
	forged.presentation.block_taxes[0][3] = row[3] + ["c999"]
	assert_false(SgViewProtocol.game(forged), "a blocker the view never carried")
	forged = view.duplicate(true)
	forged.presentation.block_taxes[0] = [row[0], 1, row[2]]
	assert_false(SgViewProtocol.block_taxes(forged.presentation.block_taxes), "protocol 26's shape is gone")
	forged = view.duplicate(true)
	forged.presentation.block_taxes[0][1] = 0
	assert_false(SgViewProtocol.block_taxes(forged.presentation.block_taxes), "a tax costs at least 1 life")


func test_a_room_that_fails_the_check_is_reported_not_dropped_silently() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var screen := _screen()
	await _pump()
	var hand := screen.game.players[0].hand.size()
	var broken := _room(0, 2)
	broken.game.presentation.block_taxes = [["o1", 0, [], []]]
	assert_false(SgViewProtocol.room(broken), "control: the room is invalid")
	screen.present(broken, true, false)
	assert_string_contains(screen._prompt_label.text, "could not be shown",
		"the screen says the host's table failed its check")
	assert_eq(int(screen._room.revision), 1, "the last valid table stays")
	assert_eq(screen.game.players[0].hand.size(), hand)


func test_the_host_never_sends_a_view_its_own_check_refuses() -> void:
	var server := SgLocalServer.new()
	add_child_autofree(server)
	assert_eq(server.start_local(0), OK)
	var a := SgLocalClient.new()
	var b := SgLocalClient.new()
	add_child_autofree(a)
	add_child_autofree(b)
	var until := func(predicate: Callable) -> bool:
		for i in 400:
			if predicate.call(): return true
			await get_tree().process_frame
		return false
	var act := func(client: SgLocalClient, action: Dictionary) -> void:
		assert_true(client.command(action), "command accepted: %s" % [action])
		await until.call(func() -> bool: return not client.busy())
		for i in 3: await get_tree().process_frame
	assert_eq(a.connect_local(server.port, server.access_code), OK)
	assert_eq(b.connect_local(server.port, server.access_code), OK)
	assert_true(await until.call(func() -> bool: return a.online and b.online), "paired")
	await act.call(a, {"op": "host", "name": "Heat table", "decks": "own", "deck": {}})
	await act.call(b, {"op": "join", "room": a.state.room.id})
	var room_id: String = a.state.room.id
	await act.call(a, {"op": "ready", "value": true})
	await act.call(b, {"op": "ready", "value": true})
	assert_true(await until.call(func() -> bool: return not b.state.room.get("game", {}).is_empty()), "the duel is dealt")
	server._rooms[room_id].match = InvalidViews.new(42)
	server._publish()
	assert_true(await until.call(func() -> bool: return not b.online), "the seat whose view failed is stopped")
	assert_string_contains(b.status, "failed its own check",
		"the guest reads why instead of \"Host sent an invalid response\"")
	for i in 6: await get_tree().process_frame
	assert_true(a.online, "the other seat's valid view still arrives")
	assert_true(SgViewProtocol.room(a.state.room))
	a.forget()
	b.forget()
	server.stop()


# ============================================ H8-3 Circling Vultures --

func test_the_referee_keeps_the_card_whose_cast_is_being_announced() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var vultures := give_hand(0, "Circling Vultures")
	var other := give_hand(0, "Circling Vultures")
	add_mana(0, Mtg.ManaColor.B)
	var handle := referee._handle(0, vultures)
	assert_ok(referee.act(0, {"op": "prepare", "card": handle, "kind": "spell", "index": 0, "x": 0, "mode": 0}))
	assert_false(referee.actions.draft.is_empty(), "control: the cast is announced")
	assert_refused(referee.act(0, {"op": "discard_special", "card": handle}), "announc")
	assert_eq(vultures.zone, Mtg.Zone.HAND, "the announced card stays in the hand")
	assert_false(referee.actions.draft.is_empty(), "the announcement is still open")
	assert_ok(referee.act(0, {"op": "discard_special", "card": referee._handle(0, other)}))
	assert_eq(other.zone, Mtg.Zone.GRAVEYARD, "another Vultures is still the seat's to discard")
	assert_ok(referee.act(0, {"op": "submit", "targets": []}))
	assert_eq(vultures.zone, Mtg.Zone.STACK, "the announced cast completes")
	resolve_stack()
	assert_eq(vultures.zone, Mtg.Zone.BATTLEFIELD)


func test_a_cancelled_announcement_frees_the_card_for_the_special_discard() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var vultures := give_hand(0, "Circling Vultures")
	var handle := referee._handle(0, vultures)
	assert_ok(referee.act(0, {"op": "prepare", "card": handle, "kind": "spell", "index": 0, "x": 0, "mode": 0}))
	assert_ok(referee.act(0, {"op": "cancel"}))
	assert_ok(referee.act(0, {"op": "discard_special", "card": handle}))
	assert_eq(vultures.zone, Mtg.Zone.GRAVEYARD)


# ========================== H8-6 the pile ring at a networked table --

## [param card_name] exiled face down off the top of seat 0's library, seat
## 0 alone may look at it and play it (Three Wishes' shape).
func _exiled_for_play(card_name: String) -> CardInstance:
	var inst := _make_instance(0, card_name)
	inst.zone = Mtg.Zone.LIBRARY
	g.players[0].library.append(inst)
	var exiled := g.exile_top_of_library(0, true, 0)
	g.grant_exile_play(exiled, 0, true)
	return exiled


## [param active]'s [param step], seat 0 holding priority.
func _window(active: int, step: int) -> void:
	g._probing = true
	g.active_player = active
	g._enter_step(Mtg.STEP_ORDER.find(step))
	g.priority_player = 0
	g._passes = 0 if active == 0 else 1
	g._probing = false


func _local_of(screen: SgDuelView, card: CardInstance) -> CardInstance:
	return screen.game.find_instance(screen.projection.local_id(referee._handle(0, card)))


## Is [param card] ringed in the open graveyard/exile view?
func _ringed(screen: SgDuelView, card: CardInstance) -> bool:
	screen._repopulate_graveyard()
	var local := _local_of(screen, card)
	for key in screen._grave_view._shelves:
		for face in screen._grave_view._shelves[key].widgets:
			if (face as MiniCard).instance == local:
				return face.find_child("PlayableRing", false, false) != null
	fail_test("the card is not on a shelf")
	return false


func test_the_networked_pile_rings_an_exiled_land_only_while_a_land_drop_is_open() -> void:
	var forest := _exiled_for_play("Forest")
	_window(1, Mtg.Step.END)
	var screen := _screen()
	await _pump()
	assert_true(screen.game.can_play_from_exile(0, _local_of(screen, forest)), "control: the seat may play it from exile")
	screen._on_grave_pile_clicked(0)
	assert_true(screen.graveyard_is_open(), "control: the view is open")
	if not screen.graveyard_is_open(): return
	assert_false(_ringed(screen, forest), "no land drop on the opponent's turn: no ring")
	_window(0, Mtg.Step.MAIN1)
	screen.present(_room(0, 2), true, false)
	await _pump()
	assert_true(_ringed(screen, forest), "the seat's own main phase, the drop unspent: the ring")
	var island := give_hand(0, "Island")
	assert_ok(g.play_land(0, island))
	screen.present(_room(0, 3), true, false)
	await _pump()
	assert_false(_ringed(screen, forest), "the land drop spent: no ring")
	assert_false(referee.view(0).presentation.cards.is_empty())


func test_the_networked_pile_rings_an_exiled_spell_only_when_it_can_be_paid() -> void:
	var bolt := _exiled_for_play("Lightning Bolt")
	_window(1, Mtg.Step.END)
	var screen := _screen()
	await _pump()
	screen._on_grave_pile_clicked(0)
	assert_false(_ringed(screen, bolt), "an instant on their turn, but no red mana to pay for it")
	put_battlefield(0, "Mountain")
	screen.present(_room(0, 2), true, false)
	await _pump()
	assert_true(_ringed(screen, bolt), "an untapped Mountain pays for it: the ring")


func test_the_network_special_actions_still_show_beside_the_gated_local_menu() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var channel := give_hand(0, "Channel")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, channel))
	resolve_stack()
	assert_true(g.players[0].life_for_mana, "control: Channel resolved")
	var labels: Array = referee.view(0).specials
	assert_eq(labels.size(), 1, "the referee offers the special action")
	var screen := _screen()
	screen.action_requested.connect(func(action: Dictionary) -> void: assert_eq(referee.act(0, action), ""))
	await _pump()
	assert_eq(screen._special_actions(0), [], "the local screen's own door stays shut at a network table")
	screen._show_specials()
	var line: Button = null
	for button: Button in screen._network_dialog.find_children("*", "Button", true, false):
		if button.text == String(labels[0]): line = button
	assert_not_null(line, "the network Special actions window lists it")
	if line == null: return
	assert_false(line.disabled, "and it can be taken")
	line.pressed.emit()
	assert_eq(g.players[0].life, 19, "1 life paid at the referee")
	assert_eq(g.players[0].mana_pool.total(), 1, "for one colorless mana")


# ======================================= a land's entry payment's decline --

## Lotus Vale's payment holds the land drop on an optional COST card question
## (MtgGame.play_land). Its decline line says what declining does — the
## land goes to the graveyard — so it is not mistaken for the `cancel` op,
## which withdraws the play.
func test_an_entry_payments_decline_line_names_the_graveyard() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var forest := put_battlefield(0, "Forest")
	var plains := put_battlefield(0, "Plains")
	var vale := give_hand(0, "Lotus Vale")
	assert_ok(referee.act(0, {"op": "play", "card": referee._handle(0, vale)}))
	var question: Dictionary = referee.view(0).choice
	assert_false(question.is_empty(), "control: the land drop is held on the payment")
	if question.is_empty(): return
	assert_true(bool(question.cancel), "control: Cancel withdraws the play")
	var options: Array = question.options
	assert_eq(String(options.back()), "Put Lotus Vale into its owner's graveyard.",
		"the decline line is not worded like the withdrawal")
	assert_false(options.has("Choose none"))
	var screen := _screen()
	await _pump()
	assert_eq(String(screen.game.awaiting_choice.options.back()), "Put Lotus Vale into its owner's graveyard.",
		"the networked overlay reads the referee's line")
	assert_ok(referee.act(0, {"op": "cancel"}))
	assert_eq(vale.zone, Mtg.Zone.HAND, "control: the cancel op withdraws")
	assert_eq(g.players[0].lands_played_this_turn, 0)
	assert_ok(referee.act(0, {"op": "play", "card": referee._handle(0, vale)}))
	options = referee.view(0).choice.options
	assert_ok(referee.act(0, {"op": "choice", "picks": [options.size() - 1]}))
	assert_null(g.awaiting_choice)
	assert_eq(vale.zone, Mtg.Zone.GRAVEYARD, "the line does what it says")
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(plains.zone, Mtg.Zone.BATTLEFIELD)


func test_an_optional_card_question_that_is_no_entry_payment_still_says_choose_none() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var tutor := give_hand(0, "Demonic Tutor")
	give_hand(0, "Lotus Vale")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(referee.act(0, {"op": "prepare", "card": referee._handle(0, tutor), "kind": "spell", "index": 0, "x": 0, "mode": 0}))
	assert_ok(referee.act(0, {"op": "submit", "targets": []}))
	for _i in 6:
		if g.awaiting_choice != null: break
		g.pass_priority(g.priority_player)
	assert_not_null(g.awaiting_choice, "control: the search asks")
	if g.awaiting_choice == null: return
	assert_eq(String(referee.view(0).choice.options.back()), "Choose none", "a search's decline is no land's")


# ================================================== H8-7 Firestorm's X --

func test_firestorm_s_x_is_bounded_by_the_targets_it_must_name() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var storm := give_hand(0, "Firestorm")
	for i in 4: give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.R)
	assert_eq(_spell_budget(referee.view(0), storm), 2,
		"four cards to discard, but only the two players to aim at")
	var screen := _screen()
	await _pump()
	var local := screen.game.find_instance(screen.projection.local_id(referee._handle(0, storm)))
	screen._click_hand_card(local)
	assert_not_null(screen._x_dialog, "X is asked")
	if screen._x_dialog == null: return
	assert_eq(int(screen._x_spin.max_value), 2, "the networked X window offers no X it cannot aim")
	screen._on_x_canceled()
	for i in 3: put_battlefield(1, "Grizzly Bears")
	assert_eq(_spell_budget(referee.view(0), storm), 4, "five targets: the hand is the bound again")


func test_an_x_target_mana_spell_is_bounded_by_its_targets_over_the_network() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var word := give_hand(0, "Word of Binding")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.B, 7)
	assert_eq(_spell_budget(referee.view(0), word), 2, "five mana spare, two creatures to tap")
	assert_ok(referee.act(0, {"op": "autoprepare", "card": referee._handle(0, word), "kind": "spell",
		"index": 0, "mode": 0, "excluded": [], "count": 1}))
	assert_eq(int(referee.actions.draft.x), 2, "the auto-cast never pays for targets that are not there")
