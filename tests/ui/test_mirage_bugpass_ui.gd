extends GutTest
## THE MIRAGE BUG PASS, DUEL SCREEN AND HELP (2026-10-04) — what a human
## seat at a LOCAL table could not do, or was told wrongly, with Pack 8 on:
##
##  * H1-F1 — THE SEAT'S SPECIAL ACTIONS. Sabertooth Cobra's "unless they pay
##    {2} before that step" ransom (`MtgGame.settle_delayed_trigger`),
##    Channel's life for mana (`pay_life_for_mana`) and Guardian Angel's paid
##    point of prevention (`pay_for_prevention`) were reachable only by the
##    AI, the SGManalink referee and tests. They are now on the payer's
##    territory menu (and the card concerned), the Cobra's ransom holds the
##    last window before it is due, and the Situation Bar names it.
##  * H8-2 — a spell's "as an additional cost" OBJECT cost is part of the
##    castable light and of the response test (Wicked Reward with nothing to
##    sacrifice is no response).
##  * H8-3 — Circling Vultures cannot be discarded while its own cast waits.
##  * H8-6 — the graveyard/exile view rings only what can be played NOW.
##  * H8-7 — an "X targets" X is bounded by the targets that exist.
##  * H8-8 — Heat Wave's "(Blocking costs N life.)" survives a take-back.
##  * H2-S1 — the tutor's pre-cast library picker lists names sorted, never
##    in library order (Cancel does not shuffle).
##  * H8-4 / H8-5 — Help: Heart of Bogardan triggers on its OWN unpaid
##    upkeep; the shared reprints are named by where their script lives.

var screen: DuelScreen
var _saved_stops: Variant = null


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	_saved_stops = Settings.get_value(PhaseStops.SETTING_KEY, null) \
		if Settings.has_value(PhaseStops.SETTING_KEY) else null
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 0.0
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.stops.clear_all()
	screen.game.players[0].hand.clear()
	screen.game.players[1].hand.clear()


func after_each() -> void:
	CardPacks.set_enabled("pack-8", false)
	if _saved_stops == null:
		Settings.clear_value(PhaseStops.SETTING_KEY)
	else:
		Settings.set_value(PhaseStops.SETTING_KEY, _saved_stops)


# ---------------------------------------------------------------- fixture --

func _window(active: int, step: int) -> MtgGame:
	var g: MtgGame = screen.game
	g._probing = true
	g.active_player = active
	g._enter_step(Mtg.STEP_ORDER.find(step))
	g.awaiting_attackers = false
	g.awaiting_blockers = false
	g.priority_player = 0
	g._passes = 0 if active == 0 else 1
	g._probing = false
	screen.mode = DuelScreen.Mode.NORMAL
	return g


func _stop_here() -> void:
	var here: Array = screen._phase_key()
	screen.stops.set_marked(here[0], here[1], here[2], true)


func _make(pid: int, card_name: String, zone: int) -> CardInstance:
	var g: MtgGame = screen.game
	var data := CardRegistry.get_card(card_name)
	assert_not_null(data, card_name)
	var inst := CardInstance.new(data, g._next_instance_id, pid)
	g._next_instance_id += 1
	g._probing = true
	g._instances[inst.id] = inst
	match zone:
		Mtg.Zone.HAND:
			inst.zone = Mtg.Zone.HAND
			g.players[pid].hand.append(inst)
		Mtg.Zone.LIBRARY:
			inst.zone = Mtg.Zone.LIBRARY
			g.players[pid].library.append(inst)   # the top is the back
		Mtg.Zone.BATTLEFIELD:
			g._put_on_battlefield(inst, pid)
			inst.summoning_sick = false
	g.recalculate()
	g._probing = false
	return inst


## Resolve the chain by passing for whoever holds priority — the engine's
## own passes, synchronously, so no AI beat runs in between.
func _resolve(g: MtgGame) -> void:
	var guard := 0
	while not g.stack.is_empty() and guard < 20:
		assert_eq(g.pass_priority(g.priority_player), "")
		guard += 1


## The id of the first item of [param menu] whose text starts with
## [param prefix], or -1.
static func _item(menu: PopupMenu, prefix: String) -> int:
	for i in menu.get_item_count():
		if menu.get_item_text(i).begins_with(prefix):
			return menu.get_item_id(i)
	return -1


static func _item_live(menu: PopupMenu, id: int) -> bool:
	var at := menu.get_item_index(id)
	return at >= 0 and not menu.is_item_disabled(at)


## The AI's Sabertooth Cobra bites the human seat for real (the trigger
## resolves through the engine), leaving its {2} ransom pending.
func _bitten_by_a_cobra() -> CardInstance:
	var g := _window(1, Mtg.Step.MAIN2)
	var cobra := _make(1, "Sabertooth Cobra", Mtg.Zone.BATTLEFIELD)
	g.deal_damage(cobra, TargetRef.player(0), 2)
	g.priority_player = 1
	_resolve(g)
	assert_eq(g.players[0].poison, 1, "the bite's first counter")
	assert_eq(g.settleable_delayed_triggers(0).size(), 1, "control: the ransom is pending")
	return cobra


## Pass for whoever holds priority until the human seat's own draw step
## (a Stop on it keeps the automatic pass from walking past) — through the
## untap step and the upkeep the Cobra's second counter is due in.
func _walk_to_my_draw(g: MtgGame) -> void:
	screen.stops.set_marked(PhaseStops.half_for_seat(0, screen._human_seat()),
		PhaseStops.Bar.PHASE, DuelScreen._phase_icon_slot(Mtg.Step.DRAW), true)
	var guard := 0
	while not (g.active_player == 0 and g.current_step() == Mtg.Step.DRAW) \
			and not g.game_over and guard < 40:
		assert_eq(g.pass_priority(g.priority_player), "")
		guard += 1
	assert_eq(g.active_player, 0, "the human's turn")
	assert_eq(g.current_step(), Mtg.Step.DRAW, "past their upkeep")


# ======================================================== H1-F1: specials --

## The control for the walk below: unpaid, the second counter arrives.
func test_cobra_ransom_unpaid_poisons_at_the_upkeep() -> void:
	_bitten_by_a_cobra()
	var g := _window(1, Mtg.Step.END)
	_walk_to_my_draw(g)
	assert_eq(g.players[0].poison, 2, "control: the second counter at the upkeep")



func test_cobra_ransom_is_paid_from_the_territory_menu() -> void:
	_bitten_by_a_cobra()
	var islands := [_make(0, "Island", Mtg.Zone.BATTLEFIELD), _make(0, "Island", Mtg.Zone.BATTLEFIELD)]
	var g := _window(1, Mtg.Step.END)
	_stop_here()
	screen._refresh()
	screen._open_territory_menu(0, Vector2(100, 400))
	var menu: PopupMenu = screen._territory_menu
	var id := _item(menu, "Pay {2}")
	assert_ne(id, -1, "the ransom is on the bitten seat's territory menu")
	assert_true(_item_live(menu, id), "and live: the seat holds priority and two Islands")
	menu.hide()
	screen._on_territory_menu_chosen(id)
	assert_true(g.settleable_delayed_triggers(0).is_empty(), "paid off")
	assert_true(islands[0].tapped and islands[1].tapped, "the {2} came from the Islands")
	assert_eq(g.players[0].mana_pool.total(), 0, "nothing left floating")
	# Paid in the opponent's end step: the upkeep comes and goes clean.
	_walk_to_my_draw(g)
	assert_eq(g.players[0].poison, 1, "no second poison counter")


func test_cobra_ransom_is_on_the_cobra_s_own_menu_too() -> void:
	var cobra := _bitten_by_a_cobra()
	_make(0, "Island", Mtg.Zone.BATTLEFIELD)
	_make(0, "Island", Mtg.Zone.BATTLEFIELD)
	var g := _window(1, Mtg.Step.END)
	_stop_here()
	screen._open_card_menu(cobra, Vector2(100, 100))
	var menu: PopupMenu = screen._card_menu
	var id := _item(menu, "Pay {2}")
	assert_true(_item_live(menu, id), "right-click the Cobra: Pay {2}")
	menu.hide()
	screen._on_card_menu_chosen(id)
	assert_true(g.settleable_delayed_triggers(0).is_empty(), "paid off from the card")


func test_cobra_ransom_is_greyed_without_the_mana_or_priority() -> void:
	_bitten_by_a_cobra()
	var g := _window(1, Mtg.Step.END)
	_stop_here()
	screen._open_territory_menu(0, Vector2(100, 400))
	var menu: PopupMenu = screen._territory_menu
	var id := _item(menu, "Pay {2}")
	assert_ne(id, -1, "listed")
	assert_false(_item_live(menu, id), "no mana: greyed")
	menu.hide()
	screen._on_territory_menu_chosen(id)
	assert_eq(g.settleable_delayed_triggers(0).size(), 1, "nothing paid")
	_make(0, "Island", Mtg.Zone.BATTLEFIELD)
	_make(0, "Island", Mtg.Zone.BATTLEFIELD)
	g.priority_player = 1
	screen._open_territory_menu(0, Vector2(100, 400))
	assert_false(_item_live(menu, _item(menu, "Pay {2}")), "the other seat's priority: greyed")
	menu.hide()
	# The AI's territory never lists the human's payments as the AI's.
	g.priority_player = 0
	screen._open_territory_menu(1, Vector2(100, 100))
	assert_true(_item_live(menu, _item(menu, "Pay {2}")),
		"the AI's half opens the human's menu (DuelScreen._menu_seat)")
	menu.hide()


## The ransom is a response: the opponent's end step — the last window
## before the upkeep it is due in — is held for it, and the bar says so.
func test_cobra_ransom_holds_the_last_window_and_is_named() -> void:
	_bitten_by_a_cobra()
	var g := _window(1, Mtg.Step.END)
	assert_false(screen._could_respond(0), "control: no mana, nothing to respond with")
	assert_true(screen._auto_pass_applies(), "control: so the end step passes itself")
	assert_eq(screen._special_action_note(), "", "control: nothing payable, nothing said")
	_make(0, "Island", Mtg.Zone.BATTLEFIELD)
	_make(0, "Island", Mtg.Zone.BATTLEFIELD)
	assert_true(screen._could_respond(0), "two Islands pay the ransom")
	assert_false(screen._auto_pass_applies(), "the end step is not passed for the player")
	screen._refresh()
	assert_string_contains(screen._status_message(), "Sabertooth Cobra")
	assert_string_contains(screen._status_message(), "right-click your territory")
	assert_eq(g.current_step(), Mtg.Step.END)


func test_channel_pays_life_for_mana_from_the_territory_menu() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	_stop_here()
	var channel := _make(0, "Channel", Mtg.Zone.HAND)
	g.players[0].mana_pool.add(Mtg.ManaColor.G, 2)
	assert_eq(g.cast_spell(0, channel), "")
	_resolve(g)
	assert_true(g.players[0].life_for_mana, "control: Channel resolved")
	screen.mode = DuelScreen.Mode.NORMAL
	screen._open_territory_menu(0, Vector2(100, 400))
	var menu: PopupMenu = screen._territory_menu
	var id := _item(menu, "Channel")
	assert_true(_item_live(menu, id), "Channel is on the menu")
	menu.hide()
	screen._on_territory_menu_chosen(id)
	assert_eq(g.players[0].life, 19)
	assert_eq(g.players[0].mana_pool.total(), 1, "one colorless mana")


## The Channel-Fireball shape: a cast waiting for its mana (PAYING) — with
## no land to tap, Channel's life is what it waits for — paid point by point
## from the menu, open over the wait.
func test_channel_pays_a_cast_that_waits_for_mana() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	_stop_here()
	g.players[0].life_for_mana = true
	var mine := _make(0, "Howling Mine", Mtg.Zone.HAND)
	screen._click_hand_card(mine)
	assert_eq(screen.mode, DuelScreen.Mode.PAYING, "waiting for {2} (prompt '%s')" % screen._prompt_label.text)
	for i in 2:
		screen._open_territory_menu(0, Vector2(100, 400))
		var id := _item(screen._territory_menu, "Channel")
		assert_true(_item_live(screen._territory_menu, id), "Channel while paying")
		screen._territory_menu.hide()
		screen._on_territory_menu_chosen(id)
	assert_eq(g.stack.size(), 1, "the cast went on the chain (mode %d, prompt '%s')" % [
		screen.mode, screen._prompt_label.text])
	assert_eq(g.players[0].life, 18)
	# Control: without Channel the same cast is refused outright, as ever.
	g.players[0].life_for_mana = false
	_resolve(g)
	var second := _make(0, "Howling Mine", Mtg.Zone.HAND)
	screen._click_hand_card(second)
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL, "no mana and no Channel: refused")


func test_guardian_angel_buys_prevention_from_the_menus() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	_stop_here()
	var bear := _make(0, "Grizzly Bears", Mtg.Zone.BATTLEFIELD)
	var plains := _make(0, "Plains", Mtg.Zone.BATTLEFIELD)
	_make(0, "Plains", Mtg.Zone.BATTLEFIELD)
	g.grant_paid_prevention(0, TargetRef.card(bear), "Guardian Angel",
		CardRegistry.get_card("Guardian Angel"))
	g.grant_paid_prevention(0, TargetRef.player(0), "Guardian Angel",
		CardRegistry.get_card("Guardian Angel"))
	screen._open_territory_menu(0, Vector2(100, 400))
	var menu: PopupMenu = screen._territory_menu
	var on_bear := _item(menu, "Pay {1}: prevent 1 damage to Grizzly Bears")
	var on_me := _item(menu, "Pay {1}: prevent 1 damage to you")
	assert_true(_item_live(menu, on_bear), "the Bears' point")
	assert_true(_item_live(menu, on_me), "the player's point")
	menu.hide()
	screen._on_territory_menu_chosen(on_bear)
	assert_eq(bear.prevention, 1, "one point bought")
	assert_true(plains.tapped, "the {1} was tapped for")
	# The card's own mini-menu offers the same point.
	screen._open_card_menu(bear, Vector2(100, 100))
	var card_id := _item(screen._card_menu, "Pay {1}")
	assert_true(_item_live(screen._card_menu, card_id), "on the Bears' menu")
	screen._card_menu.hide()
	screen._on_card_menu_chosen(card_id)
	assert_eq(bear.prevention, 2, "a second point")
	assert_eq(g.players[0].mana_pool.total(), 0, "nothing left floating")


# ============================================== H8-2: object costs light --

func test_wicked_reward_without_a_creature_is_no_response() -> void:
	var g := _window(1, Mtg.Step.END)
	_make(0, "Swamp", Mtg.Zone.BATTLEFIELD)
	_make(0, "Swamp", Mtg.Zone.BATTLEFIELD)
	_make(1, "Grizzly Bears", Mtg.Zone.BATTLEFIELD)
	var reward := _make(0, "Wicked Reward", Mtg.Zone.HAND)
	assert_false(screen._could_respond(0), "nothing to sacrifice: no response")
	assert_eq(screen._highlight_for(reward), MiniCard.Highlight.NONE, "and not lit")
	g.players[0].mana_pool.add(Mtg.ManaColor.B, 2)
	assert_false(screen._has_affordable_fast_effect(0), "floating {B}{B} does not make it one")
	g.players[0].mana_pool.clear()
	# Control: a creature of the player's own to sacrifice.
	_make(0, "Grizzly Bears", Mtg.Zone.BATTLEFIELD)
	assert_true(screen._could_respond(0), "with a creature to sacrifice it is a response")
	assert_eq(screen._highlight_for(reward), MiniCard.Highlight.OPTIONAL, "and lit")


# =========================================== H8-3: Vultures while casting --

func test_vultures_cannot_be_discarded_while_its_own_cast_waits() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	_stop_here()
	var swamp := _make(0, "Swamp", Mtg.Zone.BATTLEFIELD)
	var vultures := _make(0, "Circling Vultures", Mtg.Zone.HAND)
	screen._click_hand_card(vultures)
	screen._hand_action_menu.hide()
	screen._on_hand_action_chosen(DuelScreen.HAND_ACTION_CAST)
	assert_eq(screen.mode, DuelScreen.Mode.PAYING, "waiting for {B}")
	screen._open_card_menu(vultures, Vector2(100, 100))
	var menu: PopupMenu = screen._card_menu
	var at := menu.get_item_index(DuelScreen.CARD_MENU_DISCARD_SPECIAL)
	assert_true(at >= 0 and menu.is_item_disabled(at), "the discard is greyed while its cast waits")
	menu.hide()
	# Chosen anyway (a stale menu): refused, the cast untouched.
	screen._on_card_menu_chosen(DuelScreen.CARD_MENU_DISCARD_SPECIAL)
	assert_eq(vultures.zone, Mtg.Zone.HAND, "not discarded")
	assert_eq(screen._pending_card, vultures, "the cast still waits")
	# The hand's own Cast/Discard menu, answered stale, refuses the same.
	screen._hand_action_inst = vultures
	screen._on_hand_action_chosen(DuelScreen.HAND_ACTION_DISCARD)
	assert_eq(vultures.zone, Mtg.Zone.HAND, "not discarded from the hand menu either")
	assert_eq(screen.mode, DuelScreen.Mode.PAYING, "still waiting for its {B}")
	# Control: with the cast cancelled the discard is live again.
	screen._on_cancel()
	screen._open_card_menu(vultures, Vector2(100, 100))
	at = menu.get_item_index(DuelScreen.CARD_MENU_DISCARD_SPECIAL)
	assert_true(at >= 0 and not menu.is_item_disabled(at), "live once nothing waits")
	menu.hide()
	assert_eq(g.stack.size(), 0)
	# ...and the cast made afresh is paid by the Swamp: no dead cast.
	screen._click_hand_card(vultures)
	screen._hand_action_menu.hide()
	screen._on_hand_action_chosen(DuelScreen.HAND_ACTION_CAST)
	screen._on_card_clicked(swamp)
	assert_eq(g.stack.size(), 1, "Circling Vultures is cast")


# ============================================== H8-6: the pile's own ring --

func _shelf_widget(inst: CardInstance) -> MiniCard:
	if screen._grave_view == null:
		return null
	for key in screen._grave_view._shelves:
		for face in screen._grave_view._shelves[key].widgets:
			if (face as MiniCard).instance == inst:
				return face
	return null


func _ringed(inst: CardInstance) -> bool:
	var face := _shelf_widget(inst)
	assert_not_null(face, "%s is on a shelf" % inst.data.card_name)
	return face != null and face.find_child("PlayableRing", false, false) != null


func _wish(g: MtgGame, card_name: String) -> CardInstance:
	_make(0, card_name, Mtg.Zone.LIBRARY)
	var card := g.exile_top_of_library(0, true, 0)
	g.grant_exile_play(card, 0, true)
	assert_true(g.can_play_from_exile(0, card), "control: a Three Wishes card")
	return card


func test_an_exiled_land_is_ringed_only_when_a_land_can_be_played() -> void:
	var g := _window(1, Mtg.Step.END)
	_stop_here()
	var land := _wish(g, "Forest")
	screen._on_grave_pile_clicked(0)
	assert_false(_ringed(land), "their turn: no land drop")
	screen._close_graveyard()
	g = _window(0, Mtg.Step.MAIN1)
	_stop_here()
	screen._on_grave_pile_clicked(0)
	assert_true(_ringed(land), "your main phase with the drop unspent")
	screen._close_graveyard()
	g.players[0].lands_played_this_turn = 1
	screen._on_grave_pile_clicked(0)
	assert_false(_ringed(land), "the drop is spent")


func test_an_exiled_spell_is_ringed_only_when_it_can_be_paid() -> void:
	var g := _window(1, Mtg.Step.END)
	_stop_here()
	var bolt := _wish(g, "Lightning Bolt")
	screen._on_grave_pile_clicked(0)
	assert_false(_ringed(bolt), "no red mana: not castable now")
	screen._close_graveyard()
	_make(0, "Mountain", Mtg.Zone.BATTLEFIELD)
	screen._on_grave_pile_clicked(0)
	assert_true(_ringed(bolt), "a Mountain pays for it")


# ============================================ H8-7: X bounded by targets --

func test_firestorm_x_is_bounded_by_the_targets() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	_stop_here()
	var storm := _make(0, "Firestorm", Mtg.Zone.HAND)
	for i in 4: _make(0, "Grizzly Bears", Mtg.Zone.HAND)
	g.players[0].mana_pool.add(Mtg.ManaColor.R, 1)
	screen._click_hand_card(storm)
	assert_not_null(screen._x_dialog)
	if screen._x_dialog == null:
		return
	assert_eq(int(screen._x_spin.max_value), 2, "two players are the only targets")
	screen._on_x_canceled()
	# Control: a creature on the table is a third target.
	_make(1, "Grizzly Bears", Mtg.Zone.BATTLEFIELD)
	g.players[0].mana_pool.add(Mtg.ManaColor.R, 1)
	screen._click_hand_card(storm)
	assert_eq(int(screen._x_spin.max_value), 3, "three targets now")
	screen._on_x_canceled()


func test_a_mana_x_of_x_targets_is_bounded_by_the_targets() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	_stop_here()
	var word := _make(0, "Word of Binding", Mtg.Zone.HAND)
	_make(1, "Grizzly Bears", Mtg.Zone.BATTLEFIELD)
	g.players[0].mana_pool.add(Mtg.ManaColor.B, 2)
	g.players[0].mana_pool.add(Mtg.ManaColor.C, 5)
	screen._click_hand_card(word)
	assert_not_null(screen._x_dialog)
	if screen._x_dialog == null:
		return
	assert_eq(int(screen._x_spin.max_value), 1, "one creature: tap X target creatures for X = 1 at most")
	screen._on_x_canceled()


# ======================================== H8-8: Heat Wave's note survives --

func test_block_cost_note_survives_a_take_back() -> void:
	var g: MtgGame = screen.game
	_make(1, "Heat Wave", Mtg.Zone.BATTLEFIELD)
	var ogre := _make(1, "Gray Ogre", Mtg.Zone.BATTLEFIELD)
	var b1 := _make(0, "Grizzly Bears", Mtg.Zone.BATTLEFIELD)
	var b2 := _make(0, "Grizzly Bears", Mtg.Zone.BATTLEFIELD)
	g._probing = true
	g.active_player = 1
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS))
	g.awaiting_attackers = true
	assert_eq(g.declare_attackers(1, [ogre.id]), "")
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_BLOCKERS))
	g.awaiting_blockers = true
	g._probing = false
	screen._refresh()
	screen._pick_block(b1)
	screen._pick_block(ogre)
	screen._pick_block(b2)
	screen._pick_block(ogre)
	assert_string_contains(screen._prompt_label.text, "(Blocking costs 2 life.)")
	screen._pick_block(b2)   # take the second blocker back
	assert_eq(screen._prompt_label.text, "Combat phase: Choose blockers. (Blocking costs 1 life.)")
	screen._pick_block(b1)   # and the first: nothing owed, no note
	assert_eq(screen._prompt_label.text, "Combat phase: Choose blockers.")


# =================================== H2-S1: the tutor's picker is sorted --

func test_the_tutor_picker_never_shows_library_order() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	_stop_here()
	for card_name in ["Shivan Dragon", "Air Elemental", "Mons's Goblin Raiders", "Llanowar Elves"]:
		_make(0, card_name, Mtg.Zone.LIBRARY)
	var tutor := _make(0, "Demonic Tutor", Mtg.Zone.HAND)
	g.players[0].mana_pool.add(Mtg.ManaColor.B, 2)
	screen._click_hand_card(tutor)
	assert_not_null(screen._search_dialog, "the picker opens before the cast")
	if screen._search_dialog == null:
		return
	var shown: Array[String] = []
	for i in screen._search_list.item_count:
		shown.append(screen._search_list.get_item_text(i))
	var sorted := shown.duplicate()
	sorted.sort()
	assert_eq(shown, sorted, "listed by name, not by position in the library")
	screen._on_search_canceled()
	# Cancel did not shuffle; a different order shows exactly the same list.
	g.players[0].library.reverse()
	screen._click_hand_card(tutor)
	var again: Array[String] = []
	for i in screen._search_list.item_count:
		again.append(screen._search_list.get_item_text(i))
	assert_eq(again, shown, "the list says nothing about the order")
	screen._on_search_canceled()


# ================================== a land's entry payment: the decline --

## Every text drawn in [param node] and below it.
static func _texts(node: Node) -> Array[String]:
	var out: Array[String] = []
	if node is Button or node is Label:
		out.append(String(node.get("text")))
	for child in node.get_children():
		out.append_array(_texts(child))
	return out


## Lotus Vale (fix-ec made its entry payment a held cost question): the
## overlay's last line DECLINES — the Oracle's "put it into its owner's
## graveyard", the drop spent — beside the Cancel button that WITHDRAWS the
## play. It says so, rather than a second "Cancel".
func test_a_land_entry_decline_says_it_costs_the_land() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	_stop_here()
	_make(0, "Forest", Mtg.Zone.BATTLEFIELD)
	_make(0, "Plains", Mtg.Zone.BATTLEFIELD)
	var vale := _make(0, "Lotus Vale", Mtg.Zone.HAND)
	screen._click_hand_card(vale)
	var held: PlayerChoice = g.awaiting_choice
	assert_not_null(held, "the land drop is held on its entry payment")
	if held == null:
		return
	assert_true(held.is_cost and held.optional, "control: an optional cost question")
	var decline := "Put Lotus Vale into its owner's graveyard."
	assert_eq(screen._decline_label(held), decline)
	assert_eq(DuelScreen.choice_options(held, screen._decline_label(held)).back(), decline)
	screen._build_choice_overlay(held)   # (headless: _open_choice_overlay stays shut)
	assert_not_null(screen._choice_overlay, "the overlay is up")
	if screen._choice_overlay == null:
		return
	var drawn := _texts(screen._choice_overlay)
	var lines := DuelScreen.choice_options(held).size()
	assert_true(drawn.has("%d. %s" % [lines, decline]), "the overlay's last line: %s" % [drawn])
	assert_false(drawn.has("%d. Cancel." % lines), "no second Cancel beside the button")
	# The line still declines.
	screen._on_choice_option(lines - 1)
	assert_null(g.awaiting_choice)
	assert_eq(vale.zone, Mtg.Zone.GRAVEYARD, "declined: into the graveyard")
	assert_eq(g.players[0].lands_played_this_turn, 1, "and the drop is spent")


## Every other optional pick keeps the 1997 `Cancel.` (prompts.txt:949).
func test_an_ordinary_optional_pick_still_says_cancel() -> void:
	var search := PlayerChoice.new(PlayerChoice.Kind.CARD, 0, "Search your library for a card")
	search.optional = true
	search.source = "Demonic Tutor"
	assert_eq(screen._decline_label(search), "Cancel.")
	var cost := PlayerChoice.new(PlayerChoice.Kind.CARD, 0, "Sacrifice a creature")
	cost.is_cost = true
	cost.source = "Lotus Vale"
	assert_eq(screen._decline_label(cost), "Cancel.", "not optional: not a land's decline")


# ====================================================== H8-4 / H8-5: Help --

func _all_help_text() -> String:
	var out := PackedStringArray()
	for page in HelpPages.pages():
		for block in page.get("blocks", []):
			out.append(String(block.get("text", "")))
	return "\n".join(out)


func test_help_heart_of_bogardan_triggers_on_its_own_upkeep() -> void:
	var text := ""
	for page in preload("res://game/help/ability_glossary.gd").pages():
		for block in page["blocks"]:
			text += String(block.get("text", "")) + "\n"
	assert_false(text.contains("Whenever any cumulative upkeep goes unpaid"),
		"Heart of Bogardan triggers only on its own unpaid upkeep")
	assert_string_contains(text, "When a player does not pay Heart of Bogardan's own cumulative upkeep")


func test_help_names_the_shared_reprints_by_their_script() -> void:
	var text := _all_help_text()
	assert_false(text.contains("first printed in Ice Age, Homelands, Portal or Second Age"),
		"20 of the 31 first appeared in Mirage or Visions")
	assert_string_contains(text, "whose rules script lives in Ice Age, Homelands, Portal or Portal Second Age")


func test_help_says_where_the_special_payments_are() -> void:
	var text := _all_help_text()
	for phrase in ["Channel", "Guardian Angel", "Sabertooth Cobra", "Right-click your territory"]:
		assert_string_contains(text, phrase)
