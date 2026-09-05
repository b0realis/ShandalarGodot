extends GutTest
## THE OPENING COIN TOSS AND ITS THREE PRESENTATIONS — `docs/duel-todo.md`
## §6.4, `docs/duel-screen-design.md`'s fiftieth pass.
##
## The 1997 toss was a MOVIE (`COINTOSS_Heads.AVI` / `COINTOSS_Tails.AVI`,
## embedded with `MCIWndCreateA`), which is why `Show coin flip
## animations` gated playing one and why no coin art exists to import.
## [CoinToss]'s class doc carries the whole provenance chain. What is
## pinned here is the behaviour:
##
##  - the 1997 checkbox and the `[QoL]` three-way are ONE stored value;
##  - a 1997 registry export still reads into that value;
##  - each mode selects its own presentation, and the movie DEGRADES to
##    our animation when the footage is not imported;
##  - the badge says which seat won, three ways;
##  - a headless run presents nothing and waits for nothing;
##  - and none of it is a second source of randomness.


var _saved: Variant = null
var _had_setting := false


func before_each() -> void:
	# `ShowCoinFlips` is a REAL key in the player's own settings.cfg, so
	# every test that touches it puts it back — and puts it back by
	# CLEARING when there was nothing there, because writing the default
	# in would materialise it into the file (the bug `clear_value` exists
	# for; it shipped a "fan" hand once).
	# Read only when there IS one: ConfigFile.get_value errors on a
	# missing key with a null default.
	_had_setting = Settings.has_value(DuelOptions.COIN_FLIP_KEY)
	_saved = Settings.get_value(DuelOptions.COIN_FLIP_KEY, "") \
		if _had_setting else null


func after_each() -> void:
	if _had_setting:
		Settings.set_value(DuelOptions.COIN_FLIP_KEY, _saved)
	else:
		Settings.clear_value(DuelOptions.COIN_FLIP_KEY)
	_clear_fake_video()


# ------------------------------------------------- one value, two views --

func test_the_three_modes_are_the_owners_three() -> void:
	var keys: Array[String] = []
	for row in DuelOptions.COIN_FLIP_STYLES:
		keys.append(String(row["key"]))
		assert_ne(String(row["label"]), "", "%s has a label" % row["key"])
		assert_ne(String(row["blurb"]), "", "%s explains itself" % row["key"])
	assert_eq(keys, ["video", "recreation", "instant"],
		"the original's movie, our animation, and the result alone")


func test_the_1997_checkbox_is_a_view_of_the_three_way() -> void:
	# `Show coin flip animations` is a BOOL in 1997 and stays one here.
	# Ticked = the toss is acted out, by either animated mode.
	for style in [DuelOptions.COIN_VIDEO, DuelOptions.COIN_RECREATION]:
		DuelOptions.set_coin_flip_style(style)
		assert_true(DuelOptions.toggle(DuelOptions.COIN_FLIP_KEY),
			"%s ticks the 1997 checkbox" % style)
	DuelOptions.set_coin_flip_style(DuelOptions.COIN_INSTANT)
	assert_false(DuelOptions.toggle(DuelOptions.COIN_FLIP_KEY),
		"instant unticks it")


func test_the_two_views_share_one_stored_key() -> void:
	# Never a parallel copy: the checkbox writes the same key the list
	# reads, and there is no second key anywhere holding the style.
	DuelOptions.set_toggle(DuelOptions.COIN_FLIP_KEY, false)
	assert_eq(DuelOptions.coin_flip_style(), DuelOptions.COIN_INSTANT)
	assert_eq(String(Settings.get_value(DuelOptions.COIN_FLIP_KEY, "")),
		DuelOptions.COIN_INSTANT, "and it is IN ShowCoinFlips")

	DuelOptions.set_toggle(DuelOptions.COIN_FLIP_KEY, true)
	assert_eq(DuelOptions.coin_flip_style(), DuelOptions.COIN_FLIP_DEFAULT,
		"re-ticking returns the value to the default presentation")


func test_a_1997_registry_boolean_still_reads() -> void:
	# The whole reason the key spellings are the original's: a registry
	# export should drop straight into user://settings.cfg. 1997 wrote
	# 0/1 there, so 0/1 (and true/false) must still mean something.
	for on in [true, 1]:
		Settings.set_value(DuelOptions.COIN_FLIP_KEY, on)
		assert_eq(DuelOptions.coin_flip_style(), DuelOptions.COIN_FLIP_DEFAULT,
			"1997's ON becomes the default animated mode (%s)" % [on])
	for off in [false, 0]:
		Settings.set_value(DuelOptions.COIN_FLIP_KEY, off)
		assert_eq(DuelOptions.coin_flip_style(), DuelOptions.COIN_INSTANT,
			"1997's OFF becomes instant (%s)" % [off])


func test_an_unwritable_style_is_refused_into_the_default() -> void:
	DuelOptions.set_coin_flip_style("holographic")
	assert_eq(DuelOptions.coin_flip_style(), DuelOptions.COIN_FLIP_DEFAULT)
	assert_eq(String(Settings.get_value(DuelOptions.COIN_FLIP_KEY, "")),
		DuelOptions.COIN_FLIP_DEFAULT, "nothing unshowable reaches the file")


func test_the_default_is_the_originals_own_movie() -> void:
	# It was the recreation, on the reasoning that a machine with no
	# original files must still work. It does: `effective_style` downgrades
	# `video` to the recreation whenever the sheets are missing, so the
	# default costs a player nothing and gives the one who imported the
	# movies what they imported them FOR. (Possible only since 2026-09-03,
	# when the coin AVIs turned out to be CRAM rather than Indeo and became
	# importable at all.)
	assert_eq(DuelOptions.COIN_FLIP_DEFAULT, DuelOptions.COIN_VIDEO)
	assert_eq(CoinToss.effective_style(DuelOptions.COIN_VIDEO),
		DuelOptions.COIN_VIDEO if CoinToss.video_available()
		else DuelOptions.COIN_RECREATION,
		"and it is honest about what this machine can actually show")


func test_a_missing_video_degrades_to_our_animation_and_says_why() -> void:
	# The fallback is explained rather than silent, on every machine.
	assert_string_contains(CoinToss.VIDEO_MISSING, "Cointoss_Heads.avi")
	assert_string_contains(CoinToss.VIDEO_MISSING, "Microsoft Video 1",
		"the codec the 1997 coin actually is — the Indeo claim was the "
		+ "Manalink movies', and cost this project the coin toss for weeks")
	_clear_fake_video()
	if CoinToss.video_available():
		pass_test("the 1997 movies ARE imported on this machine — the "
			+ "fallback has nothing to fall back from")
		return
	assert_eq(CoinToss.effective_style(DuelOptions.COIN_VIDEO),
		DuelOptions.COIN_RECREATION,
		"it falls back to the RECREATION, never to instant — someone who "
		+ "asked to watch the toss should still watch it")


func test_the_video_plays_when_the_footage_is_there() -> void:
	# THE SHEET HERE IS SYNTHETIC. There is no genuine coin footage on
	# this machine (or in any reference tree), so this stands in a fake
	# sheet + sidecar through GameSkin's own caches — the same shape the
	# importer writes — and exercises the selection and the frame walk.
	# It is NOT a test of the real movies' appearance.
	_install_fake_video(4, 3, 10, 32, 24, 15.0)
	assert_true(CoinToss.video_available(), "both faces are present")
	assert_eq(CoinToss.effective_style(DuelOptions.COIN_VIDEO),
		DuelOptions.COIN_VIDEO)

	var meta := CoinToss.video_meta(CoinToss.HEADS)
	assert_almost_eq(CoinToss.video_length(meta), 10.0 / 15.0, 0.001,
		"10 frames at 15fps")
	# Row-major, which is how the importer tiles them.
	assert_eq(CoinToss.video_frame_rect(meta, 0), Rect2i(0, 0, 32, 24))
	assert_eq(CoinToss.video_frame_rect(meta, 5), Rect2i(32, 24, 32, 24))
	assert_eq(CoinToss.video_frame_rect(meta, 9), Rect2i(32, 48, 32, 24),
		"frame 9 of a 4-wide sheet is column 1 of row 2")


func test_the_movie_clock_is_pure_and_plays_once() -> void:
	var meta := {"frames": 10, "fps": 15.0, "cols": 4,
		"frame_width": 32, "frame_height": 24}
	assert_eq(CoinToss.video_frame_at(meta, 0.0), 0)
	assert_eq(CoinToss.video_frame_at(meta, 1.0 / 15.0), 1)
	assert_eq(CoinToss.video_frame_at(meta, 0.999), 9)
	assert_eq(CoinToss.video_frame_at(meta, 9999.0), 9,
		"past the end it HOLDS the last frame — a coin toss plays once")
	assert_eq(CoinToss.video_frame_at({"frames": 0}, 1.0), 0,
		"and an empty sheet never indexes off the end")
	# The original's own guard: `DUEL.EXE`'s toss dialog gives up after
	# fifteen seconds, so no sidecar can hold a duel open longer.
	assert_eq(CoinToss.VIDEO_TIMEOUT, 15.0)


func test_a_half_imported_video_is_no_video() -> void:
	# One face without the other is useless: the toss can come up either
	# way, so a half-finished import must degrade rather than crash.
	_install_fake_video(4, 3, 10, 32, 24, 15.0)
	GameSkin._texture_cache["coin_toss_tails"] = null
	assert_false(CoinToss.video_available())
	assert_eq(CoinToss.effective_style(DuelOptions.COIN_VIDEO),
		DuelOptions.COIN_RECREATION)


func test_a_sheet_with_no_sidecar_is_no_video() -> void:
	# The grid is not guessable — frame size, count and rate come off
	# whatever AVI the player owns — so a sheet without its .json is not
	# playable.
	_install_fake_video(4, 3, 10, 32, 24, 15.0)
	GameSkin._meta_cache["coin_toss_heads"] = {}
	assert_true(CoinToss.video_meta(CoinToss.HEADS).is_empty())
	assert_false(CoinToss.video_available())


# ------------------------------------------------- the toss never decides --

func test_the_coin_lands_on_the_seat_the_engine_chose() -> void:
	# The animation REPORTS the leader; it must never pick one. The coin
	# starts on whichever face leaves the winner up after HALF_TURNS
	# alternations.
	for winner in 2:
		var face: int = CoinToss.toss_start_face(winner)
		assert_true(face == 0 or face == 1, "a coin has two faces")
		assert_eq(posmod(face + CoinToss.HALF_TURNS, 2), winner,
			"seat %d's face is up when the coin settles" % winner)


func test_the_presentation_carries_no_randomness_of_its_own() -> void:
	# Hard rule 7: randomness only via MtgGame.rng. The toss is rolled
	# once, in DuelScreen._new_game; a presentation that rolled anything
	# would be a second source and would break a seeded replay.
	var source := FileAccess.get_file_as_string("res://game/duel/coin_toss.gd")
	assert_ne(source, "", "the file reads")
	for forbidden in ["randi", "randf", "rand_range", "randomize",
			"RandomNumberGenerator", "pick_random", "shuffle"]:
		assert_false(source.contains(forbidden),
			"CoinToss must not call %s" % forbidden)


func test_reporting_the_same_outcome_twice_reports_the_same_thing() -> void:
	for winner in 2:
		for seat in 2:
			assert_eq(CoinToss.result_face(winner, seat),
				CoinToss.result_face(winner, seat))
			assert_eq(CoinToss.result_line(winner, seat),
				CoinToss.result_line(winner, seat))


# --------------------------------------------------- the words and the icon --

func test_the_caption_is_the_1997_dialogs_own_two_strings() -> void:
	# `@DIALOG_COINFLIP`, s30/assets/text/Uistrings.txt:593-596 — the clean
	# 1997 copy, and `Program/UIStrings.txt` reads identically here.
	assert_eq(CoinToss.RESULT_LINES, ["Coin flip results: Heads",
		"Coin flip results: Tails"] as Array[String])
	assert_eq(CoinToss.TITLE, "Start of Duel",
		"@DIALOG_STARTCOINFLIP, Uistrings.txt:483-485")


func test_the_caption_names_a_face_per_seat() -> void:
	# Ours, and marked as ours in the source: the coin is called for the
	# seat you sit in, so Heads is that seat winning.
	assert_eq(CoinToss.result_line(0, 0), CoinToss.RESULT_LINES[CoinToss.HEADS])
	assert_eq(CoinToss.result_line(1, 0), CoinToss.RESULT_LINES[CoinToss.TAILS])
	assert_eq(CoinToss.result_line(1, 1), CoinToss.RESULT_LINES[CoinToss.HEADS],
		"the viewer's seat is always the near one")


func test_the_verdict_is_the_play_or_draw_dialogs_own_sentence() -> void:
	assert_eq(CoinToss.verdict_line(true, "anyone"),
		OpeningHand.PLAY_OR_DRAW["you_won"])
	assert_eq(CoinToss.verdict_line(false, "Black Wizard"),
		"Black Wizard won the toss")


func test_the_badge_points_at_the_winning_seats_half() -> void:
	# Mode 3's whole job: say which seat won, at a glance. The board is
	# not mirrored and the viewer sits at the bottom, so the chevron is
	# aimed at the winner's actual territory.
	var config := DuelConfig.hotseat_default()
	for winner in 2:
		var badge: Control = CoinToss.result_badge(config, winner, 0)
		add_child_autofree(badge)
		# DRAWN, not lettered: the 1997 body face has no triangle glyph,
		# and a Label of one renders nothing at all (caught by the
		# screenshot pass, not by a test — hence this one).
		var arrows: Array[CoinToss.Chevron] = []
		for child in badge.get_children():
			if child is CoinToss.Chevron:
				arrows.append(child)
		assert_eq(arrows.size(), 1,
			"exactly one pointer — a badge with both says nothing")
		if arrows.is_empty():
			continue
		assert_eq(arrows[0].down, winner == 0,
			"seat %d's own half of the table is pointed at" % winner)


func test_the_badge_names_the_seat_so_a_mirror_match_still_reads() -> void:
	# Two decks of one colour strike two identical coins; the name is
	# what is left to tell the seats apart.
	var config := DuelConfig.hotseat_default()
	config.panel_colors = ["white", "white"]
	config.player_names = ["Near Wizard", "Far Wizard"]
	var far: Control = CoinToss.result_badge(config, 1, 0)
	add_child_autofree(far)
	assert_true(_labels_of(far).has("Far Wizard"))
	var near: Control = CoinToss.result_badge(config, 0, 0)
	add_child_autofree(near)
	assert_true(_labels_of(near).has("Your seat"),
		"the seat you are sitting in is named in the second person, as "
		+ "@DIALOG_PLAYORDRAW names it")


func test_the_badge_strikes_one_coin_in_the_winning_seats_colour() -> void:
	var config := DuelConfig.hotseat_default()
	config.panel_colors = ["blue", "green"]
	for winner in 2:
		var badge: Control = CoinToss.result_badge(config, winner, 0)
		add_child_autofree(badge)
		var coins: Array[Panel] = []
		for child in badge.get_children():
			if child is Panel:
				coins.append(child)
		assert_eq(coins.size(), 1, "exactly one coin, face up")
		if coins.is_empty():
			continue
		assert_eq(coins[0].custom_minimum_size,
			Vector2(CoinToss.COIN, CoinToss.COIN),
			"struck at the coin's own size")
		# Without the 1997 Manasymbols.pic the device is the colour's
		# letter, which is the one reading available on every machine.
		var device: Node = coins[0].get_child(0)
		if device is Label:
			assert_eq((device as Label).text,
				String(CoinToss.FACE_SYMBOL[config.panel_colors[winner]]),
				"the winner's colour is on the face")


func test_every_deck_colour_has_a_coin_face() -> void:
	for color_key in ["white", "blue", "black", "red", "green"]:
		assert_true(CoinToss.FACE_SYMBOL.has(color_key),
			"%s has a coin face" % color_key)
		var face: Control = CoinToss.build_face(color_key)
		add_child_autofree(face)
		assert_eq(face.get_child_count(), 1,
			"%s's face bears exactly one device" % color_key)


# --------------------------------------------------------------- headless --

func test_headless_presents_nothing_and_waits_for_nothing() -> void:
	# The suite and the Deck Lab both run headless and must gain no wait
	# they did not have. Every mode, because the gate is in run() and not
	# in one branch of it.
	for style in [DuelOptions.COIN_VIDEO, DuelOptions.COIN_RECREATION,
			DuelOptions.COIN_INSTANT]:
		DuelOptions.set_coin_flip_style(style)
		var toss := CoinToss.new()
		add_child_autofree(toss)
		var config := DuelConfig.hotseat_default()
		var started := Time.get_ticks_msec()
		await toss.run(config, 0, true, 0)
		assert_eq(toss.get_child_count(), 0,
			"%s builds no panel headless" % style)
		assert_lt(Time.get_ticks_msec() - started, 200,
			"%s adds no delay" % style)


# ------------------------------------------ the two views, on the screen --

func test_the_options_screen_offers_all_three_and_greys_what_it_cannot() -> void:
	var screen: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var picker := _coin_picker(screen)
	assert_not_null(picker, "the [QoL] Options screen carries the full list")
	if picker == null:
		return
	assert_eq(picker.item_count, DuelOptions.COIN_FLIP_STYLES.size())
	for i in DuelOptions.COIN_FLIP_STYLES.size():
		assert_eq(picker.get_item_text(i),
			String(DuelOptions.COIN_FLIP_STYLES[i]["label"]))
	# The original's habit: grey what you cannot offer rather than
	# shorten the menu (`Duel.hlp`, **Territory**).
	assert_eq(picker.is_item_disabled(0), not CoinToss.video_available(),
		"the movie is offered only when the footage is imported")
	# And the picker shows what will HAPPEN, not what is merely stored.
	assert_eq(picker.get_item_text(picker.selected),
		String(DuelOptions.coin_flip_style_row(CoinToss.current_style())["label"]))


func test_the_1997_panel_and_the_options_screen_never_disagree() -> void:
	# The panel's checkbox and the screen's list are two views of ONE
	# value, so setting either must be visible in the other.
	for style in [DuelOptions.COIN_INSTANT, DuelOptions.COIN_RECREATION]:
		DuelOptions.set_coin_flip_style(style)
		var panel: OriginalDialog = DuelOptions.window()
		add_child_autofree(panel)
		await get_tree().process_frame
		var check := _coin_checkbox(panel)
		assert_not_null(check, "the 1997 panel still carries the checkbox")
		if check == null:
			return
		assert_eq(check.button_pressed, style != DuelOptions.COIN_INSTANT,
			"%s reads back on the 1997 checkbox" % style)

	# And the other way: unticking the 1997 checkbox is seen by the list.
	var window: OriginalDialog = DuelOptions.window()
	add_child_autofree(window)
	await get_tree().process_frame
	var box := _coin_checkbox(window)
	if box == null:
		return
	box.button_pressed = false
	box.toggled.emit(false)
	assert_eq(DuelOptions.coin_flip_style(), DuelOptions.COIN_INSTANT,
		"the checkbox wrote the value the list reads")


func _coin_picker(root: Node) -> OptionButton:
	# By its own first label, so it is not confused with the hand-display
	# or rules-preset lists on the same screen.
	var first := String(DuelOptions.COIN_FLIP_STYLES[0]["label"])
	for node in _walk(root):
		if node is OptionButton and (node as OptionButton).item_count > 0 \
				and (node as OptionButton).get_item_text(0) == first:
			return node
	return null


func _coin_checkbox(root: Node) -> CheckBox:
	for node in _walk(root):
		if node is CheckBox \
				and (node as CheckBox).text == "Show coin flip animations":
			return node
	return null


func _walk(node: Node) -> Array:
	var out: Array = [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out


# ------------------------------------------------------------- fake video --

## A stand-in sheet + sidecar in [GameSkin]'s own caches. Reaching into
## the caches is deliberate: the alternative is writing PNGs into the
## player's skin directory from a test, and the caches are exactly the
## seam the real loader hands its answers through.
func _install_fake_video(cols: int, rows: int, frames: int, fw: int, fh: int,
		fps: float) -> void:
	for key in ["coin_toss_heads", "coin_toss_tails"]:
		var img := Image.create(cols * fw, rows * fh, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.4, 0.4, 0.4))
		GameSkin._texture_cache[key] = ImageTexture.create_from_image(img)
		GameSkin._meta_cache[key] = {
			"cols": cols, "rows": rows, "frames": frames,
			"frame_width": fw, "frame_height": fh, "fps": fps,
		}


func _clear_fake_video() -> void:
	for key in ["coin_toss_heads", "coin_toss_tails"]:
		GameSkin._texture_cache.erase(key)
		GameSkin._meta_cache.erase(key)


func _labels_of(node: Node) -> Array[String]:
	var out: Array[String] = []
	for child in node.get_children():
		if child is Label:
			out.append((child as Label).text)
	return out
