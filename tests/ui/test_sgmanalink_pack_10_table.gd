extends GameTest
## PACK 10 (THE URZA BLOCK) AT AN SGMANALINK TABLE — the block's new ways
## for a HUMAN seat to act from somewhere other than its own permanents,
## played through the referee (`SgPracticeMatch`) and the real networked
## screen (`SgDuelView`), with the printed cards.
##
##  * Cycling (CR 702.29a): an ability that works from the HAND. The
##    referee offered it as the existing "ability" action of a hand card,
##    but the networked screen's click cast the card and no menu offered
##    "Cycling {2}": the face lists a hand card's abilities by cost alone.
##  * Yawgmoth's Will: "you may play lands ... from your graveyard". The
##    referee offered a graveyard spell's cast, never a land's play
##    (`_playable`, the `play` op), and the graveyard view did not ring it.
##  * Temporal Aperture: "you may play that card [the revealed top of your
##    library]". The view carried the top card as a name only; protocol 31
##    sends it as a card of the view (`library_top`) to the seat that may
##    see it, and the library pile's click plays it through the referee.
##  * The protocol and rules revision that carry them.

var referee: SgPracticeMatch
var revision := 1
var commands: Array = []
var refusals: Array = []


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super.before_each()
	referee = SgPracticeMatch.new(42)
	referee.game = g
	revision = 1
	commands.clear()
	refusals.clear()
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	referee = null
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


# ---------------------------------------------------------------- fixture --

func _room(seat := 0) -> Dictionary:
	return {"id": "r1", "name": "Pack ten", "seat": seat,
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
	screen.action_requested.connect(_act.bind(screen, seat))
	screen.present(_room(seat), true, false)
	return screen


func _act(action: Dictionary, screen: SgDuelView, seat: int) -> void:
	commands.append(action.duplicate(true))
	var error := referee.act(seat, action)
	if not error.is_empty():
		refusals.append(error)
		screen.show_notice(error)
	else: revision += 1
	screen.present.call_deferred(_room(seat), true, false)


func _pump() -> void:
	for i in 8: await get_tree().process_frame


func _local(screen: SgDuelView, card: CardInstance) -> CardInstance:
	return screen.game.find_instance(screen.projection.local_id(referee._handle(int(screen._room.seat), card)))


## [param card]'s face in [param view] (built for [param viewer]), or {}.
func _face(view: Dictionary, card: CardInstance, viewer := 0) -> Dictionary:
	var handle := referee._handle(viewer, card)
	var zones: Array = [view.hand]
	for p in view.players:
		for key in ["battlefield", "graveyard", "exile", "ante", "revealed", "phased_out", "library_top"]:
			zones.append(p[key])
	for zone in zones:
		for face in zone:
			if face.id == handle: return face
	return {}


func _row(view: Dictionary, card: CardInstance, viewer := 0) -> Dictionary:
	var handle := referee._handle(viewer, card)
	for row in view.presentation.cards:
		if row.id == handle: return row
	return {}


static func _cycling_index(inst: CardInstance) -> int:
	for i in inst.cur_activated_abilities.size():
		if inst.cur_activated_abilities[i].is_cycling:
			return i
	return -1


## The hand action menu's line [param id]: [text, disabled], or [] if absent.
static func _menu_line(screen: SgDuelView, id: int) -> Array:
	var at := screen._hand_action_menu.get_item_index(id)
	if at < 0:
		return []
	return [screen._hand_action_menu.get_item_text(at), screen._hand_action_menu.is_item_disabled(at)]


func _left_click_library(screen: SgDuelView, pid := 0) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	screen._on_pile_input(click, pid)


func _on_top(pid: int, card_name: String) -> CardInstance:
	var inst := give_hand(pid, card_name)
	g.put_from_hand_on_top_of_library(inst)
	assert_eq(g.players[pid].library.back(), inst)
	return inst


# ======================================================= the version stamp --

func test_protocol_31_and_the_urza_block_rules_revision() -> void:
	assert_eq(SgProtocol.VERSION, 31)
	assert_eq(SgProtocol.SUBPROTOCOL, "sgmanalink-local-v31")
	assert_eq(SgCompatibility.RULES_REVISION, "sgmanalink-urza-block-2026-11-06")
	assert_true(SgCompatibility.valid_stamp(SgCompatibility.stamp()), "the stamp's rules text fits the wire")
	assert_true(SgProtocol.subprotocols().has("sgmanalink-local-v30"),
		"the last protocol is still named, so a 30 build is told, not hung up on")


# ================================================ cycling from the hand --

func test_clear_offers_cast_and_cycling_on_the_networked_screen() -> void:
	var clear := give_hand(0, "Clear")
	add_mana(0, Mtg.ManaColor.C, 2)
	var index := _cycling_index(clear)
	assert_gt(index, -1, "the printed Clear cycles")
	var screen := _screen()
	await _pump()
	var local := _local(screen, clear)
	assert_eq(DuelScreen._hand_ability_indices(local), [index] as Array[int],
		"the projection knows the hand ability from the shared catalogue")
	screen._click_hand_card(local)
	assert_eq(screen._hand_action_inst, local, "the click asks which, as at a local table")
	assert_eq(_menu_line(screen, DuelScreen.HAND_ACTION_CAST), ["Cast Clear", false])
	assert_eq(_menu_line(screen, DuelScreen.HAND_ACTION_ABILITY_BASE + index), ["Cycling {2}", false])
	assert_eq(commands, [], "opening the menu sends nothing")


func test_clear_is_cycled_through_the_referee() -> void:
	var clear := give_hand(0, "Clear")
	add_mana(0, Mtg.ManaColor.C, 2)
	var hand_before := g.players[0].hand.size()
	var screen := _screen()
	await _pump()
	var local := _local(screen, clear)
	screen._click_hand_card(local)
	screen._on_hand_action_chosen(DuelScreen.HAND_ACTION_ABILITY_BASE + _cycling_index(clear))
	await _pump()
	assert_eq(refusals, [])
	assert_eq(String(commands[0].op), "prepare")
	assert_eq(String(commands[0].kind), "ability", "the existing ability action")
	assert_eq(clear.zone, Mtg.Zone.GRAVEYARD, "discarded as the cost, at the referee")
	assert_eq(g.stack.size(), 1, "the cycling ability uses the stack")
	assert_eq(screen.game.players[0].graveyard.size(), 1, "the projection followed the referee")
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand_before - 1 + 1, "one discarded, one drawn")


func test_cycling_waits_for_its_mana_then_the_auto_tap_pays_it() -> void:
	var clear := give_hand(0, "Clear")
	var plains: Array = [put_battlefield(0, "Plains"), put_battlefield(0, "Plains")]
	var screen := _screen()
	await _pump()
	screen._click_hand_card(_local(screen, clear))
	screen._on_hand_action_chosen(DuelScreen.HAND_ACTION_ABILITY_BASE + _cycling_index(clear))
	await _pump()
	assert_eq(screen.mode, DuelScreen.Mode.PAYING, "the submit was refused for its mana: the seat taps")
	assert_eq(clear.zone, Mtg.Zone.HAND, "nothing paid, nothing discarded")
	screen._auto_tap_for_pending()
	await _pump()
	await _pump()
	assert_true(plains[0].tapped and plains[1].tapped, "the referee's auto-tap paid {2}")
	assert_eq(clear.zone, Mtg.Zone.GRAVEYARD, "and the activation went through")
	assert_eq(g.stack.size(), 1)


func test_cycling_is_greyed_without_reachable_mana() -> void:
	var clear := give_hand(0, "Clear")
	var screen := _screen()
	await _pump()
	var local := _local(screen, clear)
	screen._click_hand_card(local)
	var line := _menu_line(screen, DuelScreen.HAND_ACTION_ABILITY_BASE + _cycling_index(clear))
	assert_eq(line, ["Cycling {2}", true], "the referee offers no payment it would refuse")
	assert_eq(screen._hand_ability_refusal(local, _cycling_index(clear)), SgDuelView.HAND_ABILITY_UNAVAILABLE)
	screen._start_hand_ability(local, _cycling_index(clear))
	assert_eq(commands, [], "a greyed line sends nothing")


func test_a_cycling_land_is_played_or_cycled_over_the_network() -> void:
	var isle := give_hand(0, "Remote Isle")
	var screen := _screen()
	await _pump()
	var local := _local(screen, isle)
	screen._click_hand_card(local)
	assert_eq(_menu_line(screen, DuelScreen.HAND_ACTION_CAST), ["Play Remote Isle", false])
	assert_eq(_menu_line(screen, DuelScreen.HAND_ACTION_ABILITY_BASE + _cycling_index(isle)).size(), 2)
	screen._on_hand_action_chosen(DuelScreen.HAND_ACTION_CAST)
	await _pump()
	assert_eq(refusals, [])
	assert_eq(isle.zone, Mtg.Zone.BATTLEFIELD, "played as the land drop through the referee")


func test_a_cycling_card_is_a_response_but_holds_the_orders_only_floated() -> void:
	give_hand(0, "Clear")
	put_battlefield(0, "Plains")
	put_battlefield(0, "Plains")
	var view := referee.view(0)
	assert_true(bool(view.presentation.respond), "cycling with two lands to tap: a response")
	assert_false(bool(view.presentation.floating), "...that holds no standing order")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_true(bool(referee.view(0).presentation.floating), "{2} floated for it does")


# ============================================ Yawgmoth's Will's lands --

func _will_resolved() -> void:
	var will := give_hand(0, "Yawgmoth's Will")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, will))
	resolve_stack()


func test_a_graveyard_land_under_yawgmoths_will_is_offered_to_its_owner_only() -> void:
	var forest := give_hand(0, "Forest")
	g.card_to_graveyard_from_anywhere(forest)
	var view := referee.view(0)
	assert_false(bool(_face(view, forest).get("zone_playable", true)), "control: no permission")
	assert_false(bool(_face(view, forest).get("playable", true)))
	_will_resolved()
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)
	view = referee.view(0)
	assert_true(SgViewProtocol.game(view), "the view stays valid")
	assert_true(bool(_face(view, forest).get("zone_playable", false)), "the Will covers it")
	assert_true(bool(_face(view, forest).get("playable", false)), "and the land drop is open")
	var theirs := referee.view(1)
	assert_true(SgViewProtocol.game(theirs))
	assert_false(bool(_face(theirs, forest, 1).get("zone_playable", true)), "never the other seat's")
	assert_false(bool(_face(theirs, forest, 1).get("playable", true)))


func test_a_graveyard_land_is_played_from_the_networked_graveyard_view() -> void:
	var forest := give_hand(0, "Forest")
	g.card_to_graveyard_from_anywhere(forest)
	_will_resolved()
	var screen := _screen()
	await _pump()
	var local := _local(screen, forest)
	assert_true(screen.game.can_play_from_zone(0, local), "the face says the Will covers it")
	assert_true(screen._pile_card_playable(0, local), "the graveyard view rings it")
	screen._on_graveyard_card(local)
	await _pump()
	assert_eq(refusals, [])
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD, "played from the graveyard")
	assert_eq(g.players[0].lands_played_this_turn, 1, "as the turn's land drop")


func test_the_referee_judges_a_graveyard_land_play() -> void:
	var forest := give_hand(0, "Forest")
	g.card_to_graveyard_from_anywhere(forest)
	assert_refused(referee.act(0, {"op": "play", "card": referee._handle(0, forest)}), "Card unavailable")
	_will_resolved()
	put_battlefield(0, "Island")
	g.players[0].lands_played_this_turn = 1
	var face := _face(referee.view(0), forest)
	assert_true(bool(face.get("zone_playable", false)), "still covered")
	assert_false(bool(face.get("playable", true)), "but the land drop is spent")
	assert_refused(referee.act(0, {"op": "play", "card": referee._handle(0, forest)}), "already played a land")
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)


# ===================================== Temporal Aperture's library top --

func test_the_permitted_library_top_is_a_card_of_its_owners_view_only() -> void:
	var bears := _on_top(0, "Grizzly Bears")
	var view := referee.view(0)
	assert_eq(view.players[0].library_top, [], "control: a library card is a count")
	g.grant_zone_play(0, {"zone": Mtg.Zone.LIBRARY, "card": bears, "lands": true,
		"spells": true, "free": true, "desc": "the revealed top card of their library"})
	view = referee.view(0)
	assert_true(SgViewProtocol.game(view), "the view stays valid")
	assert_eq(view.players[0].library_top.size(), 1)
	var face := _face(view, bears)
	assert_eq(face.get("name"), "Grizzly Bears")
	assert_true(bool(face.get("zone_playable", false)))
	var modes: Array = []
	for option in face.get("actions", []):
		if option.kind == "spell": modes = option.modes
	assert_eq(modes.size(), 2, "the printed row and the free one: %s" % str(modes))
	assert_string_contains(str(modes), "Without paying its mana cost")
	assert_true(bool(_row(view, bears).get("castable", false)), "the free row is open")
	var theirs := referee.view(1)
	assert_true(SgViewProtocol.game(theirs))
	assert_eq(theirs.players[0].library_top, [], "not revealed: the other seat sees a count")
	assert_false(SgProtocol.encode(theirs).contains("Grizzly Bears"), "rule 8: nothing names it")


func test_temporal_aperture_reveals_the_top_to_both_and_offers_it_to_its_owner() -> void:
	var aperture := put_battlefield(0, "Temporal Aperture")
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(referee.act(0, {"op": "prepare", "card": referee._handle(0, aperture),
		"kind": "ability", "index": 0, "x": 0, "mode": 0}))
	assert_ok(referee.act(0, {"op": "submit", "targets": []}))
	resolve_stack()
	var top: CardInstance = g.players[0].library.back()
	assert_eq(g.revealed_top_card(0), top, "played with the top card revealed")
	var mine := referee.view(0)
	var theirs := referee.view(1)
	assert_true(SgViewProtocol.game(mine))
	assert_true(SgViewProtocol.game(theirs))
	assert_eq(mine.players[0].library_top.size(), 1)
	assert_eq(theirs.players[0].library_top.size(), 1, "revealed: a card of both views")
	assert_true(bool(_face(mine, top).get("zone_playable", false)))
	assert_true(bool(_face(mine, top).get("playable", false)), "a land, the drop open")
	assert_false(bool(_face(theirs, top, 1).get("zone_playable", true)), "the permission is the owner's")
	assert_eq(_face(theirs, top, 1).get("actions"), [])
	assert_eq(int(mine.players[0].library_count), g.players[0].library.size(),
		"the rest of the library stays a count: its order is secret")


func test_the_library_pile_click_plays_the_revealed_top_land() -> void:
	var forest := _on_top(0, "Forest")
	g.grant_zone_play(0, {"zone": Mtg.Zone.LIBRARY, "card": forest, "lands": true,
		"spells": true, "free": true})
	var screen := _screen()
	await _pump()
	_left_click_library(screen, 1)
	await _pump()
	assert_eq(commands, [], "the opponent's pile is not ours to play")
	_left_click_library(screen)
	await _pump()
	assert_eq(refusals, [])
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD, "played from the top of the library")
	assert_eq(g.players[0].lands_played_this_turn, 1)


func test_the_library_pile_click_casts_the_top_spell_free() -> void:
	var bears := _on_top(0, "Grizzly Bears")
	g.grant_zone_play(0, {"zone": Mtg.Zone.LIBRARY, "card": bears, "lands": true,
		"spells": true, "free": true})
	add_mana(0, Mtg.ManaColor.G, 2)   # the printed cost is affordable...
	var screen := _screen()
	await _pump()
	_left_click_library(screen)
	assert_not_null(screen._mode_overlay, "the payment rows: the printed cost or free")
	var greyed: Array = []
	var open: Array = []
	if screen._mode_overlay != null:
		for button in screen._mode_overlay.find_children("*", "Button", true, false):
			if button.text == "Cancel": continue
			if button.disabled: greyed.append(button.text)
			else: open.append(button.text)
	assert_eq(greyed.size(), 1, "...but the printed row is greyed: %s" % str(greyed))
	assert_eq(open.size(), 1)
	assert_string_contains(str(open), "Without paying its mana cost")
	screen._on_mode_chosen(1)
	await _pump()
	assert_eq(refusals, [])
	assert_eq(g.stack.size(), 1, "cast through the referee")
	assert_eq(g.stack.back().card, bears)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 2, "without paying its mana cost")


# ================================== a held question on the guest's screen --
# The referee half of every Pack 10 question is
# tests/unit/test_sgmanalink_pack_10_questions.gd; these two drive the
# guest's own networked screen through one yes/no and one hand card.

func _until_asked() -> PlayerChoice:
	var guard := 0
	while g.awaiting_choice == null and not g.game_over and guard < 800:
		_advance_once()
		guard += 1
	return g.awaiting_choice


## The line of the guest screen's open question that begins with [param prefix].
static func _screen_line(screen: SgDuelView, prefix: String) -> int:
	var lines: Array = screen.game.awaiting_choice.options if screen.game.awaiting_choice != null else []
	for i in lines.size():
		if String(lines[i]).begins_with(prefix):
			return i
	return -1


func test_the_guest_screen_answers_its_echo() -> void:
	var patrol := put_battlefield(1, "Goblin Patrol")
	put_battlefield(1, "Mountain")
	assert_not_null(_until_asked())
	var screen := _screen(1)
	await _pump()
	assert_not_null(screen._choice_overlay, "the question opens on the guest's screen")
	assert_eq(screen.game.awaiting_choice.pid, 0, "as the guest's own question")
	assert_string_contains(screen.game.awaiting_choice.prompt, "Pay echo")
	var no := _screen_line(screen, "No")
	assert_ne(no, -1)
	screen._on_choice_option(no)
	await _pump()
	assert_eq(refusals, [])
	assert_null(g.awaiting_choice)
	assert_eq(patrol.zone, Mtg.Zone.GRAVEYARD, "declined: sacrificed")


func test_the_guest_screen_picks_its_show_and_tell_card() -> void:
	var spell := give_hand(0, "Show and Tell")
	var wurm := give_hand(1, "Craw Wurm")
	give_hand(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, spell))
	assert_not_null(_until_asked())
	assert_eq(g.awaiting_choice.pid, 1, "the host seat has nothing to show: the guest is asked")
	var screen := _screen(1)
	await _pump()
	assert_not_null(screen._choice_overlay)
	screen._on_choice_option(_screen_line(screen, "Yes"))
	await _pump()
	assert_eq(refusals, [])
	var at := _screen_line(screen, "Craw Wurm")
	assert_ne(at, -1, "the guest's own hand card is a line: %s" % str(screen.game.awaiting_choice.options \
		if screen.game.awaiting_choice != null else []))
	if at < 0:
		return
	screen._on_choice_option(at)
	await _pump()
	assert_eq(refusals, [])
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD, "put onto the battlefield")
	assert_eq(wurm.controller_id, 1)
