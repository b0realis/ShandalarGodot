extends GutTest
## THE BATTLE-SETUP SCREEN (`game/setup_screen.gd`) — the pre-duel
## parameter screen, which is where the original put every one of these
## choices too (`@SHELLPAGE_MULTIDUEL`, `Program/Text.res:2852`).
##
## What these pin, in the order the screen was built:
##
##   1. **`<random deck>` is the list's first row**, spelled exactly as
##      the original spells it, and picking it still yields a real,
##      playable deck.
##   2. **The pick is a pure function of the seed.** That is the whole
##      claim `<random deck>` makes alongside "replay this duel from its
##      logged seed": two RNGs on one seed must name the same deck, and
##      two different seeds must be able to disagree.
##   3. **Every duel leaves here already seeded**, so the seed the duel
##      screen logs is the seed that chose the decks.


var screen: SetupScreen


func before_each() -> void:
	screen = load("res://game/setup_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func _deck_pickers() -> Array:
	return screen._deck_options


# ================================================== <random deck> (item 1) ==

func test_random_deck_is_the_first_row_and_worded_as_1997_worded_it() -> void:
	# `Program/Text.res:2866` — verbatim, angle brackets and all.
	assert_eq(SetupScreen.RANDOM_DECK, "<random deck>")
	for picker in _deck_pickers():
		assert_eq(picker.get_item_text(0), SetupScreen.RANDOM_DECK,
			"the random row sits above the decks, where 1997 put it")
		assert_eq(str(picker.get_item_metadata(0)), "",
			"the random row carries no path — that is what marks it")


func test_every_deck_row_carries_its_own_path() -> void:
	var picker: OptionButton = _deck_pickers()[0]
	assert_gt(picker.item_count, 1, "the shipped decks are listed")
	var decks := 0
	for i in range(1, picker.item_count):
		if picker.is_item_separator(i):
			continue     # a group heading, not a deck
		var path := str(picker.get_item_metadata(i))
		if path.begins_with(SetupScreen.GROUP_RANDOM):
			continue     # a POOLED random, not a deck (2026-09-05)
		decks += 1
		assert_true(path.ends_with(".deck") or path.ends_with(".dec")
			or path.ends_with(".dck"), "row %d names a deck file" % i)
		assert_true(FileAccess.file_exists(path), "row %d's file exists" % i)
	assert_eq(decks, screen._deck_paths.size(), "every scanned deck is listed")
	# `_deck_paths` is every deck the picker LISTS; `_playable_paths` is
	# the subset `<random deck>` may draw from (the proxy pass,
	# 2026-09-01). With no proxy decks saved the two are the same list.
	assert_lte(screen._playable_paths.size(), screen._deck_paths.size())


func test_the_random_pick_repeats_on_the_same_seed() -> void:
	var paths := screen._deck_paths
	assert_gt(paths.size(), 1, "more than one deck, or there is nothing to pick")
	var first := RandomNumberGenerator.new()
	first.seed = 20260901
	var second := RandomNumberGenerator.new()
	second.seed = 20260901
	# Both seats, in order — the real call sequence, not one draw.
	for _seat in 2:
		assert_eq(SetupScreen.random_deck_path(paths, first),
			SetupScreen.random_deck_path(paths, second),
			"one seed, one answer")


func test_different_seeds_can_disagree() -> void:
	var paths := screen._deck_paths
	var seen := {}
	for seed_value in range(1, 40):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		seen[SetupScreen.random_deck_path(paths, rng)] = true
	assert_gt(seen.size(), 1,
		"the pick actually varies with the seed — it is not a constant")


func test_the_random_pick_always_names_a_deck_we_scanned() -> void:
	var paths := screen._deck_paths
	for seed_value in range(1, 25):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		assert_true(paths.has(SetupScreen.random_deck_path(paths, rng)),
			"seed %d picked a deck from the list" % seed_value)


func test_an_empty_deck_list_does_not_crash_the_pick() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var none: Array[String] = []
	assert_eq(SetupScreen.random_deck_path(none, rng), "")


func test_a_random_seat_still_starts_a_playable_duel() -> void:
	# Seat 1 on `<random deck>`, seat 2 on a named deck: the config the
	# screen hands over must carry two real decks either way.
	_deck_pickers()[0].select(0)
	var picker := RandomNumberGenerator.new()
	picker.seed = 4242
	var path := screen._deck_path_for(0, picker)
	assert_ne(path, "", "the random seat resolved to a file")
	var deck := DeckList.load_file(path, true)
	assert_true(deck.errors.is_empty(), "and the file loads strictly")
	assert_gte(deck.cards.size(), 20, "and it is a duel-sized deck")


# ============================================================ the seed ==

func test_a_duel_never_leaves_this_screen_unseeded() -> void:
	# 0 means "roll one" to DuelConfig; the point of resolving it HERE is
	# that the seed which chose the decks is the seed the duel logs.
	for _i in 10:
		assert_ne(screen._resolve_seed(), 0)


# ============================================ the duelist's face (item 2) ==

func test_each_seat_shows_the_duelist_its_deck_makes_it() -> void:
	if not GameSkin.is_present():
		pass_test("no 1997 skin imported — the frame stays empty by design")
		return
	for pid in 2:
		var picker: OptionButton = _deck_pickers()[pid]
		assert_gt(picker.item_count, 1)
		var row := SetupScreen._row_of_deck(picker, 0)
		picker.select(row)
		screen._update_face(pid)
		var color := screen._color_of(str(picker.get_item_metadata(row)))
		assert_not_null(screen._face_rects[pid].texture,
			"seat %d has a portrait" % pid)
		assert_eq(screen._face_rects[pid].texture,
			DuelistFace.portrait(color),
			"and it is the one the DUEL will use for that colour")
		assert_eq(screen._face_captions[pid].text, "%s duelist" % color.capitalize())


func test_the_portrait_is_shown_at_the_size_1997_drew_it() -> void:
	assert_eq(SetupScreen.FACE_SIZE, Vector2(120, 88),
		"the life register's own size — the panel this is the other side of")
	for pid in 2:
		assert_eq(_deck_pickers().size(), 2)
		assert_eq(screen._face_rects[pid].custom_minimum_size,
			SetupScreen.FACE_SIZE)
		assert_eq(screen._face_rects[pid].stretch_mode,
			TextureRect.STRETCH_KEEP_CENTERED, "1:1, never scaled")


func test_random_deck_leaves_the_frame_empty_and_says_so() -> void:
	# There is no honest face before the seed is rolled, so none is shown.
	_deck_pickers()[0].select(0)
	screen._update_face(0)
	assert_null(screen._face_rects[0].texture)
	assert_eq(screen._face_captions[0].text, SetupScreen.RANDOM_DECK)


func test_changing_the_deck_changes_the_face() -> void:
	if not GameSkin.is_present():
		pass_test("no 1997 skin imported")
		return
	var picker: OptionButton = _deck_pickers()[0]
	var seen := {}
	for i in range(1, picker.item_count):
		if picker.is_item_separator(i):
			continue
		picker.select(i)
		screen._update_face(0)
		seen[screen._face_captions[0].text] = true
	assert_gt(seen.size(), 1,
		"the shipped decks are not all one colour, so neither are the faces")


# ============================================== the deck groups (item 3) ==

func test_the_picker_is_grouped_under_headings() -> void:
	var picker: OptionButton = _deck_pickers()[0]
	var headings := PackedStringArray()
	for i in picker.item_count:
		if picker.is_item_separator(i):
			headings.append(picker.get_item_text(i))
	assert_gt(headings.size(), 0, "the list has headings")
	for heading in headings:
		assert_true(DeckGroups.ORDER.has(heading),
			"'%s' is one of the groups, not an invented one" % heading)


func test_random_deck_sits_above_every_heading() -> void:
	# It is not a deck and belongs to no group, so no heading may precede
	# it — otherwise it would read as a member of that group.
	for picker in _deck_pickers():
		assert_eq(picker.get_item_text(0), SetupScreen.RANDOM_DECK)
		assert_false(picker.is_item_separator(0))


func test_no_heading_is_shown_with_nothing_under_it() -> void:
	var picker: OptionButton = _deck_pickers()[0]
	for i in picker.item_count:
		if not picker.is_item_separator(i):
			continue
		assert_lt(i, picker.item_count - 1,
			"a heading is never the last row")
		assert_false(picker.is_item_separator(i + 1),
			"a heading is never followed by another heading")


func test_headings_appear_in_the_declared_order() -> void:
	var picker: OptionButton = _deck_pickers()[0]
	var seen: Array[int] = []
	for i in picker.item_count:
		if picker.is_item_separator(i):
			seen.append(DeckGroups.ORDER.find(picker.get_item_text(i)))
	var sorted_copy := seen.duplicate()
	sorted_copy.sort()
	assert_eq(seen, sorted_copy, "1997 first, the player's own last")


func test_the_shipped_decks_declare_their_group() -> void:
	for path in DeckStore.deck_paths_in(DeckStore.SHIPPED_DIR):
		assert_eq(DeckGroups.of(path), DeckGroups.STARTER,
			"%s is one of this project's own decks" % path.get_file())


func test_a_deck_without_a_declaration_still_loads_and_is_grouped() -> void:
	# The backward-compatibility guarantee: `# group:` rides as a comment
	# DeckList already skips, so a file written before groups existed is
	# not merely tolerated — it is a normal deck with a default heading.
	var text := "name: Old Deck\n4 Lightning Bolt\n"
	assert_eq(DeckGroups.declared_in(text), "", "nothing declared")
	var list := DeckList.new()
	list.parse(text, "old", true)
	assert_true(list.errors.is_empty(), "and it still parses cleanly")
	assert_eq(list.cards.size(), 4)


func test_a_declaration_is_read_back_case_insensitively() -> void:
	assert_eq(DeckGroups.declared_in("# group: 1997 originals\n"),
		DeckGroups.ORIGINALS)
	assert_eq(DeckGroups.declared_in("#   group:   1997 Originals  \n"),
		DeckGroups.ORIGINALS)
	assert_eq(DeckGroups.declared_in(
		"# group: Duels of the Planeswalkers\n"), DeckGroups.PLANESWALKERS)


func test_an_unknown_group_is_ignored_rather_than_invented() -> void:
	assert_eq(DeckGroups.declared_in("# group: My Cool Decks\n"), "",
		"a typo cannot create a heading")


func test_a_declaration_does_not_disturb_the_decklist() -> void:
	var list := DeckList.new()
	list.parse("# group: 1997 originals\nname: X\n4 Lightning Bolt\n", "x", true)
	assert_true(list.errors.is_empty())
	assert_eq(list.cards.size(), 4, "the group line is a comment, nothing more")


func test_grouping_lists_only_groups_that_have_decks() -> void:
	var grouped := DeckGroups.grouped(screen._deck_paths)
	assert_gt(grouped.size(), 0)
	for group in grouped:
		assert_gt((grouped[group] as Array).size(), 0)
		assert_true(DeckGroups.ORDER.has(group))
	var total := 0
	for group in grouped:
		total += (grouped[group] as Array).size()
	assert_eq(total, screen._deck_paths.size(), "no deck is dropped")


# ============================================== the seed field (item 6) ==

func test_a_blank_seed_field_rolls_a_fresh_one_every_time() -> void:
	screen._seed_edit.text = ""
	var seen := {}
	for _i in 30:
		var value := screen._resolve_seed()
		assert_ne(value, 0, "0 means 'roll one' to DuelConfig")
		seen[value] = true
	assert_gt(seen.size(), 1, "blank really is random, not a constant")


func test_a_typed_seed_is_the_seed() -> void:
	screen._seed_edit.text = "20260901"
	assert_eq(screen._resolve_seed(), 20260901)
	assert_eq(screen._resolve_seed(), 20260901, "and it does not drift")


func test_a_typed_seed_survives_spaces() -> void:
	screen._seed_edit.text = "  4242  "
	assert_eq(screen._resolve_seed(), 4242)


func test_nonsense_in_the_seed_field_is_read_as_random() -> void:
	# The field is a plain box, so it can hold anything; a word in it is
	# the same request as an empty one, not an error to shout about.
	for junk in ["banana", "", "12.5", "-", "0x10"]:
		screen._seed_edit.text = junk
		assert_ne(screen._resolve_seed(), 0, junk)
	screen._seed_edit.text = "banana"
	var seen := {}
	for _i in 20:
		seen[screen._resolve_seed()] = true
	assert_gt(seen.size(), 1, "a word rolls a fresh seed each time")


func test_zero_and_negative_seeds_become_usable_ones() -> void:
	screen._seed_edit.text = "0"
	assert_eq(screen._resolve_seed(), 1, "0 is reserved for 'roll one'")
	screen._seed_edit.text = "-77"
	assert_eq(screen._resolve_seed(), 77,
		"the log prints a positive number, so the field takes one back")


func test_a_typed_seed_fixes_the_random_deck_too() -> void:
	# The claim item 1 makes and item 6 makes usable: one number replays
	# the WHOLE duel, deck choice included.
	screen._deck_options[0].select(0)          # <random deck>
	screen._seed_edit.text = "515151"
	var picks := PackedStringArray()
	for _i in 2:
		var rng := RandomNumberGenerator.new()
		rng.seed = screen._resolve_seed()
		picks.append(screen._deck_path_for(0, rng))
	assert_eq(picks[0], picks[1], "same seed, same deck")
	assert_ne(picks[0], "", "and it is a real deck")


# ============================================ the format picker (item 5) ==

func test_the_format_picker_offers_the_five_in_the_1997_order() -> void:
	assert_eq(screen._format_option.item_count, DeckFormat.ORDER.size())
	for i in DeckFormat.ORDER.size():
		assert_eq(screen._format_option.get_item_text(i), DeckFormat.ORDER[i])


func test_unrestricted_is_the_default_because_it_refuses_nothing() -> void:
	assert_eq(screen.deck_format(), DeckFormat.UNRESTRICTED)
	assert_eq(screen._format_note.text,
		String(DeckFormat.SUMMARY[DeckFormat.UNRESTRICTED]))


func test_the_note_warns_about_an_illegal_deck_before_go_is_pressed() -> void:
	# Blue Skies plays an Ancestral Recall, so Tournament (Type 1.5) bars
	# it — and the player should find out while they can still change the
	# deck, not on "Go!".
	var picker: OptionButton = _deck_pickers()[0]
	var blue := -1
	for i in picker.item_count:
		if not picker.is_item_separator(i) \
				and str(picker.get_item_metadata(i)).contains("blue_skies"):
			blue = i
			break
	assert_gt(blue, 0, "blue_skies.deck is in the list")
	picker.select(blue)
	screen._format_option.select(DeckFormat.ORDER.find(DeckFormat.TOURNAMENT_T15))
	screen._refresh_format_note()
	assert_true(screen._format_note.text.contains("Ancestral Recall"),
		"the note names the card that breaks the format")
	assert_true(screen._format_note.text.contains("Seat 1"),
		"and which seat it belongs to")


func test_the_note_is_clean_again_when_the_format_allows_the_deck() -> void:
	screen._format_option.select(DeckFormat.ORDER.find(DeckFormat.UNRESTRICTED))
	screen._refresh_format_note()
	assert_false(screen._format_note.text.contains("Seat"))


## THIRD AUDIT PASS (2026-09-01) — the note reads the SIDEBOARD too.
## `_refresh_format_note` passed `DeckList.load_file(path).cards` and
## nothing else, so a banned or restricted card in a deck's `SB:` lines
## went unseen here and on "Go!" — even though the between-duels sideboard
## step puts those cards INTO the deck. The call site is the half of that
## fix a `DeckFormat` unit test cannot reach.
func test_the_note_reads_the_sideboard_as_part_of_the_deck() -> void:
	var path := "user://decks/third_pass_sb_probe.deck"
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(DeckStore.USER_DIR))
	var file := FileAccess.open(path, FileAccess.WRITE)
	# A maindeck that offends nothing, and a sideboard that does.
	file.store_string("name: SB Probe\n4 Grizzly Bears\n20 Forest\n"
		+ "SB: 1 Contract from Below\n")
	file.close()
	var listed := DeckList.load_file(path, true)
	assert_eq(listed.errors, [], "the probe deck parses")
	assert_eq(DeckFormat.legal(listed.cards, DeckFormat.TOURNAMENT_T15), "",
		"its MAINDECK is legal — this is what used to be all that was asked")
	# The picker was filled when the screen was built, so the row is added
	# by hand rather than rebuilding the screen — a row IS its metadata
	# path (`_fill_deck_options`), which is what `_refresh_format_note`
	# reads.
	var picker: OptionButton = _deck_pickers()[0]
	picker.add_item("SB Probe")
	picker.set_item_metadata(picker.item_count - 1, path)
	picker.select(picker.item_count - 1)
	screen._format_option.select(DeckFormat.ORDER.find(DeckFormat.TOURNAMENT_T15))
	screen._refresh_format_note()
	assert_true(screen._format_note.text.contains("Contract from Below"),
		"the banned card cannot hide in the sideboard")
	assert_true(screen._format_note.text.contains("sideboard"),
		"and the note says where it is")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_a_random_seat_is_not_judged_before_its_deck_exists() -> void:
	_deck_pickers()[0].select(0)          # <random deck>
	screen._format_option.select(DeckFormat.ORDER.find(DeckFormat.HIGHLANDER))
	screen._refresh_format_note()
	assert_false(screen._format_note.text.contains("Seat 1"),
		"nothing to check until the seed picks a deck")


# ========================================= the match parameters (item 4) ==

func test_the_match_row_offers_free_play_and_every_length() -> void:
	assert_true(screen._free_play.button_pressed, "free play is the default")
	assert_eq(screen._best_of_option.item_count, MatchState.LENGTHS.size())
	for i in MatchState.LENGTHS.size():
		assert_eq(screen._best_of_option.get_item_text(i),
			str(MatchState.LENGTHS[i]))
	# `Best of &One` put a 1 at the head of LENGTHS (docs/duel-todo.md
	# §6.21); the list still OPENS on three, which is what `&Best of:` has
	# always meant here and the first length the record sentence narrates.
	assert_eq(screen._best_of_option.get_item_text(
		screen._best_of_option.selected), "3")


func test_free_play_greys_the_length_and_the_sideboard_step() -> void:
	screen._free_play.button_pressed = true
	screen._apply_match_mode()
	assert_true(screen._best_of_option.disabled)
	assert_true(screen._sideboard_check.disabled,
		"there is no 'between duels' in a single duel")
	screen._best_of_check.button_pressed = true
	screen._apply_match_mode()
	assert_false(screen._best_of_option.disabled)
	assert_false(screen._sideboard_check.disabled)


# ============================= THE PROXY BOUNDARY (2026-09-01) ==
# THIS SCREEN IS A DOOR INTO A DUEL, and a deck holding [ProxyCard]s must
# not get through it. A proxy has no rules behind it: one that reached
# [MtgGame] would be a name `_build_library` cannot resolve, so it would
# push_error and SKIP it and the seat would be dealt a library quietly
# short of cards — silent nonsense rather than a crash, which is worse.
#
# The screen refuses it twice — live, on the note under the picker, and
# again on `Go!` — and `<random deck>` never draws one. All three are
# below, and each would fail if the gate it names were removed.

const NOT_A_CARD := "Zzz Notional Behemoth"
const PROXY_DECK := "user://decks/_gut_proxy_seat.deck"


func _write_proxy_deck() -> String:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(DeckStore.USER_DIR))
	var file := FileAccess.open(PROXY_DECK, FileAccess.WRITE)
	file.store_string("name: Proxy Seat\n36 Mountain\n4 %s\n" % NOT_A_CARD)
	file.close()
	return PROXY_DECK


func _drop_proxy_deck() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROXY_DECK))


## Point seat [param pid] at [param path] the way `_fill_deck_options`
## does — a row IS its metadata path — without rebuilding the screen.
func _select_path(pid: int, path: String) -> void:
	var picker: OptionButton = _deck_pickers()[pid]
	picker.add_item("Proxy Seat")
	picker.set_item_metadata(picker.item_count - 1, path)
	picker.select(picker.item_count - 1)


func test_the_note_refuses_a_deck_of_proxies_and_names_them() -> void:
	var path := _write_proxy_deck()
	_select_path(0, path)
	screen._refresh_format_note()
	assert_true(screen._format_note.text.contains(NOT_A_CARD),
		"the note names the card that has to be replaced")
	assert_true(screen._format_note.text.contains("Seat 1"),
		"and says which seat")
	assert_true(screen._format_note.text.contains("cannot be played"))
	_drop_proxy_deck()


func test_go_refuses_a_deck_of_proxies_before_a_duel_exists() -> void:
	# THE TEST THAT MATTERS. If this gate were removed, `_start_battle`
	# would build a DuelConfig out of a strict load — which SILENTLY DROPS
	# the names it cannot resolve — and hand a seat a 36-card library it
	# never asked for.
	var path := _write_proxy_deck()
	_select_path(0, path)
	var before := get_tree().current_scene
	screen._start_battle()
	assert_eq(get_tree().current_scene, before, "no duel was started")
	assert_true(is_instance_valid(screen), "the setup screen is still here")
	_drop_proxy_deck()


func test_go_pressed_twice_in_one_frame_starts_one_duel() -> void:
	# `queue_free()` defers, so the screen is still here for the rest of
	# the frame after a successful Go!; a second press — a double-click, a
	# held Return — used to build a second duel under `root` and orphan
	# the first, still running. The guard is the first line of
	# `_start_battle`, before any refusal: a leaving screen is deaf.
	var path := _write_proxy_deck()
	_select_path(0, path)
	screen._leaving = true
	var popups_before := screen.get_child_count()
	screen._start_battle()
	assert_eq(screen.get_child_count(), popups_before,
		"not even the proxy refusal is raised once the screen is leaving")
	assert_true(is_instance_valid(screen))
	_drop_proxy_deck()


const BROKEN_DECK := "user://decks/_gut_broken_seat.deck"


func _write_broken_deck() -> String:
	# Not proxies and not an illegal format — just a file the parser
	# cannot read a single card out of. `ProxyCard.refusal_for([], [])` is
	# "" and `DeckFormat.legal([], ...)` is "" (no format has a minimum
	# size), so nothing else in `_start_battle` stops it.
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(DeckStore.USER_DIR))
	var file := FileAccess.open(BROKEN_DECK, FileAccess.WRITE)
	file.store_string("name: Broken Seat\nzero Mountain\n")
	file.close()
	return BROKEN_DECK


func test_go_refuses_a_deck_the_parser_could_not_read() -> void:
	# THE BUG THIS PINS: `_start_battle` loaded each deck strictly and then
	# never looked at `deck.errors`. A file the parser could read nothing
	# out of — a deck deleted between the scan and Go!, or `<random deck>`
	# with an empty playable pool, which resolves to the path "" — handed
	# the seat `cards == []` and started the duel anyway, with an EMPTY
	# library. The proxy gate above cannot catch it: there are no names to
	# call proxies.
	var path := _write_broken_deck()
	var listed := DeckList.load_file(path, true)
	assert_false(listed.errors.is_empty(), "the parser does report it")
	assert_eq(listed.cards, [] as Array[String], "and yields no cards")
	_select_path(0, path)
	var before := get_tree().current_scene
	screen._start_battle()
	assert_eq(get_tree().current_scene, before, "no duel was started")
	assert_true(is_instance_valid(screen), "the setup screen is still here")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BROKEN_DECK))


func test_go_refuses_a_seat_with_no_deck_file_at_all() -> void:
	# The `<random deck>` shape of the same hole: an empty playable pool
	# makes `random_deck_path` return "", and `DeckList.load_file("")`
	# reports "cannot open ''" with no cards.
	_select_path(0, "user://decks/_gut_no_such_file.deck")
	var before := get_tree().current_scene
	screen._start_battle()
	assert_eq(get_tree().current_scene, before, "no duel was started")
	assert_true(is_instance_valid(screen))


func test_the_ai_opponent_is_hal_and_the_player_may_rename_it() -> void:
	# The seat used to be LOCKED and labelled with its skill — "AI Wizard"
	# — which froze if the skill changed and then lied about which pilot
	# the duel would get. Both halves are gone (owner's ask, 2026-09-03):
	# every seat is nameable, and an unnamed AI is HAL, which claims no
	# skill and so cannot misdescribe one.
	screen._apply_mode(SetupScreen.BattleMode.VS_AI)
	await get_tree().process_frame
	assert_eq(screen._name_edits[1].text, "HAL 9000")
	assert_true(screen._name_edits[1].editable, "and it can be typed over")
	# A skill change leaves the name alone now.
	screen._difficulty_options[1].select(0)
	screen._difficulty_options[1].item_selected.emit(0)
	assert_eq(screen._name_edits[1].text, "HAL 9000")


func test_a_demo_seats_hal_9000_against_its_sequel() -> void:
	screen._apply_mode(SetupScreen.BattleMode.DEMO)
	await get_tree().process_frame
	assert_eq([screen._name_edits[0].text, screen._name_edits[1].text],
		["HAL 9000", "HAL 9001"])


func test_a_name_the_player_typed_survives_every_mode_change() -> void:
	screen._apply_mode(SetupScreen.BattleMode.VS_AI)
	await get_tree().process_frame
	screen._name_edits[1].text = "Deep Thought"
	for mode in [SetupScreen.BattleMode.DEMO, SetupScreen.BattleMode.HOTSEAT,
			SetupScreen.BattleMode.VS_AI]:
		screen._apply_mode(mode)
		await get_tree().process_frame
		assert_eq(screen._name_edits[1].text, "Deep Thought",
			"the screen never overwrites a name it did not write")


func test_the_name_the_player_gave_the_ai_is_the_name_in_the_duel() -> void:
	# `_start_battle` copies the field straight into DuelConfig, so the
	# field IS the duel's name for that seat — which is the whole point of
	# letting a player type it.
	screen._apply_mode(SetupScreen.BattleMode.VS_AI)
	await get_tree().process_frame
	screen._name_edits[1].text = "HAL 9000½"
	var config := DuelConfig.new()
	for pid in 2:
		config.player_names[pid] = screen._name_edits[pid].text
	assert_eq(config.player_names[1], "HAL 9000½")
	assert_eq(config.player_names[0], "Player 1", "and the human keeps theirs")


func test_the_difficulty_and_sideboard_switches_explain_themselves() -> void:
	# A player finds out what the four levels DO, and that the sideboard
	# box governs the AI seats too, without leaving the screen — and the
	# tooltips name the Deck Lab flags that are the same switches, so a
	# tester reads one description (DeckLab/README.md, "The switches").
	var tip: String = screen._difficulty_options[1].tooltip_text
	for level in SetupScreen.DIFFICULTIES:
		assert_true(tip.contains(level + ":"), "the tooltip explains %s" % level)
	assert_true(tip.contains("--profile-a"), "names the Lab flag")
	assert_true(tip.contains("never sideboards"), "the Apprentice's honest gap")
	var side: String = screen._sideboard_check.tooltip_text
	assert_true(side.contains("AI seats sideboard too"), "governs the AI seats")
	assert_true(side.contains("--sideboard on|off"), "names the Lab flag")


func test_a_shipped_deck_cannot_declare_itself_user_created() -> void:
	# DeckGroups' class doc: USER "is DERIVED, never declared. A deck in
	# `user://decks` is the player's, full stop." `declared_in` walked
	# ORDER, which holds USER because ORDER is the DISPLAY order — so a
	# shipped file could type the heading into itself and be filed under
	# the player's own.
	assert_eq(DeckGroups.declared_in("# group: %s\n" % DeckGroups.USER), "",
		"USER is not declarable")
	assert_eq(DeckGroups.declared_in("# group: %s\n" % DeckGroups.ORIGINALS),
		DeckGroups.ORIGINALS, "the declarable groups still declare")
	assert_eq(DeckGroups.raw_in("# group: %s\n" % DeckGroups.USER),
		DeckGroups.USER,
		"but the line is still carried through a load-and-save untouched")


func test_go_still_starts_a_duel_when_both_decks_are_real() -> void:
	# The other half of the gate: it must refuse proxies and nothing else.
	# Checked through the same lenient read `_start_battle` makes, rather
	# than by starting a duel and having to tear it down.
	for path in DeckStore.deck_paths_in(DeckStore.SHIPPED_DIR):
		var listed := DeckList.load_file(path, false)
		assert_eq(ProxyCard.refusal_for(listed.cards, listed.sideboard), "",
			"%s passes the gate" % path.get_file())


func test_random_deck_never_draws_a_deck_it_would_refuse() -> void:
	# A seed that could hand a seat an unplayable deck is a seed that
	# cannot start a duel, which is not a choice worth offering.
	var rng := RandomNumberGenerator.new()
	for seed_value in range(1, 40):
		rng.seed = seed_value
		var path := SetupScreen.random_deck_path(screen._playable_paths, rng)
		if path == "":
			continue
		var listed := DeckList.load_file(path, false)
		assert_eq(ProxyCard.refusal_for(listed.cards, listed.sideboard), "",
			"seed %d drew a playable deck" % seed_value)


func test_a_deck_of_proxies_is_listed_rather_than_hidden() -> void:
	# A deck the player built and saved that silently vanished from this
	# list would be a mystery. It is listed, marked, and refused with its
	# reasons the moment it is chosen.
	var path := _write_proxy_deck()
	var fresh: SetupScreen = load("res://game/setup_screen.tscn").instantiate()
	add_child_autofree(fresh)
	await get_tree().process_frame
	assert_true(fresh._deck_paths.has(path), "it is in the list")
	assert_false(fresh._playable_paths.has(path),
		"...but never in the random pool")
	var marked := false
	var picker: OptionButton = fresh._deck_options[0]
	for i in picker.item_count:
		if str(picker.get_item_metadata(i)) == path:
			marked = picker.get_item_text(i).contains("proxy")
			assert_true(picker.get_item_tooltip(i).contains(NOT_A_CARD),
				"and its tooltip names the card")
	assert_true(marked, "the row says the deck holds proxies")
	_drop_proxy_deck()


## THE SCREEN HAS TO FIT THE WINDOW IT SHIPS WITH.
##
## Godot's OptionButton defaults to `fit_to_longest_item = true`: its
## minimum width is the width of the WIDEST ROW IT HOLDS, not the row
## showing. That was harmless while the picker held five starter decks.
## The 2026-09-02 port put 318 decks in it, the longest of them 71
## characters ("Menendian — Eternal Weekend 2016 Old School finalist (UR
## Aggro-Control)"), and that one row pushed the seat column, the panel
## and the whole screen past the edge of the window: the 2026-09-03
## playtest of the exported build saw the left-hand labels cut off
## ("ckground:", "tricted") and the seat-2 rows running off the right.
##
## The list is a LIST — a long name belongs in the popup, not in the
## button's minimum size.
func test_the_deck_picker_does_not_size_itself_to_its_longest_deck_name() -> void:
	for picker in _deck_pickers():
		assert_false((picker as OptionButton).fit_to_longest_item,
			"a 71-character deck name must not set the button's width")
		assert_true((picker as OptionButton).clip_text,
			"and what does not fit is clipped, not overflowed")


func test_no_panel_on_this_screen_is_wider_than_the_shipped_window() -> void:
	# The screen root is anchored, not laid out, so its own minimum size
	# says nothing; what overflows is the widest PANEL in it.
	var width: float = ProjectSettings.get_setting(
		"display/window/size/viewport_width", 1280)
	var widest := 0.0
	var worst := ""
	var stack: Array = [screen]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is Container and node.get_combined_minimum_size().x > widest:
			widest = (node as Container).get_combined_minimum_size().x
			worst = node.name
	assert_lt(widest, width,
		"the widest thing on the setup screen (%s) must fit the window "
		% worst + "this project ships with")


func test_a_human_seat_shows_no_ai_difficulty_label_over_the_gap() -> void:
	# The picker was hidden for a human seat and its label was not, so
	# "AI difficulty:" stood over nothing (2026-09-03 playtest shots).
	screen._apply_mode(SetupScreen.BattleMode.VS_AI)
	await get_tree().process_frame
	assert_false(screen._difficulty_labels[0].visible, "seat 1 is the human")
	assert_eq(screen._difficulty_labels[0].visible,
		screen._difficulty_options[0].visible, "label and picker agree")
	assert_true(screen._difficulty_labels[1].visible, "seat 2 is the AI")
	screen._apply_mode(SetupScreen.BattleMode.HOTSEAT)
	await get_tree().process_frame
	for pid in 2:
		assert_false(screen._difficulty_labels[pid].visible,
			"two humans, no difficulty anywhere")


func test_the_settings_panel_sits_in_the_middle_of_the_screen() -> void:
	# It did not. PANEL_WIDTH was used AS the width, the seat boxes ask
	# for more than that, and a control with room on one side only grows
	# that way — so the panel sat against the right edge with the backdrop
	# showing down the left (2026-09-03 playtest). Measured as margins,
	# because that is what the eye actually compares.
	screen.size = Vector2(1280, 800)
	screen._fit_panel()
	await get_tree().process_frame
	var panel: Control = screen._panel
	var left := panel.global_position.x
	var right := screen.size.x - (panel.global_position.x + panel.size.x)
	assert_almost_eq(left, right, 2.0,
		"equal air on both sides: %.0f vs %.0f" % [left, right])
	assert_gt(panel.size.x, SetupScreen.PANEL_WIDTH - 1.0,
		"and the width is the content's, never less than the floor")
	assert_lt(panel.size.x, screen.size.x,
		"and never wider than the window")


# ------------------------------------------- the seat's own portrait --

## THE DUELIST IS DERIVED, THE PORTRAIT IS CHOSEN. The face above a seat
## comes from the deck's dominant colour, the way the original picked it;
## the one under it is the player's own, and these pin the three things
## that make it a choice rather than a decoration: the arrows move it, the
## choice is stored BY ID (so new art cannot shuffle it), and a machine
## with no portrait art says so instead of showing an empty frame.

const PORTRAIT_DIR := "user://portraits"

var _portrait_files: Array[String] = []


func _drop_portrait(name: String) -> void:
	PortraitLibrary.ensure_folder()
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.3, 0.2, 0.5))
	var path := PORTRAIT_DIR.path_join(name)
	image.save_png(ProjectSettings.globalize_path(path))
	_portrait_files.append(path)
	PortraitLibrary.refresh()


## Only the player's folder is searched while these run, so the 1997
## faces an imported skin may hold cannot decide the outcome (the seam is
## PortraitLibrary.dirs). Restored by [method _restore_portraits].
func _only_the_players_folder() -> void:
	PortraitLibrary.dirs = [PORTRAIT_DIR]
	PortraitLibrary.refresh()


func _no_portraits_at_all() -> void:
	PortraitLibrary.dirs = ["user://portraits_that_are_not_there"]
	PortraitLibrary.refresh()


func _restore_portraits() -> void:
	PortraitLibrary.dirs = PortraitLibrary.DEFAULT_DIRS.duplicate()
	PortraitLibrary.refresh()


func _clean_portraits() -> void:
	for path in _portrait_files:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_portrait_files = []
	_restore_portraits()
	for pid in 2:
		Settings.clear_value(SetupScreen.PORTRAIT_KEY % pid)


func test_with_no_portrait_art_the_chooser_says_so_and_does_nothing() -> void:
	_clean_portraits()
	_no_portraits_at_all()
	screen._update_portrait(0)
	assert_eq(screen._portrait_captions[0].text, SetupScreen.NO_PORTRAITS)
	assert_null(screen._portrait_rects[0].texture)
	for arrow in screen._portrait_arrows[0]:
		assert_true((arrow as Button).disabled, "an arrow with nowhere to go")
	_restore_portraits()


func test_the_arrows_walk_the_portraits_and_wrap() -> void:
	_clean_portraits()
	_only_the_players_folder()
	_drop_portrait("alpha_mage.png")
	_drop_portrait("beta_mage.png")
	screen._update_portrait(0)
	var first := screen._portrait_captions[0].text
	screen._cycle_portrait(0, 1)
	var second := screen._portrait_captions[0].text
	assert_ne(first, second, "the arrow moved it")
	screen._cycle_portrait(0, 1)
	assert_eq(screen._portrait_captions[0].text, first, "and it wraps")
	assert_not_null(screen._portrait_rects[0].texture, "with art to show")
	_clean_portraits()


func test_the_choice_is_remembered_by_id_not_by_index() -> void:
	# A portrait dropped in later sorts before the chosen one; the seat
	# must still wear the face it was given, which an index would not.
	_clean_portraits()
	_only_the_players_folder()
	_drop_portrait("beta_mage.png")
	screen._update_portrait(0)
	screen._cycle_portrait(0, 1)
	var chosen := screen._portrait_captions[0].text
	assert_eq(String(Settings.get_value(SetupScreen.PORTRAIT_KEY % 0, "")),
		"beta_mage", "stored by id")
	_drop_portrait("alpha_mage.png")
	screen._update_portrait(0)
	assert_eq(screen._portrait_captions[0].text, chosen,
		"new art does not repaint a seat that already chose")
	_clean_portraits()


func test_each_seat_keeps_its_own_portrait() -> void:
	_clean_portraits()
	_only_the_players_folder()
	_drop_portrait("alpha_mage.png")
	_drop_portrait("beta_mage.png")
	for pid in 2:
		screen._update_portrait(pid)
	screen._cycle_portrait(1, 1)
	assert_ne(screen._portrait_captions[0].text,
		screen._portrait_captions[1].text, "two seats, two faces")
	_clean_portraits()


func test_the_deck_color_row_says_which_colour_that_is() -> void:
	# `Deck color` is the shipped default and always did the work — your
	# half of the table takes your deck's dominant colour. What it did not
	# do was SAY so, so the answer looked missing (asked 2026-09-03).
	var row := DuelOptions.TERRITORY_COLORS.find(DuelOptions.DECK_COLOR)
	assert_gt(row, -1, "the entry exists")
	for pick in ["decks/big_green.deck", "decks/black_red_raiders.deck"]:
		for i in screen._deck_options[0].item_count:
			if str(screen._deck_options[0].get_item_metadata(i)).ends_with(pick):
				screen._deck_options[0].select(i)
				screen._deck_options[0].item_selected.emit(i)
				break
		await get_tree().process_frame
		var shown := screen._territory_color.get_item_text(row)
		assert_string_contains(shown, DuelOptions.DECK_COLOR)
		var path: String = "res://" + pick
		assert_string_contains(shown,
			DuelConfig.dominant_color(DeckList.load_file(path, true).cards),
			"%s: the row names the colour it will use" % pick.get_file())


func test_naming_the_colour_does_not_change_what_is_stored() -> void:
	# The label is text; the VALUE is still "Deck color", or a saved
	# preference would silently harden into one colour.
	Settings.clear_value("PlayerTerritoryColor")
	screen._update_territory_preview()
	var row := DuelOptions.TERRITORY_COLORS.find(DuelOptions.DECK_COLOR)
	screen._territory_color.select(row)
	screen._territory_color.item_selected.emit(row)
	assert_eq(DuelOptions.territory_color(), DuelOptions.DECK_COLOR)
	assert_eq(DuelOptions.ground_color_for(0, 0, "green"), "green",
		"and it still means: follow whatever deck I bring")
	Settings.clear_value("PlayerTerritoryColor")
	# The preview rebuilds its ground on every change; let the freed ones
	# actually go before GUT counts orphans.
	await get_tree().process_frame


# ------------------------------------------- the pooled random draw --
#
# *"I want to play against AI random decks but only from the 1997
# original game, nothing else."* (playtest, 2026-09-05)
#
# The pool is a GROUP, and the row that names it sits under that group's
# own heading — see [constant SetupScreen.GROUP_RANDOM]. These tests hold
# the three properties the feature is worth nothing without: the draw
# never leaves the pool, it is still a function of the seed, and a pooled
# row is not mistaken for a deck by anything that counts decks.


func _pooled_rows(option: OptionButton) -> Array[String]:
	var out: Array[String] = []
	for i in option.item_count:
		var meta := str(option.get_item_metadata(i))
		if meta.begins_with(SetupScreen.GROUP_RANDOM):
			out.append(meta.substr(SetupScreen.GROUP_RANDOM.length()))
	return out


func test_the_1997_originals_can_be_drawn_from_alone() -> void:
	var groups := _pooled_rows(screen._deck_options[1])
	assert_true(groups.has(DeckGroups.ORIGINALS),
		"the owner's own case: a pooled draw over the 1997 decks")


func test_a_pooled_draw_never_leaves_its_group() -> void:
	for group in _pooled_rows(screen._deck_options[1]):
		var pool := SetupScreen.paths_in_group(screen._playable_paths, group)
		assert_gt(pool.size(), 1, "%s is a real choice" % group)
		# Every seed, not a sample: a draw that escapes its pool once is
		# the whole feature broken, and the pool is small enough to sweep.
		var rng := RandomNumberGenerator.new()
		for seed_value in range(200):
			rng.seed = seed_value
			var drawn := SetupScreen.random_deck_path(pool, rng)
			assert_true(pool.has(drawn),
				"seed %d drew %s, which is not in %s"
					% [seed_value, drawn, group])
			assert_eq(DeckGroups.of(drawn), group,
				"…and it really is filed there")


func test_the_pooled_draw_is_still_a_function_of_the_seed() -> void:
	# The whole screen's promise — "the same seed replays the same duel" —
	# has to survive the narrower bag, or a logged seed stops reproducing.
	var pool := SetupScreen.paths_in_group(screen._playable_paths,
		DeckGroups.ORIGINALS)
	var first: Array[String] = []
	var again: Array[String] = []
	for run in [first, again]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242
		for _i in range(12):
			run.append(SetupScreen.random_deck_path(pool, rng))
	assert_eq(first, again, "same seed, same twelve decks")


func test_a_pooled_row_is_not_counted_as_a_deck() -> void:
	# `_row_of_deck` picks the nth DECK, skipping the random row and the
	# headings. A pooled row carries metadata, so unlike `<random deck>`
	# it would have looked like a deck to anything testing for emptiness.
	var option: OptionButton = screen._deck_options[0]
	for nth in range(6):
		var row := SetupScreen._row_of_deck(option, nth)
		var meta := str(option.get_item_metadata(row))
		assert_false(meta.begins_with(SetupScreen.GROUP_RANDOM),
			"row %d is a deck, not a pool" % nth)
		assert_false(option.is_item_separator(row), "…nor a heading")
		assert_ne(meta, "", "…nor <random deck>")


func test_a_group_with_one_playable_deck_offers_no_pool() -> void:
	# A bag with one ball is not a draw, and a bag with none would fall
	# through to the whole pool — the opposite of what the row promises.
	for group in _pooled_rows(screen._deck_options[1]):
		assert_gt(SetupScreen.paths_in_group(
			screen._playable_paths, group).size(), 1,
			"%s would not have been worth offering" % group)


# ------------------------------------- the shell's bed carries in here --
#
# *"The magic battle GUI menu should have also the same music as main
# menu."* (playtest, 2026-09-05)
#
# Magic Battle is the title screen's next room — reached by a button on
# the shell, left again with `Back` — so falling silent on the way in made
# the menu music read as a title jingle rather than as the front of the
# game.


func test_it_plays_the_shells_own_bed_and_not_a_bed_of_its_own() -> void:
	# THE REQUIREMENT IS A COUPLING, so it is tested as one: whatever the
	# title screen ends up playing, this screen plays the same thing. That
	# holds on a machine with the 1997 music imported and on one without
	# (where both are silent), and it is what would actually break if
	# somebody gave this screen a bed list of its own.
	assert_not_null(screen._music, "the screen holds its own player")
	var shell: MainScreen = load("res://game/main.tscn").instantiate()
	add_child_autofree(shell)
	await get_tree().process_frame
	screen._apply_music_switch()
	shell._apply_music_switch()
	assert_eq(screen._music.tracks, shell._music.tracks,
		"the setup screen plays exactly what the title screen plays")
	# And it is the shell's LIST it read, not a copy that could drift.
	assert_gt(MainScreen.MENU_BEDS.size(), 0, "the shell declares the beds")


func test_the_global_switch_silences_it() -> void:
	# The shell's rule exactly: the global `music_enabled` key decides.
	# The Deck Builder's own screen-scoped switch is that screen's and
	# must not reach this one.
	var had := Settings.has_value("music_enabled")
	var saved: Variant = Settings.get_value("music_enabled", true)
	Settings.set_value("music_enabled", false)
	screen._apply_music_switch()
	assert_eq(screen._music.tracks.size(), 0, "off means silent")
	Settings.set_value("music_enabled", true)
	screen._apply_music_switch()
	if had:
		Settings.set_value("music_enabled", saved)
	else:
		Settings.clear_value("music_enabled")


func test_leaving_stops_it() -> void:
	# So the duel starts against silence and the PCM is dropped rather
	# than carried into the next screen.
	var fresh: SetupScreen = load("res://game/setup_screen.tscn").instantiate()
	add_child(fresh)
	await get_tree().process_frame
	var player: MusicPlayer = fresh._music
	fresh.free()
	assert_true(player == null or not is_instance_valid(player)
		or player.tracks.is_empty(), "the bed does not follow the player out")


func test_both_seats_open_on_a_random_1997_deck() -> void:
	# *"In the Magic Battle menu the default decks should be random from
	# 1997."* (2026-09-06). The screen used to open on the first two decks
	# alphabetically, so a duel started twice was the same duel twice.
	for pid in 2:
		var picker: OptionButton = screen._deck_options[pid]
		var meta := str(picker.get_item_metadata(picker.selected))
		assert_eq(meta, SetupScreen.GROUP_RANDOM + DeckGroups.ORIGINALS,
			"seat %d opens on the pooled 1997 draw" % pid)


func test_the_opening_draw_really_only_yields_1997_decks() -> void:
	# The selection is only worth anything if the pool behind it is right.
	var pool := SetupScreen.paths_in_group(screen._playable_paths,
		DeckGroups.ORIGINALS)
	assert_gt(pool.size(), 1, "there is a pool to draw from")
	var rng := RandomNumberGenerator.new()
	for seed_value in range(100):
		rng.seed = seed_value
		var drawn := SetupScreen.random_deck_path(pool, rng)
		assert_eq(DeckGroups.of(drawn), DeckGroups.ORIGINALS,
			"seed %d drew %s" % [seed_value, drawn])
