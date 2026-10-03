extends GutTest
## PLAYING FROM THE GRAVEYARD AND EXILE, AND A HAND CARD'S SPECIAL ACTION
## — the Pack 8 (Mirage block) zone actions a HUMAN seat reaches through the
## duel screen.
##
##  * Bösium Strip: "Until end of turn, you may cast instant and sorcery
##    spells from the top of your graveyard" (`MtgGame.grant_graveyard_cast`
##    / `can_cast_from_graveyard`). The engine and the AI could; a human
##    had no click path. The graveyard view now rings the top card the seat
##    may cast and a click on it starts the hand's own cast chain.
##  * Three Wishes: three cards exiled FACE DOWN that only their owner may
##    look at and play (`exile_top_of_library(pid, true, pid)`,
##    `grant_exile_play`). The view drew them face up for that seat already;
##    the click showed the back and stopped. The opponent's still shows a
##    back and does nothing.
##  * Circling Vultures: "You may discard this card any time you could cast
##    an instant" — a SPECIAL ACTION (CR 116.2, `discard_as_special_action`):
##    no stack, no response, the player keeps priority. The hand card's
##    click offers Cast and Discard; the right-click mini-menu offers the
##    discard too.

var screen: DuelScreen
var _saved_stops: Variant = null


func before_each() -> void:
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
	if _saved_stops == null:
		Settings.clear_value(PhaseStops.SETTING_KEY)
	else:
		Settings.set_value(PhaseStops.SETTING_KEY, _saved_stops)


# ---------------------------------------------------------------- fixture --

static func _shock(card_name := "Test Shock") -> CardData:
	return CardData.new(card_name, "{R}", Mtg.CardType.INSTANT) \
		.spell(DamageEffect.new(2).any_target())


static func _sorcery() -> CardData:
	return CardData.new("Test Divination", "{U}", Mtg.CardType.SORCERY) \
		.spell(DrawEffect.new(1))


static func _vultures() -> CardData:
	return CardData.new("Test Vultures", "{B}", Mtg.CardType.CREATURE).pt(3, 2) \
		.with_keywords([Mtg.Keyword.FLYING]).with_discard_special_action()


static func _instant_or_sorcery(c: CardInstance) -> bool:
	return c.data.is_type(Mtg.CardType.INSTANT) or c.data.is_type(Mtg.CardType.SORCERY)


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


## A Stop on the phase the duel stands in — what a player who wants to act
## there has placed, so the automatic pass leaves the window to them.
func _stop_here() -> void:
	var here: Array = screen._phase_key()
	screen.stops.set_marked(here[0], here[1], here[2], true)


func _make(pid: int, data: CardData, zone: int) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(data, g._next_instance_id, pid)
	g._next_instance_id += 1
	g._probing = true
	g._instances[inst.id] = inst
	match zone:
		Mtg.Zone.HAND:
			inst.zone = Mtg.Zone.HAND
			g.players[pid].hand.append(inst)
		Mtg.Zone.GRAVEYARD:
			inst.zone = Mtg.Zone.HAND
			g.players[pid].hand.append(inst)
			g.card_to_graveyard_from_anywhere(inst)
		Mtg.Zone.LIBRARY:
			inst.zone = Mtg.Zone.LIBRARY
			g.players[pid].library.append(inst)   # the top is the back
		Mtg.Zone.BATTLEFIELD:
			g._put_on_battlefield(inst, pid)
			inst.summoning_sick = false
	g._probing = false
	return inst


## The open view's widget for [param inst], or null.
func _shelf_widget(inst: CardInstance) -> MiniCard:
	if screen._grave_view == null:
		return null
	for key in screen._grave_view._shelves:
		for face in screen._grave_view._shelves[key].widgets:
			if (face as MiniCard).instance == inst:
				return face
	return null


# ============================================== casting from a graveyard --

func test_the_top_of_the_graveyard_is_cast_from_the_view_under_bosium_strip() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	var under := _make(0, _shock("Test Spark"), Mtg.Zone.GRAVEYARD)
	var top := _make(0, _shock(), Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].graveyard.back(), top)
	assert_false(g.can_cast_from_graveyard(0, top), "control: no permission yet")
	g.grant_graveyard_cast(0, _instant_or_sorcery, "instant and sorcery spells", true, true)
	assert_true(g.can_cast_from_graveyard(0, top))
	assert_false(g.can_cast_from_graveyard(0, under), "only the TOP card")
	g.players[0].mana_pool.add(Mtg.ManaColor.R, 1)
	screen._on_grave_pile_clicked(0)
	assert_true(screen.graveyard_is_open())
	var face := _shelf_widget(top)
	var below := _shelf_widget(under)
	assert_not_null(face)
	assert_not_null(below)
	if face == null or below == null:
		return
	assert_not_null(face.find_child("PlayableRing", false, false), "the castable card is ringed")
	assert_true(face.castable, "and its name is yellow")
	assert_null(below.find_child("PlayableRing", false, false), "the one beneath is not")
	face.pressed.emit()
	assert_false(screen.graveyard_is_open(), "the view gets out of the way")
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING, "the hand's own cast chain")
	assert_eq(screen._pending_card, top)
	screen._on_life_clicked(1)
	assert_eq(g.stack.size(), 1, "cast from the graveyard")
	assert_eq(g.stack.back().card, top)
	var life: int = g.players[1].life
	g._probing = true
	g._resolve_top()
	g._probing = false
	assert_eq(g.players[1].life, life - 2)
	assert_eq(top.zone, Mtg.Zone.EXILE, "a spell cast this way is exiled, not buried")


func test_a_graveyard_instant_is_a_response_and_a_sorcery_waits_for_its_phase() -> void:
	var g := _window(1, Mtg.Step.END)
	_make(0, CardRegistry.get_card("Mountain"), Mtg.Zone.BATTLEFIELD)
	var sorcery := _make(0, _sorcery(), Mtg.Zone.GRAVEYARD)
	g.grant_graveyard_cast(0, _instant_or_sorcery, "instant and sorcery spells", true, true)
	assert_true(g.can_cast_from_graveyard(0, sorcery))
	assert_false(screen._could_respond(0), "a sorcery is no answer on their turn")
	screen._on_grave_pile_clicked(0)
	var face := _shelf_widget(sorcery)
	if face != null:
		assert_null(face.find_child("PlayableRing", false, false),
			"no promise the step cannot keep")
	screen._close_graveyard()
	var shock := _make(0, _shock(), Mtg.Zone.GRAVEYARD)
	assert_true(g.can_cast_from_graveyard(0, shock))
	assert_true(screen._could_respond(0), "the instant on top is one")
	assert_false(screen._auto_pass_applies(), "so their end step holds for it")


# ======================================== a face-down card only you see --

func test_a_three_wishes_card_is_played_by_its_viewer_and_hidden_from_the_other() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	_stop_here()
	_make(0, _shock(), Mtg.Zone.LIBRARY)
	var mine := g.exile_top_of_library(0, true, 0)
	g.grant_exile_play(mine, 0, true)
	_make(1, _shock("Their Wish"), Mtg.Zone.LIBRARY)
	var theirs := g.exile_top_of_library(1, true, 1)
	g.grant_exile_play(theirs, 1, true)
	assert_true(mine.face_down and theirs.face_down)
	assert_true(g.can_play_from_exile(0, mine))
	assert_false(g.can_play_from_exile(0, theirs))
	# The plates: my own card named for me, theirs never.
	assert_string_contains(screen._exile_tooltip(0), "Test Shock")
	assert_string_contains(screen._exile_tooltip(1), "(face down)")
	assert_false(screen._exile_tooltip(1).contains("Their Wish"))
	g.players[0].mana_pool.add(Mtg.ManaColor.R, 1)
	screen._on_grave_pile_clicked(0)
	var my_face := _shelf_widget(mine)
	var their_face := _shelf_widget(theirs)
	assert_not_null(my_face)
	assert_not_null(their_face)
	if my_face == null or their_face == null:
		return
	assert_false(my_face.face_down, "the viewer reads it")
	assert_true(their_face.face_down, "the other seat's is a card back")
	assert_not_null(my_face.find_child("PlayableRing", false, false))
	# Their card: a back in the Showcase and nothing started.
	their_face.pressed.emit()
	assert_null(screen._pending_card)
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)
	# Mine: the cast chain.
	my_face.pressed.emit()
	assert_eq(screen._pending_card, mine, "the viewer's click starts the cast")
	screen._on_life_clicked(1)
	assert_eq(g.stack.size(), 1)
	assert_false(mine.face_down, "turned face up as it is cast")


# ============================================ Circling Vultures' discard --

func test_the_vultures_click_offers_the_discard_and_it_keeps_priority() -> void:
	var g := _window(1, Mtg.Step.UPKEEP)
	_stop_here()
	var vultures := _make(0, _vultures(), Mtg.Zone.HAND)
	screen._click_hand_card(vultures)
	var menu: PopupMenu = screen._hand_action_menu
	assert_not_null(menu)
	if menu == null:
		return
	assert_true(menu.visible, "a small menu at the pointer")
	var cast_at := menu.get_item_index(DuelScreen.HAND_ACTION_CAST)
	var discard_at := menu.get_item_index(DuelScreen.HAND_ACTION_DISCARD)
	assert_true(menu.is_item_disabled(cast_at), "a creature cannot be cast in their upkeep")
	assert_false(menu.is_item_disabled(discard_at), "but it can be discarded now")
	assert_string_contains(menu.get_item_text(discard_at), "Discard Test Vultures")
	menu.hide()
	screen._on_hand_action_chosen(DuelScreen.HAND_ACTION_DISCARD)
	assert_eq(vultures.zone, Mtg.Zone.GRAVEYARD, "discarded")
	assert_true(g.stack.is_empty(), "a special action uses no stack")
	assert_eq(g.priority_player, 0, "and the player keeps priority (CR 116.3)")


func test_the_vultures_menu_casts_in_your_main_phase_and_can_be_left() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	var vultures := _make(0, _vultures(), Mtg.Zone.HAND)
	g.players[0].mana_pool.add(Mtg.ManaColor.B, 1)
	screen._click_hand_card(vultures)
	var menu: PopupMenu = screen._hand_action_menu
	assert_false(menu.is_item_disabled(menu.get_item_index(DuelScreen.HAND_ACTION_CAST)))
	# Leaving the menu does nothing at all.
	menu.hide()
	assert_eq(vultures.zone, Mtg.Zone.HAND)
	assert_null(screen._pending_card)
	# Opened again and Cast chosen: the ordinary cast.
	screen._click_hand_card(vultures)
	menu.hide()
	screen._on_hand_action_chosen(DuelScreen.HAND_ACTION_CAST)
	assert_eq(g.stack.size(), 1, "cast from the floating {B}")
	assert_eq(g.stack.back().card, vultures)


func test_the_right_click_mini_menu_offers_the_discard_too() -> void:
	var g := _window(1, Mtg.Step.DRAW)
	_stop_here()
	var vultures := _make(0, _vultures(), Mtg.Zone.HAND)
	screen._open_card_menu(vultures, Vector2(100, 100))
	var menu: PopupMenu = screen._card_menu
	var at := menu.get_item_index(DuelScreen.CARD_MENU_DISCARD_SPECIAL)
	assert_gte(at, 0, "the entry is on the card's own menu")
	assert_false(menu.is_item_disabled(at))
	menu.hide()
	screen._on_card_menu_chosen(DuelScreen.CARD_MENU_DISCARD_SPECIAL)
	assert_eq(vultures.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.priority_player, 0)
	# A plain creature's menu has no such entry.
	var bear := _make(0, CardData.new("Test Bear", "{G}", Mtg.CardType.CREATURE).pt(2, 2),
		Mtg.Zone.HAND)
	screen._open_card_menu(bear, Vector2(100, 100))
	assert_eq(menu.get_item_index(DuelScreen.CARD_MENU_DISCARD_SPECIAL), -1)
	menu.hide()
