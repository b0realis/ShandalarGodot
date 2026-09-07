extends GutTest
## THE HELP SCREEN — the paged reference behind the main menu's Help button
## (`game/help/help_screen.gd`, content in `game/help/help_pages.gd`).
##
## Four things these pin, because each one is a silent failure otherwise:
##
##   1. **Every page renders.** A page whose blocks are malformed would
##      simply come up blank in the real screen; here it fails the suite.
##   2. **Paging cannot run off either end** — by button, by key, or by a
##      caller's arithmetic.
##   3. **The Help button exists, directly above Exit.** Position is the
##      owner's instruction, so position is what is asserted.
##   4. **Every icon entry resolves to a REAL texture.** A broken icon is
##      the one defect this screen cannot survive — its whole job is to
##      show the player the picture beside the words. With the 1997 skin
##      imported, a null texture is a failure, not a fallback.


var screen: HelpScreen


func before_each() -> void:
	screen = load("res://game/help/help_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func _walk(node: Node) -> Array:
	var out: Array = [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out


func _labels_of(node: Node) -> Array:
	var out: Array = []
	for n in _walk(node):
		if n is Label and (n as Label).text != "":
			out.append((n as Label).text)
	return out


# ========================================================== the content ==

func test_there_are_many_pages_and_each_has_a_title_and_blocks() -> void:
	var pages := HelpPages.pages()
	assert_gt(pages.size(), 10, "the owner asked for many pages")
	for i in pages.size():
		var page: Dictionary = pages[i]
		assert_ne(String(page.get("title", "")), "", "page %d has a title" % i)
		var blocks: Array = page.get("blocks", [])
		assert_gt(blocks.size(), 0, "page %d has content" % i)
		for block in blocks:
			assert_true(HelpPages.KINDS.has(String(block.get("kind", ""))),
				"page %d: every block is a known kind" % i)


func test_page_titles_are_unique() -> void:
	# The page indicator says "Page 4 of N"; the title is the only other
	# way to tell one page from another, so two pages may not share one.
	var seen: Array = []
	for page in HelpPages.pages():
		var title := String(page["title"])
		assert_false(seen.has(title), "'%s' appears once" % title)
		seen.append(title)


func test_every_quote_carries_its_source() -> void:
	# The house rule for this screen: a sentence in quotation marks is the
	# 1997 manual's or `Duel.hlp`'s, and it names where it came from.
	for page in HelpPages.pages():
		for block in page["blocks"]:
			if String(block.get("kind", "")) != HelpPages.QUOTE:
				continue
			assert_ne(String(block.get("text", "")), "", "the quotation")
			assert_ne(String(block.get("cite", "")), "",
				"'%s...' cites its source" % String(block["text"]).substr(0, 40))


func test_the_reference_covers_the_five_colors_and_colorless() -> void:
	var text := HelpPages.all_text()
	# American spelling throughout the user-facing text, as the original's
	# own string tables and our Color Filters already spell it.
	for word in ["White", "Blue", "Black", "Red", "Green", "colorless"]:
		assert_true(text.contains(word), "the mana types name %s" % word)
	assert_false(HelpPages.all_text().contains("colour"),
		"the original is American — 'color', as Mtg.COLOR_NAMES spells it")


func test_the_reference_covers_the_six_phases_by_their_1997_names() -> void:
	# Manual p.60: "1) Untap 2) Upkeep 3) Draw 4) Main 5) Discard
	# 6) Cleanup" — and Main's three parts (pp.62-63).
	var text := HelpPages.all_text()
	for phase in ["Untap", "Upkeep", "Draw", "Main", "Discard", "Cleanup",
			"Pre-Combat", "Post-Combat"]:
		assert_true(text.contains(phase), "the turn page names %s" % phase)


func test_the_reference_never_promises_a_rule_the_engine_lacks() -> void:
	# docs/glossary-1997.md §5 forbids the word "interrupt" outright: the
	# engine has no such timing tier, so using it would promise timing we
	# do not implement. The help screen is user-facing text and is exactly
	# where that rule matters most.
	var text := HelpPages.all_text().to_lower()
	assert_false(text.contains("interrupt"),
		"no interrupts — glossary-1997.md §5")


# ============================================================ the icons ==

func test_the_screen_does_not_teach_a_mark_the_card_no_longer_wears() -> void:
	# **THE HELP SCREEN IS WHERE A PLAYER GOES TO LEARN THIS VOCABULARY**,
	# so a mark it names had better exist. `MiniCard._refresh_status`
	# deleted the `+N aura` CHIP in the forty-first pass — *"NO `+N aura`
	# CHIP HERE ANY MORE"* — when the aura peek replaced it, and this page
	# went on teaching it for two passes (`docs/card-states.md` §5.3).
	assert_false(HelpPages.all_text().contains("+N aura"),
		"the +N aura chip was removed from the small card")
	var taught := ""
	for entry in HelpPages.icon_entries():
		var body := String(entry.get("text", ""))
		assert_false(body.contains("How many enchantments are attached"),
			"'%s' still counts auras in a chip" % String(entry.get("name", "")))
		if String(entry.get("name", "")).to_lower().contains("aura"):
			taught = body
	assert_ne(taught, "", "the aura peek is on the small-card icon page")
	assert_true(taught.contains("WHOLE card"),
		"and it is taught as what it is: a whole card behind the host")


func test_the_icon_pages_carry_a_substantial_inventory() -> void:
	var entries := HelpPages.icon_entries()
	assert_gt(entries.size(), 40,
		"every icon in the duel and the deck builder, each explained")


func test_every_icon_entry_is_named_and_explained() -> void:
	for entry in HelpPages.icon_entries():
		assert_ne(String(entry.get("name", "")), "", "an icon entry is named")
		assert_gt(String(entry.get("text", "")).length(), 12,
			"'%s' is explained, not just labelled" % String(entry.get("name", "")))
		assert_ne(String(entry.get("alt", "")), "",
			"'%s' has a no-skin stand-in" % String(entry.get("name", "")))


func test_every_icon_entry_resolves_to_a_real_texture() -> void:
	# THE ONE THAT MUST NOT BE SKIPPED WHEN THE ART IS THERE. A cell index
	# off by one, a renamed skin key, a sheet that changed size on
	# re-import — all of them land here as a null texture, and a help
	# screen with a hole where an icon should be is worse than none.
	if not GameSkin.is_present():
		pass_test("no 1997 skin imported — the alt strings are the render")
		return
	for entry in HelpPages.icon_entries():
		var spec: Dictionary = entry.get("icon", {})
		if String(spec.get("src", "")) == HelpPages.SRC_DRAWN:
			continue     # code-drawn marks (the Stop dot, the count badge)
		var texture := HelpPages.icon_texture(spec)
		assert_not_null(texture,
			"'%s' resolves (%s)" % [String(entry.get("name", "")), spec])
		if texture != null:
			assert_gt(texture.get_width(), 0, String(entry.get("name", "")))
			assert_gt(texture.get_height(), 0, String(entry.get("name", "")))


func test_an_unknown_icon_source_resolves_to_null_rather_than_erroring() -> void:
	assert_null(HelpPages.icon_texture({"src": "no_such_source"}))
	assert_null(HelpPages.icon_texture({}))


func test_the_duel_icons_match_the_screens_that_draw_them() -> void:
	# The inventory is taken FROM THE CODE, so it has to stay tied to it:
	# these are the exact tables the duel screen renders from.
	var text := HelpPages.all_text()
	for cue in PhaseBar.CUE_YOURS:
		assert_true(text.contains(cue), "the Phase Bar page carries: %s" % cue)
	for cue in CombatBar.TOOLTIPS:
		assert_true(text.contains(cue), "the Combat Bar page carries: %s" % cue)


func test_the_badge_icons_are_the_ones_the_mini_card_actually_draws() -> void:
	# MiniCard.BADGE_SLOT, PROTECTION_SLOT and the two slots that sit
	# outside both dicts — REGENERATION (there is no keyword for it) and
	# ARTIFACT_PROTECTION (cur_protection is a colour bitmask) — are the
	# whole set of ability marks a player can meet on a card in play. The
	# reference explains each of them and invents none.
	var shown: Array = []
	for entry in HelpPages.icon_entries():
		var spec: Dictionary = entry.get("icon", {})
		if String(spec.get("src", "")) == HelpPages.SRC_BADGE:
			shown.append(int(spec["slot"]))
	for keyword in MiniCard.BADGE_SLOT:
		assert_true(shown.has(int(MiniCard.BADGE_SLOT[keyword])),
			"badge slot %d explained" % MiniCard.BADGE_SLOT[keyword])
	for color in MiniCard.PROTECTION_SLOT:
		assert_true(shown.has(int(MiniCard.PROTECTION_SLOT[color])),
			"protection slot %d explained" % MiniCard.PROTECTION_SLOT[color])
	assert_true(shown.has(MiniCard.REGENERATION_SLOT), "regeneration (15)")
	assert_true(shown.has(MiniCard.ARTIFACT_PROTECTION_SLOT),
		"protection from artifacts (10)")
	assert_eq(shown.size(), MiniCard.BADGE_SLOT.size()
		+ MiniCard.PROTECTION_SLOT.size() + 2, "and no badge we never draw")
	assert_false(shown.has(17),
		"CELL 17 IS BLANK — 484/484 px of solid black. s30 maps Menace "
		+ "there; the 1997 game had neither the keyword nor the icon.")


func test_every_small_card_state_with_art_is_explained() -> void:
	# `@CUECARD_SMALLCARD`'s ten states are the small card's whole
	# vocabulary. Every one this game can actually draw is on the icon
	# pages, addressed by the same skin key MiniCard draws it with.
	var keys: Array = []
	for entry in HelpPages.icon_entries():
		var spec: Dictionary = entry.get("icon", {})
		if String(spec.get("src", "")) == HelpPages.SRC_SPRITE:
			keys.append(String(spec["key"]))
	for state in MiniCard.STATE_SPRITE:
		assert_true(keys.has(String(MiniCard.STATE_SPRITE[state])),
			"state %s ('%s') is explained" % [state, MiniCard.STATE_CUE[state]])


func test_the_deck_builder_filter_icons_are_the_bars_own_cells() -> void:
	var shown: Array = []
	for entry in HelpPages.icon_entries():
		var spec: Dictionary = entry.get("icon", {})
		if String(spec.get("src", "")) == HelpPages.SRC_FILTER:
			shown.append([int(spec["row"]), int(spec["col"])])
	for type_flag in FilterBar.TYPE_CELL:
		assert_true(shown.has(FilterBar.TYPE_CELL[type_flag]),
			"type cell %s explained" % [FilterBar.TYPE_CELL[type_flag]])
	for color in FilterBar.COLOR_CELL:
		assert_true(shown.has(FilterBar.COLOR_CELL[color]),
			"color cell %s explained" % [FilterBar.COLOR_CELL[color]])
	for cell in [FilterBar.GOLD_CELL, FilterBar.COST_CELL,
			FilterBar.POWER_CELL, FilterBar.TOUGHNESS_CELL,
			FilterBar.FUNNEL_CELL, FilterBar.ABILITY_CELL,
			FilterBar.RARITY_CELL, FilterBar.ARTIST_CELL]:
		assert_true(shown.has(cell), "cell %s explained" % [cell])
	for code in FilterBar.SET_CELL:
		assert_true(shown.has(FilterBar.SET_CELL[code]),
			"the %s medallion is explained" % code)


func test_every_mana_symbol_on_the_1997_sheet_is_explained() -> void:
	var shown: Array = []
	for entry in HelpPages.icon_entries():
		var spec: Dictionary = entry.get("icon", {})
		if String(spec.get("src", "")) == HelpPages.SRC_MANA:
			shown.append(String(spec["sym"]))
	for symbol in ["W", "U", "B", "R", "G", "X", "T"]:
		assert_true(shown.has(symbol), "{%s} is explained" % symbol)


# =========================================================== the screen ==

func test_every_page_renders_without_a_blank_body() -> void:
	for i in HelpPages.pages().size():
		screen.go_to(i)
		await get_tree().process_frame
		assert_eq(screen.current_page(), i)
		var labels := _labels_of(screen)
		assert_gt(labels.size(), 2,
			"page %d ('%s') drew something" % [i, HelpPages.pages()[i]["title"]])
		assert_true(labels.has(String(HelpPages.pages()[i]["title"])),
			"page %d shows its title" % i)


func test_the_page_indicator_counts_from_one() -> void:
	screen.go_to(0)
	assert_true(_labels_of(screen).has("Page 1 of %d" % screen.page_count()))
	screen.go_to(screen.page_count() - 1)
	assert_true(_labels_of(screen).has(
		"Page %d of %d" % [screen.page_count(), screen.page_count()]))


func test_paging_cannot_run_off_either_end() -> void:
	screen.go_to(0)
	screen.go_to(-1)
	assert_eq(screen.current_page(), 0, "no page before the first")
	screen.go_to(-999)
	assert_eq(screen.current_page(), 0)
	var last := screen.page_count() - 1
	screen.go_to(last)
	screen.go_to(last + 1)
	assert_eq(screen.current_page(), last, "no page after the last")
	screen.go_to(9999)
	assert_eq(screen.current_page(), last)


func test_the_turn_buttons_grey_out_at_the_ends() -> void:
	screen.go_to(0)
	assert_true(screen._prev_button.disabled, "nothing before page 1")
	assert_false(screen._next_button.disabled)
	screen.go_to(screen.page_count() - 1)
	assert_false(screen._prev_button.disabled)
	assert_true(screen._next_button.disabled, "nothing after the last page")


func test_the_keyboard_turns_pages_and_home_end_jump() -> void:
	screen.go_to(0)
	_press(KEY_RIGHT)
	assert_eq(screen.current_page(), 1, "Right turns forward")
	_press(KEY_PAGEDOWN)
	assert_eq(screen.current_page(), 2, "Page Down does too")
	_press(KEY_LEFT)
	assert_eq(screen.current_page(), 1, "Left turns back")
	_press(KEY_END)
	assert_eq(screen.current_page(), screen.page_count() - 1, "End is the last")
	_press(KEY_HOME)
	assert_eq(screen.current_page(), 0, "Home is the first")
	_press(KEY_LEFT)
	assert_eq(screen.current_page(), 0, "and Left at the first stays put")


func _press(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	screen._input(event)


func test_a_page_of_icons_draws_a_texture_for_each_of_them() -> void:
	if not GameSkin.is_present():
		pass_test("no 1997 skin imported — the alt strings stand in")
		return
	var page := -1
	for i in HelpPages.pages().size():
		for block in HelpPages.pages()[i]["blocks"]:
			if String(block.get("kind", "")) == HelpPages.ICONS:
				page = i
				break
		if page >= 0:
			break
	assert_gt(page, -1, "there is an icon page")
	screen.go_to(page)
	await get_tree().process_frame
	var drawn := 0
	for node in _walk(screen):
		if node is TextureRect and (node as TextureRect).texture != null:
			drawn += 1
	assert_gt(drawn, 2, "the icons are on screen as real art")


func test_the_screen_survives_a_small_window() -> void:
	# canvas_items stretch: 1280x720 is the other shape the panel has to
	# hold. Nothing may be pushed off the bottom.
	screen.size = Vector2(1280, 720)
	screen.go_to(HelpPages.pages().size() - 1)
	await get_tree().process_frame
	assert_lt(screen._scroll.global_position.y + screen._scroll.size.y,
		721.0, "the body stays inside the window")
	assert_gt(screen._scroll.size.y, 200.0, "and still has room to read in")


# ====================================================== the deck formats ==
#
# The owner's addition to item 5: the five formats must be DOCUMENTED, and
# the documentation must match what is actually enforced. A page that
# promises a rule the code does not apply is the one failure this screen
# cannot afford, so these check the page against [DeckFormat] itself
# rather than against a copy of the words.

func _format_pages() -> Array:
	var out: Array = []
	for page in HelpPages.pages():
		if String(page["title"]).begins_with("Deck formats"):
			out.append(page)
	return out


func _all_text(page: Dictionary) -> String:
	var parts := PackedStringArray()
	for block in page.get("blocks", []):
		parts.append(String(block.get("text", "")))
	return "\n".join(parts)


func test_all_five_formats_are_explained_by_their_1997_names() -> void:
	var pages := _format_pages()
	assert_gt(pages.size(), 0, "there is a formats page")
	var text := ""
	for page in pages:
		text += _all_text(page)
	for format in DeckFormat.ORDER:
		assert_true(text.contains(format),
			"'%s' is explained, spelled as 1997 spells it" % format)


func test_the_page_says_which_formats_are_enforced() -> void:
	# Item 5's instruction: the page must match reality. All five ARE
	# enforced, so the page says so — and if that ever stops being true
	# this test is the reminder that the page must change with it.
	var text := ""
	for page in _format_pages():
		text += _all_text(page)
	assert_true(text.to_lower().contains("enforced"),
		"the page states what is checked and what is not")
	for format in DeckFormat.ORDER:
		assert_eq(DeckFormat.legal([], format), "",
			"%s really is implemented, as the page claims" % format)


func test_the_page_names_the_cards_the_rule_can_actually_fire_on() -> void:
	# A restricted card the pool does not have would be an empty promise;
	# every card the page lists as restricted must be BOTH on the list and
	# in the registry.
	var text := ""
	for page in _format_pages():
		text += _all_text(page)
	for card_name in ["Black Lotus", "Ancestral Recall", "Sol Ring",
			"Library of Alexandria"]:
		assert_true(text.contains(card_name), "%s is listed" % card_name)
		assert_true(DeckFormat.RESTRICTED.has(card_name), card_name)
		assert_true(CardRegistry.has_card(card_name),
			"%s is in the pool, so the page is not promising air" % card_name)


func test_the_page_admits_the_lists_are_not_1997s() -> void:
	# Rule 5 of help_pages.gd: anything unconfirmed says so ON THE PAGE.
	# No 1997 restricted list survives, and the page must not pretend one
	# does.
	var text := ""
	for page in _format_pages():
		text += _all_text(page)
	assert_true(text.contains("No 1997 restricted list survives"),
		"the page states the provenance gap plainly")


func test_the_setup_screens_tooltip_says_the_same_thing_as_the_page() -> void:
	# The owner asked for the one-line answer to be available without
	# leaving the setup screen. One source of words, two places.
	var setup: SetupScreen = load("res://game/setup_screen.tscn").instantiate()
	add_child_autofree(setup)
	await get_tree().process_frame
	for i in DeckFormat.ORDER.size():
		var format: String = DeckFormat.ORDER[i]
		assert_eq(setup._format_option.get_item_text(i), format)
		assert_eq(setup._format_option.get_item_tooltip(i),
			String(DeckFormat.SUMMARY[format]),
			"%s's tooltip is its summary" % format)


# ======================================================== the menu entry ==

func test_the_main_menu_has_help_directly_above_exit() -> void:
	assert_true(ResourceLoader.exists("res://game/help/help_screen.tscn"))
	var menu: Control = load("res://game/main.tscn").instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame
	var labels: Array = []
	for node in _walk(menu):
		if node is Button:
			labels.append((node as Button).text)
	assert_true(labels.has("Help"), "the menu offers Help")
	assert_eq(labels.find("Help") + 1, labels.find("Exit"),
		"Help sits directly above Exit (the owner's instruction)")


func test_the_main_menu_wears_our_name_in_the_bottom_left() -> void:
	var menu: Control = load("res://game/main.tscn").instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame
	var wordmark: Label = null
	var version: Label = null
	for node in _walk(menu):
		if node is Label:
			if (node as Label).text == "ShandalarGodot":
				wordmark = node
			elif (node as Label).text.begins_with("v"):
				version = node
	assert_not_null(wordmark, "the ShandalarGodot wordmark exists")
	assert_not_null(version, "beside its twin, the version tag")
	if wordmark == null or version == null:
		return
	# THE COLUMN, not the label: since the 2026-09-03 playtest the wordmark
	# stands ON TOP OF the set badges in one bottom-left stack, so what is
	# anchored is their container. ANCHORS rather than pixels, because
	# `canvas_items` stretch moves the corner with the window and the
	# anchor is what pins it there: bottom left is (0, 1), growing right
	# and up.
	var column := wordmark.get_parent() as Control
	assert_true(column is VBoxContainer, "the wordmark stands in a column")
	assert_eq(Vector2(column.anchor_left, column.anchor_top),
		Vector2(0, 1), "anchored bottom-LEFT")
	assert_eq(column.grow_horizontal, Control.GROW_DIRECTION_END)
	assert_eq(column.grow_vertical, Control.GROW_DIRECTION_BEGIN)
	assert_eq(Vector2(version.anchor_left, version.anchor_top),
		Vector2(1, 1), "and the version tag bottom-RIGHT")
	assert_gt(column.position.x, 0.0, "inset from the left edge")
	assert_lt(column.position.x, 40.0, "but only just")
	# The badges hang UNDER the name — the owner's ask, and the reason the
	# pair moved out of the top-left corner in the first place.
	assert_eq(column.get_child(0), wordmark, "the name leads")
	var badges: Control = column.get_child(1)
	assert_gt(_walk(badges).size(), 1, "the set badges hang under it")
	assert_gt(wordmark.get_theme_font_size("font_size"),
		version.get_theme_font_size("font_size") * 2,
		"and it is a wordmark now, not a second footnote")
	assert_eq(wordmark.get_theme_color("font_color"),
		version.get_theme_color("font_color"),
		"still the same parchment ink: both sit on the title PAINTING, "
		+ "whose bottom third is dark — UiChrome's ink is for the sand")


func test_the_page_no_longer_claims_the_pool_filters_the_list_for_us() -> void:
	# THE CORRECTED CLAIM (2026-09-01). The page used to tell the player
	# that "what the pool leaves standing is the era's own list". That is
	# true only for cards ADDED to the restricted list since 1997; it is
	# false for the eleven REMOVED from it, all of which are in our pool
	# and were going unflagged. A help page that states a rule the code
	# does not follow is worse than one that says nothing.
	var text := ""
	for page in _format_pages():
		text += _all_text(page)
	assert_false(text.contains("What the pool leaves standing is the era's"),
		"the wrong claim is gone")
	assert_true(text.contains("The Duelist #22"),
		"and the page names the source the era list comes from")
	# Every era-restricted card the page lists must be on the list AND in
	# the pool — the same promise the page makes about the modern ones.
	for card_name in ["Braingeyser", "Mind Twist", "Regrowth", "Recall",
			"Black Vise", "Maze of Ith", "Underworld Dreams"]:
		assert_true(text.contains(card_name), "%s is listed" % card_name)
		assert_true(DeckFormat.RESTRICTED.has(card_name), card_name)
		assert_true(CardRegistry.has_card(card_name),
			"%s is in the pool, so the page is not promising air" % card_name)


# ------------------------------------------------- the deck builder page --

func _builder_page() -> Dictionary:
	for page in HelpPages.pages():
		if String(page["title"]) == "The Deck Builder":
			return page
	return {}


## The v0.16.0 update (2026-09-07): the five list filters shipped as the
## pages of one window behind the funnel, and the page that used to say
## three of them were not built had to stop saying so.
func test_the_help_no_longer_says_three_filters_are_missing() -> void:
	var text := HelpPages.all_text()
	assert_false(text.contains("are not built here"), "all five are")
	assert_true(text.contains("Filters window"), "and the window is taught")
	for name in ["Creatures", "Enchantments", "Abilities", "Rarity", "Artists"]:
		assert_true(text.contains(name), "%s page named" % name)
	var bar: FilterBar = autofree(FilterBar.new(DeckFilter.new()))
	for page in bar.window_pages():
		var name := String(page["title"])
		assert_true(text.contains(name), "the window's own '%s' tab" % name)
	# The window's ability names are the 1997 ones with today's beside
	# them; the page must not teach a different pairing.
	var eye := ""
	for entry in HelpPages.icon_entries():
		if String(entry.get("name", "")).begins_with("Abilities"):
			eye = String(entry.get("text", ""))
	assert_ne(eye, "", "the eye is explained")
	for i in DeckAbilities.MODERN:
		var pair := "%s is %s" % [DeckAbilities.LABELS[i], DeckAbilities.MODERN[i]]
		assert_true(eye.contains(pair), pair)


## The page names the screen's commands by the screen's own constants, so
## a command added to the mini-menu without a line here fails this.
func test_the_deck_builder_page_names_every_command_and_key() -> void:
	var page := _builder_page()
	assert_false(page.is_empty(), "there is a Deck Builder page")
	if page.is_empty():
		return
	var text := _all_text(page)
	for label in DeckBuilderScreen.COMMANDS:
		assert_true(text.contains(label), "1997 command '%s'" % label)
	for label in DeckBuilderScreen.MENU_COMMANDS:
		assert_true(text.contains(label), "1997 command '%s'" % label)
	for label in DeckBuilderScreen.EXTRA_COMMANDS:
		assert_true(text.contains(label), "[QoL] command '%s'" % label)
	for label in DeckBuilderScreen.STATS_PAGES:
		assert_true(text.contains(label), "Stats page '%s'" % label)
	for keycode in DeckBuilderScreen.SHORTCUTS:
		var key := "Ctrl+%s" % OS.get_keycode_string(keycode)
		assert_true(text.contains(key), "%s is on the page" % key)
	assert_true(text.contains("Ctrl+F"), "and the type-ahead's own key")
	for line in FilterBar.ALL_MENU:
		assert_true(text.to_lower().contains(line.to_lower()), line)
	assert_true(text.contains("Search card text too"), FilterBar.RULES_LINE)
	for name in FilterBar.SORT_MENU:
		assert_true(text.contains(name), "sort '%s'" % name)


## The owner's question of 2026-09-07 — *"How do we now turn on or off
## the type-ahead filter? It has no button"* — is answered on the page.
func test_the_deck_builder_page_says_how_the_type_ahead_is_cleared() -> void:
	var text := _all_text(_builder_page())
	assert_true(text.contains("no button to switch it on or off"))
	assert_true(text.contains("small cross at its right edge"), "the clear button")
	assert_true(text.contains("Escape"), "and the key")
	assert_true(text.contains("Enter adds the first card shown"))


# --------------------------------------------------- rebuilding a page --

func test_a_page_turn_leaves_only_the_new_pages_blocks() -> void:
	# THE BUG THIS PINS: `_rebuild` called `queue_free()` on the old page's
	# blocks WITHOUT detaching them first. A queued node is still a child
	# until the end of the frame, so for that frame the VBox held BOTH
	# pages, laid out one under the other at double height — and
	# `scroll_vertical = 0` was applied against that. Every other rebuild
	# in this codebase detaches before it frees for exactly this reason.
	screen.go_to(0)
	var first := screen._body.get_child_count()
	assert_gt(first, 0, "page 1 drew something")
	screen.go_to(1)
	var second := screen._body.get_child_count()
	assert_gt(second, 0, "page 2 drew something")
	for child in screen._body.get_children():
		assert_false(child.is_queued_for_deletion(),
			"no leftover from the page we just left")
