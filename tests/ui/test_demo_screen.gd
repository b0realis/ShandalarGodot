extends GutTest
## The demo screen opened from Options: its window, the card-list check and
## the four shows (solitaire's end, the mess table, the two collector
## tables), with fronts, backs or both, and its keys. Then the draw of
## random cards beside it: its window, its colours, and the spin.

const Options := preload("res://game/options_screen.gd")
const POOL: Array[String] = ["Lightning Bolt", "Forest", "Serra Angel",
	"Shivan Dragon", "Counterspell", "Llanowar Elves"]


func before_each() -> void:
	CardRegistry.ensure_loaded()


func _demo(mode: int, faces: int = Options.DemoScreen.Faces.FRONT) -> Options.DemoScreen:
	var demo := Options.DemoScreen.new()
	demo.pool = POOL.duplicate()
	demo.mode = mode
	demo.faces = faces
	add_child_autofree(demo)
	# Past the click shield, as if the show had been up a while.
	demo._opened_ms = -Options.DemoScreen.SETTLE_MS * 10
	return demo


func _deal_all(demo: Options.DemoScreen) -> void:
	var guard := 0
	while demo.cards_to_deal() > 0 and guard < 1000:
		demo._run_jobs()
		guard += 1


func _holders(demo: Options.DemoScreen) -> Array[Control]:
	var out: Array[Control] = []
	for child in demo._table.get_children():
		if child is Control and child.get_child_count() > 0:
			out.append(child)
	return out


func _found(node: Node, kind: Variant) -> Array[Node]:
	var out: Array[Node] = []
	if is_instance_of(node, kind):
		out.append(node)
	for child in node.get_children():
		out.append_array(_found(child, kind))
	return out


func _key(code: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = code
	key.pressed = true
	return key


# ------------------------------------------------------------ the window --

func test_the_pool_cards_are_in_the_game() -> void:
	for card_name in POOL:
		assert_true(CardRegistry.has_card(card_name), card_name)


func test_the_list_check_reads_names_and_deck_lists() -> void:
	var checked := Options.DemoSetup.check_list("lightning bolt\n4 Forest\n2x Serra Angel\n"
		+ "Counterspell x3\nSB: 1 Shivan Dragon\n# a comment\n\nNo Such Card\nForest")
	assert_eq(checked.found, ["Lightning Bolt", "Forest", "Serra Angel",
		"Counterspell", "Shivan Dragon"])
	assert_eq(checked.unknown, ["No Such Card"])


func test_a_line_of_names_splits_at_its_commas_but_a_comma_name_stays_whole() -> void:
	assert_eq(Options.DemoSetup.check_list("Lightning Bolt, Forest; Counterspell").found,
		["Lightning Bolt", "Forest", "Counterspell"])
	var comma_name := ""
	var quote_name := ""
	for card_name in CardRegistry.all_names():
		if comma_name == "" and String(card_name).contains(", "):
			comma_name = card_name
		if quote_name == "" and String(card_name).contains("'"):
			quote_name = card_name
	if comma_name != "":
		assert_eq(Options.DemoSetup.check_list(comma_name).found, [comma_name])
	assert_ne(quote_name, "", "a card with an apostrophe")
	assert_eq(Options.DemoSetup.check_list(quote_name.replace("'", "’").to_upper()).found,
		[quote_name])


func test_the_sources_are_every_set_each_set_and_the_list() -> void:
	var sources := Options.DemoSetup.sources()
	assert_eq(sources.front().id, "")
	assert_eq(sources.front().label, Options.DemoSetup.ALL_SETS)
	assert_eq(sources.back().id, Options.DemoSetup.LIST)
	var labels: Array = sources.map(func(entry: Dictionary) -> String: return entry.label)
	assert_has(labels, "Unlimited")
	for entry in sources.slice(1, sources.size() - 1):
		assert_false(CardRegistry.names_in_set(entry.id).is_empty(), entry.label)
	assert_eq(Options.DemoSetup.pool_for("2ed", "").size(),
		CardRegistry.names_in_set("2ed").size())
	assert_eq(Options.DemoSetup.pool_for("", "").size(), CardRegistry.size())
	assert_eq(Options.DemoSetup.pool_for(Options.DemoSetup.LIST, "Forest\nNope"), ["Forest"] as Array[String])


func test_options_has_the_button_and_the_window_runs_a_show_and_comes_back() -> void:
	var saved: Dictionary = Options.DemoSetup._last.duplicate()
	Options.DemoSetup._last = {"source": "", "list": "", "mode": Options.DemoScreen.Mode.COLLECTOR_SMALL,
		"faces": Options.DemoScreen.Faces.FRONT, "foil": true}
	var options_screen: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(options_screen)
	var button := options_screen.find_child("DemoScreen", true, false) as Button
	assert_not_null(button)
	assert_eq(button.text, "Demo screen")
	button.pressed.emit()
	var window: Options.DemoSetup = null
	for child in options_screen.get_children():
		if child is Options.DemoSetup:
			window = child
	assert_not_null(window, "the window opened")
	assert_string_contains(window.find_child("DemoKeys", true, false).text, "R: new cards")

	# The list: empty means no Go; typing names picks the list as the source.
	window._select_source(Options.DemoSetup.LIST)
	window._refresh()
	assert_true(window.go_button.disabled)
	window.list_box.text = "Forest\nCounterspell\nNot A Card"
	window.list_box.text_changed.emit()
	assert_false(window.go_button.disabled)
	assert_string_contains(window.check_label.text, "2 cards found")
	assert_string_contains(window.check_label.text, "Not A Card")

	assert_true(window.foil_check.button_pressed, "foil starts on")
	window.foil_check.button_pressed = false
	assert_false(Options.DemoSetup._last.foil)
	window.start()
	await get_tree().process_frame
	var demo := window.demo
	assert_false(demo.foil, "the window's foil switch reaches the show")
	assert_not_null(demo, "the show is up")
	assert_true(demo.is_inside_tree())
	assert_eq(demo.pool, ["Forest", "Counterspell"] as Array[String])
	assert_eq(demo.mode, Options.DemoScreen.Mode.COLLECTOR_SMALL)
	assert_false(window.visible)
	assert_false(options_screen.visible)

	demo.leave()
	await get_tree().process_frame
	assert_true(window.visible, "back to the window")
	assert_true(options_screen.visible)
	assert_null(window.demo)
	assert_eq(Options.DemoSetup._last.list, "Forest\nCounterspell\nNot A Card",
		"the window remembers the list for the session")

	window.close()
	assert_true(button.has_focus(), "back on the button that opened it")
	await get_tree().process_frame
	assert_false(is_instance_valid(window))
	Options.DemoSetup._last = saved


# -------------------------------------------------------------- the maths --

func test_bigger_screens_get_more_cards() -> void:
	assert_eq(Options.DemoScreen.density_scale(1.0), 1.0)
	assert_eq(Options.DemoScreen.density_scale(0.5), 1.0)
	assert_almost_eq(Options.DemoScreen.density_scale(4.0), 0.5, 0.0001)
	var card := CardPreview.SIZE * Options.DemoScreen.BIG_SCALE
	var small := Options.DemoScreen.grid_fit(Vector2(1280, 800), card, 14, 22)
	# The same window at twice the pixels each way: twice the stretch.
	var big := Options.DemoScreen.grid_fit(Vector2(1280, 800),
		card * Options.DemoScreen.density_scale(2.0), 14 * Options.DemoScreen.density_scale(2.0),
		22 * Options.DemoScreen.density_scale(2.0))
	assert_gt(big.x * big.y, small.x * small.y)
	assert_eq(Options.DemoScreen.grid_fit(Vector2(50, 50), card, 14, 22), Vector2i(1, 1))
	assert_eq(Options.DemoScreen.mess_count(Vector2(10, 10), card), Options.DemoScreen.MESS_MIN)
	assert_eq(Options.DemoScreen.mess_count(Vector2(9000, 9000), card), Options.DemoScreen.MESS_MAX)


func test_a_flying_card_bounces_off_the_floor_losing_a_quarter() -> void:
	var step := Options.DemoScreen.fly(Vector2(10, 95), Vector2(-4, 20), 1.0, 100.0)
	assert_eq(step[0], Vector2(6, 100))
	assert_almost_eq(step[1].y, -21.0 * Options.DemoScreen.BOUNCE, 0.0001)
	var falling := Options.DemoScreen.fly(Vector2(10, 10), Vector2(-4, 0), 1.0, 100.0)
	assert_eq(falling[0], Vector2(6, 10))
	assert_eq(falling[1], Vector2(-4, Options.DemoScreen.GRAVITY))


func test_the_binder_order_is_colour_then_name() -> void:
	var names: Array[String] = ["Forest", "Llanowar Elves", "Lightning Bolt",
		"Serra Angel", "Counterspell"]
	names.sort_custom(Options.DemoScreen._binder_order)
	assert_eq(names, ["Serra Angel", "Counterspell", "Lightning Bolt",
		"Llanowar Elves", "Forest"] as Array[String])


# --------------------------------------------------------------- the shows --

func test_the_collector_tables_fill_the_screen_in_a_sorted_grid() -> void:
	for big in [true, false]:
		var demo := _demo(Options.DemoScreen.Mode.COLLECTOR_BIG if big
			else Options.DemoScreen.Mode.COLLECTOR_SMALL)
		assert_gt(demo.cards_to_deal(), 0, "the deal is spread over frames")
		_deal_all(demo)
		var holders := _holders(demo)
		var native := CardPreview.SIZE if big else MiniCard.SIZE
		var card := native * (Options.DemoScreen.BIG_SCALE if big else Options.DemoScreen.SMALL_SCALE) \
			* Options.DemoScreen.density_scale(demo._phys)
		var grid := Options.DemoScreen.grid_fit(demo._view, card,
			(Options.DemoScreen.BIG_GAP if big else Options.DemoScreen.SMALL_GAP) * Options.DemoScreen.density_scale(demo._phys),
			Options.DemoScreen.EDGE * Options.DemoScreen.density_scale(demo._phys))
		assert_eq(holders.size(), grid.x * grid.y)
		for holder in holders:
			assert_true(Rect2(Vector2.ZERO, demo._view).encloses(
				Rect2(holder.position, holder.size)), "every card on the screen")
		var faces := _found(demo._table, CardPreview if big else MiniCard)
		assert_eq(faces.size(), holders.size())
		var ranks: Array[int] = []
		for face in faces:
			var card_name: String = face._shown.data.card_name if big \
				else face.instance.data.card_name
			ranks.append(Options.DemoScreen.colour_rank(CardRegistry.get_card(card_name)))
		var sorted := ranks.duplicate()
		sorted.sort()
		assert_eq(ranks, sorted, "a binder's order")
		# The rare one wears the foil; nothing else does.
		for holder in holders:
			var foil := holder.find_child("Foil", true, false)
			var face: Node = _found(holder, CardPreview if big else MiniCard)[0]
			var card_name: String = face._shown.data.card_name if big \
				else face.instance.data.card_name
			assert_eq(foil != null, card_name == "Shivan Dragon", card_name)


func test_the_foil_switch_takes_the_glint_away() -> void:
	var demo := _demo(Options.DemoScreen.Mode.COLLECTOR_BIG)
	demo.foil = false
	demo.regenerate()
	_deal_all(demo)
	var glints := _found(demo._table, ColorRect).filter(
		func(node: Node) -> bool: return node.name == "Foil")
	assert_eq(glints.size(), 0, "no foil with the switch off")
	demo.foil = true
	demo.regenerate()
	_deal_all(demo)
	glints = _found(demo._table, ColorRect).filter(
		func(node: Node) -> bool: return node.name == "Foil")
	assert_gt(glints.size(), 0, "the rare one glints with it on")


func test_backs_and_a_mix_of_both() -> void:
	var backs := _demo(Options.DemoScreen.Mode.COLLECTOR_SMALL, Options.DemoScreen.Faces.BACK)
	_deal_all(backs)
	var minis := _found(backs._table, MiniCard)
	assert_gt(minis.size(), 0)
	for mini in minis:
		assert_true(mini.face_down, "the card shows its back")
		assert_false(mini._name_label.visible, "and not its name")
	assert_eq(_found(backs._table, ColorRect).filter(
		func(node: Node) -> bool: return node.name == "Foil").size(), 0, "no foil on a back")
	var both := _demo(Options.DemoScreen.Mode.COLLECTOR_SMALL, Options.DemoScreen.Faces.BOTH)
	both.rng.seed = 7
	both.regenerate()
	_deal_all(both)
	var down := 0
	var cards := _found(both._table, MiniCard)
	for mini in cards:
		if mini.face_down:
			down += 1
	assert_between(down, 1, cards.size() - 1, "some of each")


func test_the_mess_covers_the_table_at_every_angle() -> void:
	var demo := _demo(Options.DemoScreen.Mode.MESS)
	_deal_all(demo)
	var holders := _holders(demo)
	var card := CardPreview.SIZE * Options.DemoScreen.MESS_SCALE * Options.DemoScreen.density_scale(demo._phys)
	assert_gte(holders.size(), Options.DemoScreen.mess_count(demo._view, card))
	var turns := {}
	for holder in holders:
		turns[snappedf(holder.rotation, 0.5)] = true
	assert_gt(turns.size(), 5, "cards lie at many angles")
	# Every quarter of the table has cards on it.
	for quarter in [Vector2(0.25, 0.25), Vector2(0.75, 0.25), Vector2(0.25, 0.75),
			Vector2(0.75, 0.75)]:
		var near := holders.filter(func(holder: Control) -> bool:
			return (holder.position + holder.size * 0.5).distance_to(demo._view * quarter) \
				< demo._view.y * 0.3)
		assert_gt(near.size(), 0, str(quarter))


func test_solitaire_launches_every_card_and_deals_again() -> void:
	var demo := _demo(Options.DemoScreen.Mode.SOLITAIRE)
	assert_not_null(demo._trail, "the trail picture")
	assert_eq(demo._trail.render_target_clear_mode, SubViewport.CLEAR_MODE_ONCE)
	assert_eq(demo.cards_left(), Options.DemoScreen.SOL_PILES * Options.DemoScreen.SOL_PILE_CARDS)
	for i in demo._pile_faces.size():
		var face := demo._pile_faces[i]
		assert_true(face.visible)
		assert_eq(face.position, demo._pile_spots[i], "each foundation in its place")
	demo._solitaire_tick(Options.DemoScreen.STEP)
	assert_eq(demo._pile_faces[0].position, demo._pile_spots[0],
		"a card shown in the tree stays where it was put")
	var first_table := demo._table
	var frames := 0
	while demo.cards_left() > 0 and frames < 100000:
		demo._solitaire_tick(Options.DemoScreen.STEP)
		frames += 1
	assert_eq(demo.cards_left(), 0, "every card flew")
	var shown := demo._stamps.filter(func(stamp: CardPreview) -> bool: return stamp.visible)
	assert_between(shown.size(), 0, Options.DemoScreen.STAMPS)
	# The last one leaves, the table rests, and a new deal comes.
	while demo._flying or demo._rest < Options.DemoScreen.SOL_REST:
		demo._solitaire_tick(Options.DemoScreen.STEP)
		frames += 1
		if frames > 200000:
			break
	# Paused, so the frame that brings the new deal launches nothing from it.
	demo.set_paused(true)
	await get_tree().process_frame
	assert_ne(demo._table, first_table, "a new deal")
	assert_eq(demo.cards_left(), Options.DemoScreen.SOL_PILES * Options.DemoScreen.SOL_PILE_CARDS)


func test_a_slow_frame_still_stamps_each_step() -> void:
	var demo := _demo(Options.DemoScreen.Mode.SOLITAIRE)
	demo._solitaire_tick(Options.DemoScreen.STEP * 3.0 + 0.0001)
	var shown := demo._stamps.filter(func(stamp: CardPreview) -> bool: return stamp.visible)
	assert_eq(shown.size(), 3)
	assert_ne(shown[0].position, shown[2].position)


func test_the_flip_wall_turns_cards_over() -> void:
	var demo := _demo(Options.DemoScreen.Mode.FLIP_WALL)
	_deal_all(demo)
	assert_gt(demo._flippers.size(), 0)
	assert_eq(demo._flippers.size(), _holders(demo).size(), "every pocket turns")
	# Not sorted like a binder: a wall of whatever came.
	demo._flip_tick(Options.DemoScreen.FLIP_EVERY + 0.01)
	var turning := demo._flippers.filter(func(turn: Control) -> bool:
		return turn.get_meta("turning", false))
	assert_eq(turning.size(), 1, "one card at a time")
	# A wall of fronts: the card turns DOWN to its back, lies a moment, and
	# comes back up as another card.
	var busy := turning.duplicate()
	var tween := demo.flip_one()
	var fresh := demo._flippers.filter(func(turn: Control) -> bool:
		return turn.get_meta("turning", false) and not busy.has(turn))
	assert_eq(fresh.size(), 1)
	var turn: Control = fresh[0]
	var face := turn.get_child(0)
	tween.custom_step(Options.DemoScreen.FLIP_HALF + 0.01)
	assert_true(turn.get_meta("back"), "turned down to its back")
	tween.custom_step(Options.DemoScreen.FLIP_HOLD * 0.5)
	assert_true(turn.get_meta("back"), "lying face down a moment")
	tween.custom_step(Options.DemoScreen.FLIP_HOLD + Options.DemoScreen.FLIP_HALF * 2.0)
	assert_false(turn.get_meta("back"), "up again")
	assert_ne(turn.get_child(0), face, "as another card's face")
	assert_false(turn.get_meta("turning"))
	assert_almost_eq(turn.scale.x, 1.0, 0.001, "and open flat")


func test_a_wall_of_backs_turns_cards_up_and_down_again() -> void:
	var demo := _demo(Options.DemoScreen.Mode.FLIP_WALL, Options.DemoScreen.Faces.BACK)
	_deal_all(demo)
	var turn: Control = demo._flippers[0]
	assert_true(turn.get_meta("back"))
	demo._turn_over(turn)
	assert_false(turn.get_meta("back"), "turned up")
	assert_has(POOL, String(turn.get_meta("card_name")))
	demo._turn_over(turn)
	assert_true(turn.get_meta("back"), "and down again")


func test_the_card_rain_falls_far_cards_behind_and_comes_round_again() -> void:
	var demo := _demo(Options.DemoScreen.Mode.CARD_RAIN)
	_deal_all(demo)
	var drops := demo._drops
	assert_between(drops.size(), Options.DemoScreen.RAIN_MIN, Options.DemoScreen.RAIN_MAX)
	# Far ones first in the tree, so near ones are drawn over them.
	for i in range(1, drops.size()):
		assert_true(float(drops[i].depth) >= float(drops[i - 1].depth))
		assert_true((drops[i].node as Control).get_index() > (drops[i - 1].node as Control).get_index())
	assert_gt(float(drops.back().speed), float(drops.front().speed), "near falls faster")
	var first: Dictionary = drops.front()
	var y := float(first.y)
	var x := (first.node as Control).position.x
	demo._rain_tick(0.5)
	assert_gt(float(first.y), y, "falling")
	assert_eq((first.node as Control).position.x, x, "straight down, no sway")
	# Turning over as it falls: its back is the card back, its face a card.
	first.flip = PI
	demo._place_drop(first)
	assert_true((first.back as Control).visible)
	assert_false((first.face as Control).visible)
	assert_true((first.back as CardPreview)._back.visible, "the back is a card back")
	first.flip = 0.0
	demo._place_drop(first)
	assert_true((first.face as Control).visible)
	assert_false((first.back as Control).visible)
	assert_false((first.face as CardPreview)._back.visible, "the face is a card")
	first.flip = PI * 0.5
	demo._place_drop(first)
	assert_lt((first.turn as Control).scale.x, 0.05, "edge-on half way over")
	# Past the bottom: back in at the top.
	first.y = demo._view.y * 3.0
	demo._rain_tick(0.01)
	assert_lt(float(first.y), 0.0, "round again from the top")


# ------------------------------------------------------------------ keys --

func test_r_deals_again_space_pauses_esc_leaves() -> void:
	var demo := _demo(Options.DemoScreen.Mode.COLLECTOR_BIG)
	watch_signals(demo)
	var first := demo._table
	demo._input(_key(KEY_R))
	assert_ne(demo._table, first, "R deals new cards")
	demo._input(_key(KEY_SPACE))
	assert_true(demo.paused)
	assert_true(demo._note.visible)
	assert_eq(demo._note.text, "Paused")
	assert_eq(demo._table.process_mode, Node.PROCESS_MODE_DISABLED)
	var waiting := demo.cards_to_deal()
	demo._process(0.5)
	assert_eq(demo.cards_to_deal(), waiting, "a paused deal waits")
	demo._input(_key(KEY_SPACE))
	assert_false(demo.paused)
	assert_false(demo._note.visible, "the note goes with the pause")
	demo._input(_key(KEY_ESCAPE))
	assert_signal_emitted(demo, "left")
	assert_true(demo.is_queued_for_deletion())


func test_a_click_leaves_but_not_the_one_that_pressed_go() -> void:
	var demo := _demo(Options.DemoScreen.Mode.COLLECTOR_SMALL)
	watch_signals(demo)
	demo._opened_ms = Time.get_ticks_msec()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	demo._input(click)
	assert_signal_not_emitted(demo, "left", "the click shield")
	demo._opened_ms = -Options.DemoScreen.SETTLE_MS * 10
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	demo._input(wheel)
	assert_signal_not_emitted(demo, "left", "a wheel is not a click")
	demo._input(click)
	assert_signal_emitted(demo, "left")


func test_a_pad_leaves_and_deals() -> void:
	var demo := _demo(Options.DemoScreen.Mode.MESS)
	watch_signals(demo)
	var first := demo._table
	var y := InputEventJoypadButton.new()
	y.button_index = JOY_BUTTON_Y
	y.pressed = true
	demo._input(y)
	assert_ne(demo._table, first)
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_B
	b.pressed = true
	demo._input(b)
	assert_signal_emitted(demo, "left")


func test_the_note_says_where_a_picture_went_and_fades() -> void:
	var demo := _demo(Options.DemoScreen.Mode.COLLECTOR_SMALL)
	demo.say("Saved: somewhere")
	assert_true(demo._note.visible)
	demo._process(Options.DemoScreen.NOTE_SECONDS + 0.1)
	assert_false(demo._note.visible)


# ------------------------------------------------------ draw random cards --

func _draw(count: int, pool: Array[String] = POOL) -> Options.DrawScreen:
	var draw := Options.DrawScreen.new()
	draw.pool = pool.duplicate()
	draw.count = count
	add_child_autofree(draw)
	draw._opened_ms = -Options.DemoScreen.SETTLE_MS * 10
	return draw


## Run a draw's spin by hand, [param seconds] of it, a frame at a time.
func _spin(draw: Options.DrawScreen, seconds: float, each: Callable = Callable()) -> void:
	var t := 0.0
	while t < seconds:
		draw._tick(1.0 / 60.0)
		if each.is_valid():
			each.call()
		t += 1.0 / 60.0


func test_options_has_the_draw_button_and_its_window_draws_and_comes_back() -> void:
	var saved: Dictionary = Options.DrawSetup._kept.duplicate(true)
	Options.DrawSetup._kept = {"source": "", "list": "", "colours": [true, true, true, true, true],
		"gold": true, "count": 1, "foil": true}
	var options_screen: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(options_screen)
	var button := options_screen.find_child("DrawCards", true, false) as Button
	assert_not_null(button)
	assert_eq(button.text, "Draw random card(s)")
	button.pressed.emit()
	var window: Options.DrawSetup = null
	for child in options_screen.get_children():
		if child is Options.DrawSetup:
			window = child
	assert_not_null(window, "the window opened")
	assert_string_contains(window.find_child("DrawKeys", true, false).text, "R: draw again")
	assert_eq(window.colour_buttons.size(), 6, "five colours and Gold")
	for medallion in window.colour_buttons:
		assert_true(medallion.button_pressed, "%s starts on" % medallion.name)
	assert_eq(window.count_list.selected, 0, "one card to begin with")
	assert_eq(window.count_list.item_count, 7)

	window.list_box.text = "Forest\nCounterspell\nSerra Angel"
	window.list_box.text_changed.emit()
	assert_string_contains(window.check_label.text, "3 cards found")
	# Blue and White off: the Forest stays, as a land does in the Deck Builder.
	window.colour_buttons[0].button_pressed = false
	window.colour_buttons[1].button_pressed = false
	assert_eq(Options.DrawSetup._kept.colours, [false, false, true, true, true])
	assert_string_contains(window.check_label.text, "1 in the chosen colours")
	window.count_list.select(6)
	window.count_list.item_selected.emit(6)
	assert_eq(int(Options.DrawSetup._kept.count), 7)
	assert_string_contains(window.check_label.text, "Fewer than 7, so all 1 are drawn")
	assert_false(window.go_button.disabled)

	window.start()
	await get_tree().process_frame
	var draw := window.demo as Options.DrawScreen
	assert_not_null(draw, "the draw is up")
	assert_eq(draw.pool, ["Forest"] as Array[String])
	assert_eq(draw.count, 7)
	assert_eq(draw.drawn, ["Forest"] as Array[String], "fewer than asked for: all of them")
	assert_false(window.visible)
	draw.leave()
	await get_tree().process_frame
	assert_true(window.visible, "back to the window")
	assert_eq(get_viewport().oversampling_override, 0.0, "the text sharpness back as it was")

	# Every colour off and no Gold: only lands and colourless cards are left.
	for medallion in window.colour_buttons:
		medallion.button_pressed = false
	window.list_box.text = "Counterspell"
	window.list_box.text_changed.emit()
	assert_true(window.go_button.disabled, "nothing to draw")
	window.close()
	assert_true(button.has_focus(), "back on the button that opened it")
	await get_tree().process_frame
	Options.DrawSetup._kept = saved


func test_the_colours_filter_as_the_deck_builder_does() -> void:
	var gold_card := ""
	for card_name in CardRegistry.all_names():
		var d := CardRegistry.get_card(card_name)
		if not d.is_land() and DeckFilter.WUBRG_MASK & d.color_mask() \
				and (d.color_mask() & (d.color_mask() - 1)) & DeckFilter.WUBRG_MASK:
			gold_card = card_name
			break
	assert_ne(gold_card, "", "the game has a gold card")
	var names: Array[String] = POOL.duplicate()
	names.append(gold_card)
	names.append("Sol Ring")
	var red := Options.DrawSetup.colour_pool(names, [false, false, false, true, false], false)
	assert_eq(red, ["Lightning Bolt", "Forest", "Shivan Dragon", "Sol Ring"] as Array[String],
		"red, and the land and the artifact the colours never filter")
	var gold := Options.DrawSetup.colour_pool(names, [false, false, false, false, false], true)
	assert_has(gold, gold_card)
	assert_does_not_have(gold, "Lightning Bolt")
	assert_eq(Options.DrawSetup.colour_pool(names, [true, true, true, true, true], true), names)


func test_the_drawn_cards_land_in_the_middle_in_one_row_or_two() -> void:
	var view := Vector2(1280, 800)
	var one := Options.DrawScreen.layout(view, 1)
	assert_eq(one.spots, [view * 0.5] as Array[Vector2], "one card: the middle")
	assert_eq(float(one.scale), Options.DrawScreen.MOST_SCALE, "and big")
	var four := Options.DrawScreen.layout(view, 4)
	assert_eq(four.spots.size(), 4)
	for spot in four.spots:
		assert_almost_eq(spot.y, view.y * 0.5, 0.01, "four in one row")
	var seven := Options.DrawScreen.layout(view, 7)
	var rows := {}
	for spot in seven.spots:
		rows[roundi(spot.y)] = int(rows.get(roundi(spot.y), 0)) + 1
	assert_eq(rows.values(), [4, 3], "seven in two rows, the top one fuller")
	assert_gt(float(seven.scale), (view.x / 7.0) / CardPreview.SIZE.x,
		"bigger than seven in one row would be")
	for n in range(1, Options.DrawScreen.MOST + 1):
		var where := Options.DrawScreen.layout(view, n)
		var card: Vector2 = CardPreview.SIZE * float(where.scale)
		for i in where.spots.size():
			var rect := Rect2(where.spots[i] - card * 0.5, card)
			assert_true(Rect2(Vector2.ZERO, view).encloses(rect), "%d cards: on the screen" % n)
			for k in range(i + 1, where.spots.size()):
				assert_false(rect.intersects(Rect2(where.spots[k] - card * 0.5, card)),
					"%d cards: none over another" % n)


func test_a_draw_takes_each_card_once_and_all_of_a_short_pool() -> void:
	var draw := _draw(3)
	assert_eq(draw.drawn.size(), 3)
	for card_name in draw.drawn:
		assert_has(POOL, card_name)
		assert_eq(draw.drawn.count(card_name), 1, "once each")
	var short := _draw(7, ["Forest", "Counterspell"] as Array[String])
	assert_eq(short.drawn.size(), 2)
	assert_has(short.drawn, "Forest")
	assert_has(short.drawn, "Counterspell")


func test_each_card_spins_face_down_first_and_lands_face_up_as_the_card_drawn() -> void:
	var draw := _draw(3)
	var first: Dictionary = draw._spinners[0]
	var third: Dictionary = draw._spinners[2]
	var saw := {"back": false, "edge": false, "faces": {}}
	draw._tick(0.01)
	assert_true((first.node as Control).visible)
	assert_true((first.back as Control).visible, "face down to start with")
	assert_false((third.node as Control).visible, "the third waits its turn")
	assert_lt((first.node as Control).scale.x, float(first.scale) * 0.2, "small, far away")
	_spin(draw, Options.DrawScreen.SPIN_SECONDS * 0.9, func() -> void:
		if (first.back as Control).visible:
			saw.back = true
		if (first.turn as Control).scale.x < 0.2:
			saw.edge = true
		if (first.face as Control).visible:
			saw.faces[(first.face as CardPreview)._shown] = true)
	assert_true(saw.back and saw.edge, "it turns over and over")
	assert_eq(draw.landed(), 0)
	assert_true((third.node as Control).visible, "the third is on its way")
	_spin(draw, Options.DrawScreen.SPIN_SECONDS + 2.0 * Options.DrawScreen.STAGGER)
	assert_eq(draw.landed(), 3, "all down")
	for spinner in draw._spinners:
		var holder: Control = spinner.node
		var spot: Vector2 = spinner.spot
		assert_almost_eq(holder.position + CardPreview.SIZE * 0.5, spot, Vector2.ONE * 0.01,
			"in its place")
		assert_true((spinner.face as Control).visible, "face up")
		assert_false((spinner.back as Control).visible)
		assert_eq((spinner.turn as Control).scale, Vector2.ONE, "flat")
		assert_eq((spinner.face as CardPreview)._shown.data.card_name, spinner.name,
			"as the card drawn")
		assert_almost_eq(holder.rotation, float(spinner.tilt), 0.0001, "still")
	assert_eq(draw.drawn, draw._spinners.map(func(s: Dictionary) -> String: return s.name))


func test_a_rare_drawn_card_wears_the_foil_unless_it_is_switched_off() -> void:
	var rare := ""
	for card_name in CardRegistry.all_names():
		if CardRegistry.rarity_of(card_name, "") == "rare":
			rare = card_name
			break
	var lit := _draw(1, [rare] as Array[String])
	_spin(lit, Options.DrawScreen.SPIN_SECONDS + 0.1)
	assert_not_null((lit._spinners[0].turn as Control).find_child("Foil", false, false))
	var plain := _draw(1, [rare] as Array[String])
	plain.foil = false
	plain.regenerate()
	_spin(plain, Options.DrawScreen.SPIN_SECONDS + 0.1)
	assert_null((plain._spinners[0].turn as Control).find_child("Foil", false, false))


func test_r_draws_again_and_a_pause_holds_the_spin() -> void:
	var draw := _draw(2)
	_spin(draw, 1.0)
	var first: Dictionary = draw._spinners[0]
	draw._input(_key(KEY_SPACE))
	var t := float(first.t)
	draw._process(0.5)
	assert_eq(float(first.t), t, "paused")
	draw._input(_key(KEY_SPACE))
	draw._input(_key(KEY_R))
	assert_ne(draw._spinners[0], first, "R draws again")
	assert_eq(float(draw._spinners[0].t), 0.0, "from the start")
	assert_eq(draw.landed(), 0)


func test_big_cards_cut_their_letters_at_their_size_and_no_new_deal_follows() -> void:
	get_viewport().oversampling_override = 0.0
	var auto := get_viewport().get_oversampling()
	var draw := _draw(1)
	assert_almost_eq(get_viewport().oversampling_override,
		auto * Options.DrawScreen.MOST_SCALE, 0.001)
	assert_lt(draw._resize_due, 0.0, "the sharpness is no new screen")
	draw.leave()
	await get_tree().process_frame
	assert_eq(get_viewport().oversampling_override, 0.0)
