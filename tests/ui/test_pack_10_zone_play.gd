extends GutTest
## PLAYING FROM THE GRAVEYARD AND THE LIBRARY'S TOP — the Pack 10 (Urza
## block) zone permissions a HUMAN seat reaches through the duel screen
## (engine: `MtgGame.grant_zone_play`, Pack 10 E5).
##
##  * Yawgmoth's Will: "Until end of turn, you may play lands and cast
##    spells from your graveyard." The graveyard view rings a LAND the seat
##    may play as well as a spell, and the click plays it as the land drop.
##  * Temporal Aperture: "... for as long as that card remains on top of
##    your library, play with the top card of your library revealed and you
##    may play that card without paying its mana cost." A left click on the
##    seat's own library pile plays the top card: a land at once, a spell
##    through its payment rows ("Without paying its mana cost").

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


func _make(pid: int, card_name: String, zone: int) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name), g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	inst.zone = zone
	match zone:
		Mtg.Zone.GRAVEYARD: g.players[pid].graveyard.append(inst)
		Mtg.Zone.LIBRARY: g.players[pid].library.append(inst)   # the top is the back
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


func _left_click_library(pid: int) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	screen._on_pile_input(click, pid)


# ============================================ a land from the graveyard --

func test_a_graveyard_land_is_ringed_and_played_from_the_view_under_the_will() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	var forest := _make(0, "Forest", Mtg.Zone.GRAVEYARD)
	g.grant_zone_play(0, {"zone": Mtg.Zone.GRAVEYARD, "lands": true, "spells": true,
		"desc": "lands and spells from their graveyard"})
	screen._on_grave_pile_clicked(0)
	assert_true(screen.graveyard_is_open())
	var face := _shelf_widget(forest)
	assert_not_null(face)
	if face == null:
		return
	assert_not_null(face.find_child("PlayableRing", false, false), "the playable land is ringed")
	face.pressed.emit()
	assert_false(screen.graveyard_is_open(), "the view gets out of the way")
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD, "played as the land drop")
	assert_eq(g.players[0].lands_played_this_turn, 1)


func test_without_the_will_a_graveyard_land_is_only_looked_at() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	var forest := _make(0, "Forest", Mtg.Zone.GRAVEYARD)
	screen._on_grave_pile_clicked(0)
	var face := _shelf_widget(forest)
	assert_not_null(face)
	if face == null:
		return
	assert_null(face.find_child("PlayableRing", false, false))
	face.pressed.emit()
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].lands_played_this_turn, 0)


# =========================================== the top of the library --

func test_a_left_click_on_the_library_plays_the_permitted_top_land() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	var forest := _make(0, "Forest", Mtg.Zone.LIBRARY)
	_left_click_library(0)
	assert_eq(forest.zone, Mtg.Zone.LIBRARY, "control: no permission, the click does nothing")
	g.grant_zone_play(0, {"zone": Mtg.Zone.LIBRARY, "card": forest, "lands": true,
		"spells": true, "free": true})
	_left_click_library(1)
	assert_eq(forest.zone, Mtg.Zone.LIBRARY, "the opponent's pile is not ours to play")
	_left_click_library(0)
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].lands_played_this_turn, 1)


func test_a_left_click_on_the_library_casts_the_top_spell_free() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	var bear := _make(0, "Grizzly Bears", Mtg.Zone.LIBRARY)
	g.grant_zone_play(0, {"zone": Mtg.Zone.LIBRARY, "card": bear, "lands": true,
		"spells": true, "free": true})
	g.players[0].mana_pool.add(Mtg.ManaColor.G, 2)   # the printed cost is affordable...
	_left_click_library(0)
	assert_not_null(screen._mode_overlay, "the payment rows: the printed cost or free")
	var greyed: Array = []
	var open: Array = []
	for button in screen._mode_overlay.find_children("*", "Button", true, false):
		if button.text == "Cancel": continue
		if button.disabled: greyed.append(button.text)
		else: open.append(button.text)
	assert_eq(greyed.size(), 1, "...but the printed row is greyed: %s" % str(greyed))
	assert_string_contains(str(greyed), "Pay")
	assert_eq(open.size(), 1)
	assert_string_contains(str(open), "Without paying its mana cost")
	var rows := g.payment_rows(0, bear)
	var free := -1
	for i in rows.size():
		if bool(Dictionary(rows[i].get("payment", {})).get("zone_free", false)):
			free = i
	assert_gt(free, 0)
	screen._on_mode_chosen(free)
	assert_eq(g.stack.size(), 1, "cast without paying its mana cost")
	assert_eq(g.stack.back().card, bear)
	assert_false(g.players[0].library.has(bear))
