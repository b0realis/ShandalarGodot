extends GutTest
## WHAT THE TABLE MAY TELL WHOM — the bug pass of 2026-10-03, two halves of
## one rule (CONTRIBUTING hard rule 8 is the AI's half of fair information;
## this is the screen's).
##
## 1. THE PRIVATE LOG LINE. The Duel Log window and the running
##    `duel_log.txt` printed every engine line verbatim, so the AI's Demonic
##    Tutor find ("... searches their library and finds Lord of the Pit")
##    and Sylvan Library's top cards were on the player's screen and in the
##    player's file. The engine marks such a line with two meta keys —
##    `private_to` (the seat it belongs to) and `public` (the sentence
##    everyone else may read) — and the screen prints `public` wherever
##    that seat's secrets are not the local viewer's to see. Pinned with
##    synthetic meta, so it holds whichever side lands first.
## 2. THE LOOK. `MtgGame.information_revealed` (Glasses of Urza,
##    Inquisition, Amnesia, Rag Man, Nebuchadnezzar) was connected only by
##    SGManalink; on the local table a "look at" showed nothing at all. It
##    now opens a window naming the cards — for the seat the signal names
##    (or everyone, viewer -1), and never for a seat the viewer is not.


const FOUND := "%s searches their library and finds Lord of the Pit"
const HIDDEN := "%s searches their library and finds a card"


func _table(config: DuelConfig) -> DuelScreen:
	config.pace = 1000.0     # no AI dwell fires inside a test
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	return screen


func _vs_ai() -> DuelScreen:
	return await _table(DuelConfig.vs_ai_default(AiProfile.wizard()))


## One private line, the way the engine marks it: the full sentence for
## [param seat], the redacted one for everybody else.
func _private_line(screen: DuelScreen, seat: int) -> void:
	var g: MtgGame = screen.game
	var who: String = g.players[seat].player_name
	var meta := {"turn": g.turn_number, "step": g.current_step(), "pid": seat,
		"kind": "", "card": "Lord of the Pit", "colors": 0,
		"private_to": seat, "public": HIDDEN % who}
	g.log_lines.append(FOUND % who)
	g.log_meta.append(meta)
	g.log_appended.emit(FOUND % who, meta)


# ============================================================ the log --

func test_the_ais_private_find_reaches_the_window_redacted() -> void:
	var screen := await _vs_ai()
	screen._open_duel_log()
	_private_line(screen, 1)
	var body := screen._duel_log.text()
	assert_false(body.contains("Lord of the Pit"), "the AI's find is not the player's to read")
	assert_true(body.contains("searches their library and finds a card"),
		"the public sentence stands in its place")


## END TO END: the engine's own private line (MtgGame.log_line's
## `private_to`/`public`) through the real screen — the AI resolves Demonic
## Tutor's search (no reveal) and the player's log window never names it.
func test_the_ais_real_demonic_tutor_find_is_redacted_on_screen() -> void:
	var config := DuelConfig.vs_ai_default(AiProfile.wizard())
	var d0: Array = []
	for i in 40:
		d0.append("Forest")
	var d1: Array = []
	for i in 39:
		d1.append("Swamp")
	d1.append("Lord of the Pit")
	config.decks = [d0, d1]
	var screen := await _table(config)
	screen._open_duel_log()
	var search: SearchLibraryEffect = null
	for effect in CardRegistry.get_card("Demonic Tutor").spell_effects:
		if effect is SearchLibraryEffect:
			search = effect
	assert_not_null(search)
	var g: MtgGame = screen.game
	var hand_before := g.players[1].hand.size()
	search.resolve(g, null, 1, null, 0)
	assert_eq(g.players[1].hand.size(), hand_before + 1, "the AI found a card")
	var body := screen._duel_log.text()
	assert_true(body.contains("searches their library and finds a card"), body)
	for card in g.players[1].hand:
		if card.data.card_name != "Swamp":
			assert_false(body.contains(card.data.card_name),
				"the AI's find (%s) is not the player's to read" % card.data.card_name)


## The AI's masked creature, named by an engine line, reaches the player's
## window nameless; a line about both seats' masks is redacted for anyone
## who cannot see both hands (MtgGame.FACE_DOWN_NOBODY).
func test_the_ais_face_down_creature_is_nameless_in_the_window() -> void:
	var config := DuelConfig.vs_ai_default(AiProfile.wizard())
	var d0: Array = []
	var d1: Array = []
	for i in 40:
		d0.append("Forest")
		d1.append("Shivan Dragon")
	config.decks = [d0, d1]
	var screen := await _table(config)
	screen._open_duel_log()
	var g: MtgGame = screen.game
	var dragon := g.top_of_library_to_hand(1)
	assert_not_null(dragon)
	g.put_from_hand_face_down(dragon, 1)      # Illusionary Mask's route
	assert_true(dragon.face_down)
	g.add_counters(dragon, "+1/+1", 1)
	var body := screen._duel_log.text()
	assert_false(body.contains("Shivan Dragon gets"), "the mask's card is not the player's to read")
	assert_true(body.contains("A face-down creature gets 1"), body)
	assert_false(screen._sees_private_log(MtgGame.FACE_DOWN_NOBODY),
		"both seats' secrets in one line are nobody's against the computer")


func test_the_players_own_private_find_reads_in_full() -> void:
	var screen := await _vs_ai()
	screen._open_duel_log()
	_private_line(screen, 0)
	assert_true(screen._duel_log.text().contains("finds Lord of the Pit"),
		"the seat the line is private to reads all of it")


func test_a_window_opened_later_is_filled_redacted() -> void:
	var screen := await _vs_ai()
	_private_line(screen, 1)
	screen._open_duel_log()
	var body := screen._duel_log.text()
	assert_false(body.contains("Lord of the Pit"), "the refill reads the log the same way")
	assert_true(body.contains("finds a card"))


func test_a_line_without_the_keys_is_printed_as_it_is() -> void:
	var screen := await _vs_ai()
	screen._open_duel_log()
	var g: MtgGame = screen.game
	g.log_line("%s casts Lord of the Pit" % g.players[1].player_name, null, "cast", 1)
	assert_true(screen._duel_log.text().contains("casts Lord of the Pit"))


func test_the_running_file_gets_the_redacted_line() -> void:
	var dir := ProjectSettings.globalize_path("user://").path_join("duel_log_private_test")
	DirAccess.make_dir_recursive_absolute(dir)
	DuelLogFile.location = dir
	if FileAccess.file_exists(DuelLogFile.path()):
		DirAccess.remove_absolute(DuelLogFile.path())
	var screen := await _vs_ai()
	_private_line(screen, 1)
	_private_line(screen, 0)
	var file := FileAccess.open(DuelLogFile.path(), FileAccess.READ)
	var body := file.get_as_text() if file != null else ""
	if file != null:
		file.close()
	DirAccess.remove_absolute(DuelLogFile.path())
	DirAccess.remove_absolute(dir)
	DuelLogFile.location = ""
	# The file prints a seat's label for its name ("Player 2 (AI Wizard)
	# searches ..."), so the sentences are matched on their tails.
	assert_eq(body.count("finds Lord of the Pit"), 1,
		"the file beside the game keeps the AI's secret, and the player's own find")
	assert_eq(body.count("searches their library and finds a card"), 1,
		"and says what everyone saw in the AI's place")


func test_the_ai_demo_reads_everything() -> void:
	# Both hands are open to a spectator, so both seats' secrets are too.
	var screen := await _table(DuelConfig.demo_default())
	screen._open_duel_log()
	_private_line(screen, 0)
	_private_line(screen, 1)
	var body := screen._duel_log.text()
	assert_false(body.contains("finds a card"), "nothing is redacted for the spectator")
	assert_eq(body.count("finds Lord of the Pit"), 2)


func test_a_private_hotseat_prints_neither_seats_secret() -> void:
	# One window and one file serve both players at a private hotseat, and
	# either may be looking — so neither seat's private line is printed.
	var config := DuelConfig.hotseat_default()
	config.hotseat_privacy = true
	var screen := await _table(config)
	screen._open_duel_log()
	_private_line(screen, 0)
	_private_line(screen, 1)
	var body := screen._duel_log.text()
	assert_false(body.contains("Lord of the Pit"))
	assert_eq(body.count("finds a card"), 2)


func test_an_open_hotseat_prints_both() -> void:
	var screen := await _table(DuelConfig.hotseat_default())
	screen._open_duel_log()
	_private_line(screen, 1)
	assert_true(screen._duel_log.text().contains("finds Lord of the Pit"),
		"no seat is hidden at an open hotseat")


# =========================================================== the look --

func _reveal_text(screen: DuelScreen) -> String:
	var window: Variant = screen.get("_reveal_window")
	if window == null or not is_instance_valid(window) or window.is_queued_for_deletion():
		return ""
	var out := PackedStringArray()
	var stack: Array = [window]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Label:
			out.append((node as Label).text)
		for child in node.get_children():
			stack.push_front(child)
	return "\n".join(out)


func _glasses_look(screen: DuelScreen, controller: int) -> void:
	var g: MtgGame = screen.game
	var data := CardRegistry.get_card("Glasses of Urza")
	var glasses := CardInstance.new(data, g._next_instance_id, controller)
	g._next_instance_id += 1
	g._instances[glasses.id] = glasses
	var peek: EffectBase = data.activated_abilities[0].effects[0]
	peek.resolve(g, glasses, controller, TargetRef.player(1 - controller))


func test_a_public_reveal_opens_a_window_naming_the_cards() -> void:
	var screen := await _vs_ai()
	screen.game.reveal_information(-1, "Rag Man — revealed hand", ["Shivan Dragon", "Swamp"])
	var text := _reveal_text(screen)
	assert_true(text.contains("Rag Man — revealed hand"), "the window names the look")
	assert_true(text.contains("Shivan Dragon") and text.contains("Swamp"), "and the cards")


func test_glasses_of_urza_shows_the_player_their_look_and_not_the_ais() -> void:
	var screen := await _vs_ai()
	var ai_hand: Array = screen.game.players[1].hand
	assert_gt(ai_hand.size(), 0)
	_glasses_look(screen, 1)
	assert_eq(_reveal_text(screen), "", "the AI's look is the AI's alone")
	_glasses_look(screen, 0)
	var text := _reveal_text(screen)
	assert_true(text.contains("Glasses of Urza"), "the player's own look is shown")
	assert_true(text.contains(ai_hand[0].data.card_name), "with the hand it looked at")


func test_a_second_look_joins_the_open_window() -> void:
	var screen := await _vs_ai()
	screen.game.reveal_information(-1, "Inquisition — revealed hand", ["Forest"])
	screen.game.reveal_information(-1, "Amnesia — revealed hand", ["Island"])
	var windows := 0
	for child in screen.get_children():
		if child is OriginalDialog and not child.is_queued_for_deletion():
			windows += 1
	assert_eq(windows, 1, "one window, not a pile of them")
	var text := _reveal_text(screen)
	assert_true(text.contains("Inquisition") and text.contains("Amnesia"))


func test_escape_closes_the_look_and_nothing_under_it() -> void:
	var screen := await _vs_ai()
	screen.game.reveal_information(-1, "Nebuchadnezzar — revealed cards", ["Swamp"])
	assert_ne(_reveal_text(screen), "")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	screen._unhandled_key_input(esc)
	assert_eq(_reveal_text(screen), "", "Escape answered the window")
	assert_false(screen.is_paused(), "and did not reach past it")


func test_a_private_hotseat_shows_a_look_only_to_its_seat() -> void:
	var config := DuelConfig.hotseat_default()
	config.hotseat_privacy = true
	var screen := await _table(config)
	var g: MtgGame = screen.game
	g.active_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	screen._refresh()
	g.reveal_information(1, "Visions — top cards, top first", ["Serra Angel"])
	g.reveal_information(0, "Glasses of Urza — hand", ["Hurricane"])
	assert_eq(_reveal_text(screen), "", "nobody's hand is shown: nobody's look either")
	screen._toggle_hotseat_hand(0)
	var text := _reveal_text(screen)
	assert_true(text.contains("Hurricane"), "seat 0 sees its own look once it shows its hand")
	assert_false(text.contains("Serra Angel"), "and never seat 1's")
	screen._toggle_hotseat_hand(0)
	assert_eq(_reveal_text(screen), "", "hiding the hand closes the look")
	g.active_player = 1
	screen._refresh()
	screen._toggle_hotseat_hand(1)
	text = _reveal_text(screen)
	assert_true(text.contains("Serra Angel"), "seat 1 gets its own look in its turn")
	assert_false(text.contains("Hurricane"))
