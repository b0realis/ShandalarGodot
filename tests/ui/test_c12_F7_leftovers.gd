extends GutTest
## THE BUG CAMPAIGN c12'S LEFTOVERS ON SCREEN (fixer F7, 2026-10-27):
##  - Escape on a popup with no cancel action (the pack notice's several
##    buttons) closes it without an engine error — `UiChrome.dismiss_popup`
##    asked the veil for a meta that a null had erased (F3's need).
##  - PAUSE HOLDS THE VIDEO TOSS (h4-8, F2's need): the movie ran on the
##    wall clock and the verdict's timer on the tree's, so a Pause window
##    over the toss let both run out under it. The toss now keeps its own
##    clock, held whenever it is ([method CoinToss.hold], or the process
##    mode the duel screen's Pause already sets).
##  - The Help says what Randomize, the Sealed Deck booster and the card
##    menu's Original type really do.


# ------------------------------------------------- a popup with no cancel --

func test_escape_on_a_popup_with_no_cancel_raises_no_engine_error() -> void:
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child_autofree(host)
	var pressed: Array = []
	var veil := UiChrome.action_popup(host, "Two ways", "Choose one.", [
		{"label": "One", "callable": func() -> void: pressed.append("One")},
		{"label": "Two", "callable": func() -> void: pressed.append("Two")}])
	assert_false(veil.has_meta(&"cancel_button"), "control: two buttons, no cancel")
	assert_eq(UiChrome.open_popup(host), veil)
	UiChrome.dismiss_popup(veil)
	assert_engine_error_count(0, "no 'meta not found' from the engine")
	await get_tree().process_frame
	assert_false(is_instance_valid(veil), "the popup simply closes")
	assert_eq(pressed, [], "and presses nothing")


func test_a_popup_with_a_cancel_still_presses_it() -> void:
	var host := Control.new()
	add_child_autofree(host)
	var pressed: Array = []
	var veil := UiChrome.action_popup(host, "Two ways", "Choose one.", [
		{"label": "Go", "callable": func() -> void: pressed.append("Go")},
		{"label": "Back", "cancel": true, "callable": func() -> void: pressed.append("Back")}])
	UiChrome.dismiss_popup(veil)
	assert_eq(pressed, ["Back"], "control: Escape stands for the cancel action")


# ------------------------------------------------------- the video toss --

func _watch_video(toss: CoinToss, panel: Control, face: int, done: Array) -> void:
	await toss._play_video(panel, face)
	done.append(true)


func _wait_on(toss: CoinToss, seconds: float, done: Array) -> void:
	await toss._wait(seconds)
	done.append(true)


## A fake movie of [param frames] frames at [param fps], installed through
## GameSkin's caches as `test_coin_toss.gd` installs it.
func _video_fixture(frames: int, fps: float) -> CoinToss:
	for key in ["coin_toss_heads", "coin_toss_tails"]:
		var img := Image.create(4 * 32, 3 * 24, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.4, 0.4, 0.4))
		GameSkin._texture_cache[key] = ImageTexture.create_from_image(img)
		GameSkin._meta_cache[key] = {"cols": 4, "rows": 3, "frames": frames,
			"frame_width": 32, "frame_height": 24, "fps": fps}
	var toss := CoinToss.new()
	add_child_autofree(toss)
	var panel := toss._build_panel(CoinToss.panel_size_for(DuelOptions.COIN_VIDEO,
		CoinToss.video_meta(CoinToss.HEADS)))
	toss.add_child(panel)
	return toss


func after_each() -> void:
	for key in ["coin_toss_heads", "coin_toss_tails"]:
		GameSkin._texture_cache.erase(key)
		GameSkin._meta_cache.erase(key)


## The duel screen's Pause holds the toss as it always has, by its process
## mode ([method DuelScreen._hold_opening]); the movie now stands still
## under it, on the frame it had reached, and plays on after it.
func test_pause_holds_the_movie_where_it_stands() -> void:
	var toss := _video_fixture(10, 15.0)   # two thirds of a second
	var panel := toss.get_child(0) as Control
	var done: Array = []
	_watch_video(toss, panel, CoinToss.HEADS, done)
	await get_tree().process_frame
	toss.process_mode = Node.PROCESS_MODE_DISABLED   # the Pause window opens
	var film := panel.get_child(panel.get_child_count() - 1) as TextureRect
	var region := (film.texture as AtlasTexture).region
	await wait_seconds(1.0)
	assert_true(done.is_empty(), "held past the movie's whole length, it has not finished")
	assert_true(toss._video_playing, "it is still the movie")
	assert_eq((film.texture as AtlasTexture).region, region, "standing on the frame it had reached")
	get_viewport().push_input(_press(true), true)
	assert_false(toss._video_skip_requested, "a click meant for the Pause window skips nothing")
	get_viewport().push_input(_press(false), true)
	toss.process_mode = Node.PROCESS_MODE_INHERIT    # and closes
	await wait_until(func() -> bool: return done.size() == 1, 10.0)
	assert_eq(done.size(), 1, "released, it plays out")
	assert_eq((film.texture as AtlasTexture).region, Rect2(CoinToss.video_frame_rect(
		CoinToss.video_meta(CoinToss.HEADS), 9)), "to its last frame")


## [method CoinToss.hold]: the toss stands still — its tweens with its
## process mode, its own clock, and the verdict's wait on that clock.
func test_hold_holds_the_toss_clock_and_the_verdicts_wait() -> void:
	var toss := CoinToss.new()
	add_child_autofree(toss)
	toss.hold(true)
	assert_eq(toss.process_mode, Node.PROCESS_MODE_DISABLED, "its tweens stand still")
	var held_at := toss.clock_ms()
	var done: Array = []
	_wait_on(toss, 0.2, done)
	await wait_seconds(0.6)
	assert_eq(toss.clock_ms(), held_at, "held, the toss's clock stands")
	assert_true(done.is_empty(), "and the verdict's 0.2 s have not run out in 0.6")
	toss.hold(false)
	assert_eq(toss.process_mode, Node.PROCESS_MODE_INHERIT)
	await wait_until(func() -> bool: return done.size() == 1, 10.0)
	assert_eq(done.size(), 1, "released, the verdict's wait runs out")
	assert_gt(toss.clock_ms(), held_at, "and the clock runs on")


## The duel screen's own line (the process mode) holds the verdict's wait
## too, and holding twice or releasing twice is harmless.
func test_the_process_mode_holds_the_verdicts_wait_too() -> void:
	var toss := CoinToss.new()
	add_child_autofree(toss)
	var done: Array = []
	_wait_on(toss, 0.2, done)
	toss.process_mode = Node.PROCESS_MODE_DISABLED
	toss.hold(true)
	await wait_seconds(0.6)
	assert_true(done.is_empty(), "held by the duel screen's Pause")
	toss.process_mode = Node.PROCESS_MODE_INHERIT
	toss.hold(false)
	await wait_until(func() -> bool: return done.size() == 1, 10.0)
	assert_eq(done.size(), 1, "and let go")
	var before := toss.clock_ms()
	await wait_seconds(0.2)
	assert_gt(toss.clock_ms() - before, 100, "released once, the clock is not held")


func _press(pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = Vector2(8, 8)
	event.global_position = event.position
	return event


# ------------------------------------------------------------- the Help --

func _page_text(title: String) -> String:
	for page in HelpPages.pages():
		if String(page["title"]) == title:
			var out := PackedStringArray()
			for block in page["blocks"]:
				if block is Dictionary and block.has("text"):
					out.append(String(block["text"]))
			return "\n".join(out)
	return ""


func test_the_help_says_randomize_leaves_the_waiting_packs_alone() -> void:
	var embark := _page_text("Shandalar — a new adventure")
	assert_string_contains(embark, "Randomize draws every choice")
	assert_false(embark.contains("the playmat, the card packs, the difficulty"),
		"the packs are not drawn while they wait")
	assert_string_contains(embark, "the card packs stay unticked while they wait")


func test_the_help_says_the_booster_deals_by_printed_rarity() -> void:
	var builder := ""
	for page in HelpPages.pages():
		for block in page["blocks"]:
			if block is Dictionary and String(block.get("text", "")).contains("Sealed Deck Tournament Simulation"):
				builder = String(block["text"])
	assert_ne(builder, "", "control: the Sealed Deck paragraph")
	assert_false(builder.contains("one rare or legend"), "a legend comes at the rarity it was printed at")
	assert_string_contains(builder, "printed")


func test_the_help_says_original_type_shows_a_copys_own_card() -> void:
	assert_string_contains(String(HelpPages.mini(HelpPages.MINI_CARD)["text"]), "Original type")
	assert_string_contains(_page_text("The parts of a card"), "Original type")
