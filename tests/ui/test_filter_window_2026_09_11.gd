extends GutTest
## THE FILTER WINDOW AUDIT — 2026-09-11. The owner's report, in their own
## words:
##
## *"The last filter window toggle should update filters in realtime.
## Whatever filters you click in the window should reflect in card-pool in
## the bottom. (For example abilities - you select only first strike and
## only creatures with first strike are below - now it does not work -
## audit it)"*
##
## REPRODUCED HEADLESS BEFORE IT WAS FIXED. The funnel, the Abilities
## page, `Clear All`, `First strike`: the Inventory stood at **897 of
## 897**, because `@ABILITY`, `@RARITY` and `@ARTIST` are each dead
## without their own `Enable Filter` (`@LONGLIST`, Menus.txt:21;
## `check_abilities`, deckdll.cpp:7126) and in 1997 that switch was a
## MEDALLION ON THE STRIP (`CHECK_BUTTON(27, "ABILITY", …, FA_ENABLE)`,
## deckdll.cpp:6653) — a medallion this strip has no room for. The same
## gesture now leaves **25 of 897**.
##
## WHAT IS PINNED HERE:
##
## - the owner's own gesture, through the real window, to the real
##   Inventory — and the one view only the switch can reach (everything
##   ticked, the filter on) still one click away;
## - that a WIDENING tick never presses the switch, so `Select All` keeps
##   meaning "stop narrowing";
## - the realtime path itself: every medallion on the strip, and every
##   kind of line in the window, moves [member DeckFilter.revision] and
##   the Inventory with it;
## - `Select All` / `Clear All` re-listing the Inventory ONCE, not once
##   per row (126 rows on the Creatures page used to be 126 full passes);
## - the three comparison mini-menus: each of `@CASTCOST`'s four modes and
##   `@POWER`/`@TOUGHNESS`'s three doing what the string table says, the
##   number applying, the menu staying open so the number is reachable in
##   the same gesture, and the medallion keeping the comparison over a
##   press;
## - the edges of that number — empty, zero, negative, a word, past the
##   pool — and the `{X}` costs [constant DeckFilter.Cost.HAS_X] exists
##   for;
## - and the 1997 POLARITY and COMBINATION rules, so a later pass cannot
##   quietly invert them.


var screen: DeckBuilderScreen


func before_each() -> void:
	CardRegistry.ensure_loaded()
	screen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


# ------------------------------------------------------------- helpers --

func _walk(node: Node) -> Array:
	var out := [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out


func _funnel() -> Button:
	return screen._filter_bar.group_buttons("Other Filters")[3]


func _window() -> OriginalDialog:
	for dialog in screen.open_dialogs():
		if dialog.has_meta("filter_window"):
			return dialog
	return null


func _menu() -> OriginalDialog:
	for dialog in screen.open_dialogs():
		if dialog.has_meta("filter_menu"):
			return dialog
	return null


func _right_click(button: Button) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	button.gui_input.emit(click)


func _tab(key: String) -> Button:
	var window := _window()
	return window.find_child(key + "Tab", true, false) as Button if window != null else null


## A line of whatever dialog is up, found by what it ends with — the tick
## or the bullet in front of it is the part that changes.
func _line(text: String) -> Button:
	for dialog in screen.open_dialogs():
		for node in _walk(dialog):
			if node is Button and (node as Button).text.ends_with(text):
				return node
	return null


func _lines() -> Array:
	var page: Node = _window().find_child("Page", true, false)
	var out := []
	for node in _walk(page):
		if node is Button and node.visible and (node as Button).text.begins_with("["):
			out.append((node as Button).text)
	return out


func _press(text: String) -> void:
	for dialog in screen.open_dialogs():
		for node in _walk(dialog):
			if node is Button and (node as Button).text == text:
				(node as Button).pressed.emit()
				return
	fail_test("no button reading %s" % text)


func _spin() -> SpinBox:
	for dialog in screen.open_dialogs():
		for node in _walk(dialog):
			if node is SpinBox:
				return node
	return null


func _shown() -> int:
	return screen._inventory.entry_count()


func _names() -> Array[String]:
	var out: Array[String] = []
	for entry in screen._inventory._visible_entries():
		out.append(entry[0].card_name)
	return out


func _open_page(key: String) -> void:
	_funnel().pressed.emit()
	await get_tree().process_frame
	_tab(key).pressed.emit()
	await get_tree().process_frame


# ----------------------------- [1997] the owner's case, end to end --

func test_only_first_strike_leaves_only_the_first_strikers() -> void:
	var whole := _shown()
	assert_eq(whole, CardRegistry.all_names().size(), "the whole pool to begin with")
	await _open_page("Abilities")
	assert_eq(_lines()[0], "[  ] Enable Filter", "the switch is up, as 1997 leaves it")
	_press("Clear All")
	_line("First strike").pressed.emit()
	await get_tree().process_frame
	assert_true(screen.filter.ability_on,
		"unticking pressed the switch the 1997 strip had a medallion for")
	assert_eq(_lines()[0], "[x] Enable Filter", "and the line above the list says so")
	assert_lt(_shown(), whole, "the Inventory followed the tick")
	assert_gt(_shown(), 0)
	var wanted := 1 << DeckAbilities.Ability.FIRST_STRIKE
	for card_name in _names():
		var d := CardRegistry.get_card(card_name)
		assert_true(bool(DeckAbilities.native(d) & wanted)
				or bool(DeckAbilities.gives(d) & wanted),
			"%s has first strike, or hands it out" % card_name)
	assert_has(_names(), "Black Knight", "a native first striker")
	assert_has(_names(), "Lance", "and the aura that grants it — Gives is a scope")
	assert_does_not_have(_names(), "Grizzly Bears")
	assert_true(_funnel().button_pressed, "the funnel is lit: a page is in force")
	_press("Cancel")


func test_the_well_says_what_the_tick_just_switched_on() -> void:
	await _open_page("Rarity")
	_line("Common").pressed.emit()
	assert_eq(screen._status_label.text,
		DeckBuilderScreen.ENABLED_HINT % "Rarity",
		"a filter that switched itself on says so, as the list hint does")
	_press("Cancel")


func test_the_switch_alone_still_reaches_the_1997_view() -> void:
	# Everything ticked and the filter ON is a view of its own — every card
	# that has ANY of the thirteen — and it is the switch's to reach.
	var whole := _shown()
	await _open_page("Abilities")
	_line("Enable Filter").pressed.emit()
	await get_tree().process_frame
	assert_true(screen.filter.ability_on)
	assert_lt(_shown(), whole, "the cards with no ability at all are gone")
	assert_gt(_shown(), 100, "but every one that has one is still here")
	assert_has(_names(), "Serra Angel")
	assert_does_not_have(_names(), "Plains")
	_press("Cancel")


func test_a_widening_tick_never_presses_the_switch() -> void:
	# `Select All` means "stop narrowing", so it must not switch a filter
	# on over a list that excludes nothing.
	var whole := _shown()
	await _open_page("Artists")
	_press("Select All")
	await get_tree().process_frame
	assert_false(screen.filter.artist_on, "nothing was narrowed")
	assert_eq(_shown(), whole, "and nothing was filtered")
	_press("Clear All")
	await get_tree().process_frame
	assert_true(screen.filter.artist_on, "clearing IS narrowing")
	assert_eq(_shown(), 0)
	_press("Select All")
	await get_tree().process_frame
	assert_true(screen.filter.artist_on, "and it does not switch itself back off")
	assert_eq(_shown(), whole, "though every card is listed again")
	_press("Cancel")


func test_cancel_still_puts_the_switch_back() -> void:
	await _open_page("Abilities")
	_press("Clear All")
	_line("First strike").pressed.emit()
	assert_true(screen.filter.ability_on)
	_press("Cancel")
	await get_tree().process_frame
	assert_false(screen.filter.ability_on, "Cancel restores the snapshot, switch included")
	assert_true(screen.filter.ability_ticked(DeckAbilities.Ability.FLYING))
	assert_false(_funnel().button_pressed)


# ----------------------------------------------------------- realtime --

func test_every_medallion_on_the_strip_moves_the_inventory() -> void:
	# *"Whatever filters you click… should reflect in card-pool in the
	# bottom"*: one press, one re-listing, no OK to press.
	for group in screen._filter_bar.group_names():
		for button in screen._filter_bar.group_buttons(group):
			if button == _funnel():
				continue    # a door, not a filter
			var cue: String = button.get_meta("cue")
			var before := _shown()
			var revision: int = screen.filter.revision
			button.pressed.emit()
			assert_ne(screen.filter.revision, revision,
				"%s / %s moved the filter" % [group, cue])
			assert_ne(_shown(), before,
				"%s / %s moved the Inventory with it" % [group, cue])
			button.pressed.emit()
			assert_eq(_shown(), before,
				"%s / %s put back is the pool again" % [group, cue])


func test_every_kind_of_line_in_the_window_moves_the_inventory() -> void:
	# The three shapes the window draws: a list entry, a head check, and
	# the `Select All` / `Clear All` pair.
	await _open_page("Enchantments")
	var before := _shown()
	_line("] Creature").pressed.emit()
	await get_tree().process_frame
	assert_lt(_shown(), before, "a list entry, on the one page with no switch at all")
	_press("Cancel")
	await get_tree().process_frame

	await _open_page("Creatures")
	before = _shown()
	_line("] Summon").pressed.emit()
	await get_tree().process_frame
	assert_lt(_shown(), before, "a head check")
	_press("Cancel")
	await get_tree().process_frame

	await _open_page("Enchantments")
	before = _shown()
	_press("Clear All")
	await get_tree().process_frame
	assert_lt(_shown(), before, "Clear All")
	_press("Select All")
	await get_tree().process_frame
	assert_eq(_shown(), before, "Select All")
	_press("Cancel")


func test_select_all_and_clear_all_re_list_the_inventory_once() -> void:
	# They used to call the tick once per row, and every call re-filtered
	# the whole pool and rebuilt the Inventory: 126 rows on the Creatures
	# page was 126 passes, measured at 414 ms headless. `tick_many` does
	# the ticks and re-lists at the end.
	await _open_page("Creatures")
	assert_gt(_lines().size(), 100, "the pool's own creature types, so this is worth counting")
	var passes: int = screen.filter_passes
	_press("Clear All")
	await get_tree().process_frame
	assert_eq(screen.filter_passes, passes + 1, "one pass over the pool for the whole list")
	assert_false(screen.filter.creature_type_on("elf"), "and every row was really ticked")
	assert_false(screen.filter.creature_type_on("goblin"))
	_press("Cancel")


# ------------------- [1997] the three comparison mini-menus (@CASTCOST) --

func _cost_menu() -> void:
	_right_click(screen._filter_bar.group_buttons("Other Filters")[0])
	await get_tree().process_frame


func test_the_cost_menu_keeps_its_number_when_a_comparison_is_picked() -> void:
	# It used to close on the pick, taking the `Number` field with it, so
	# "cost = 3" meant right-clicking the medallion twice and the field
	# looked like decoration. 1997 asks for both halves in ONE gesture too:
	# `GLE_FILTER` (deckdll.cpp:7600) pops `show_dialog_filter_gle` from
	# the menu item itself and only then writes the mode.
	await _cost_menu()
	assert_not_null(_menu(), "the mini-menu")
	assert_not_null(_spin(), "with its number")
	_line("Equal to").pressed.emit()
	await get_tree().process_frame
	assert_not_null(_menu(), "the menu stayed up")
	assert_eq(screen.filter.cost_mode, DeckFilter.Cost.EQ)
	assert_not_null(_line("• Equal to"), "and the bullet moved to it")
	var spin := _spin()
	spin.value = 3
	await get_tree().process_frame
	assert_eq(screen.filter.cost_value, 3)
	assert_gt(_shown(), 0)
	for card_name in _names():
		assert_eq(CardRegistry.get_card(card_name).cost.mana_value(), 3,
			"%s is a three-drop" % card_name)
	_press("Done")
	await get_tree().process_frame
	assert_null(_menu(), "`Done` closes it — the number was applied as it was turned")


func test_the_four_cost_modes_are_the_string_tables_own() -> void:
	# `@CASTCOST` (Menus.txt:347). The table's inclusive wording beats the
	# manual's prose, which `deck_filter.gd`'s header already ruled on.
	assert_eq(FilterBar.COST_MENU[0], "Greater than or equal to")
	assert_eq(FilterBar.COST_MENU[1], "Less than or equal to")
	assert_eq(FilterBar.COST_MENU[2], "Equal to")
	assert_eq(FilterBar.COST_MENU[3], "X cost")
	var filter := DeckFilter.new()
	filter.cost_value = 2
	var bolt := CardRegistry.get_card("Lightning Bolt")      # {R}
	var bears := CardRegistry.get_card("Grizzly Bears")      # {1}{G}
	var angel := CardRegistry.get_card("Serra Angel")        # {3}{W}{W}
	filter.cost_mode = DeckFilter.Cost.GE
	assert_false(filter.matches_cost(bolt), "1 is not >= 2")
	assert_true(filter.matches_cost(bears), "2 is, inclusively")
	assert_true(filter.matches_cost(angel))
	filter.cost_mode = DeckFilter.Cost.LE
	assert_true(filter.matches_cost(bolt))
	assert_true(filter.matches_cost(bears), "and inclusively here too")
	assert_false(filter.matches_cost(angel))
	filter.cost_mode = DeckFilter.Cost.EQ
	assert_false(filter.matches_cost(bolt))
	assert_true(filter.matches_cost(bears))
	assert_false(filter.matches_cost(angel))


func test_x_cost_is_the_fourth_mode_and_ignores_the_number() -> void:
	var filter := DeckFilter.new()
	filter.cost_mode = DeckFilter.Cost.HAS_X
	filter.cost_value = 19
	assert_true(filter.matches_cost(CardRegistry.get_card("Fireball")), "{X}{R}")
	assert_false(filter.matches_cost(CardRegistry.get_card("Lightning Bolt")))
	filter.cost_value = 0
	assert_true(filter.matches_cost(CardRegistry.get_card("Fireball")),
		"the number is not this mode's question")


func test_power_and_toughness_compare_the_same_three_ways() -> void:
	# `@POWER` (Menus.txt:354) / `@TOUGHNESS` (:360) — the same three
	# twice, and a card with no power cannot answer either.
	assert_eq(FilterBar.RANK_MENU[0], "Greater than or equal to")
	assert_eq(FilterBar.RANK_MENU[1], "Less than or equal to")
	assert_eq(FilterBar.RANK_MENU[2], "Equal to")
	var bears := CardRegistry.get_card("Grizzly Bears")      # 2/2
	var angel := CardRegistry.get_card("Serra Angel")        # 4/4
	var bolt := CardRegistry.get_card("Lightning Bolt")
	for subject in ["power", "toughness"]:
		var filter := DeckFilter.new()
		var mode := "%s_mode" % subject
		filter.set("%s_value" % subject, 3)
		filter.set(mode, DeckFilter.Rank.GE)
		assert_false(filter.matches(bears), "%s 2 is not >= 3" % subject)
		assert_true(filter.matches(angel))
		assert_false(filter.matches(bolt), "a spell has no %s to rank" % subject)
		filter.set(mode, DeckFilter.Rank.LE)
		assert_true(filter.matches(bears))
		assert_false(filter.matches(angel))
		assert_false(filter.matches(bolt))
		filter.set(mode, DeckFilter.Rank.EQ)
		assert_false(filter.matches(bears))
		assert_false(filter.matches(angel))
		filter.set("%s_value" % subject, 4)
		assert_true(filter.matches(angel))
		filter.set(mode, DeckFilter.Rank.OFF)
		assert_true(filter.matches(bolt), "off is everything again")


func test_the_number_holds_its_edges() -> void:
	var filter := DeckFilter.new()
	# ZERO, which is a real casting cost — the lands and the Ornithopter.
	filter.cost_mode = DeckFilter.Cost.EQ
	filter.cost_value = 0
	assert_true(filter.matches_cost(CardRegistry.get_card("Mountain")))
	assert_true(filter.matches_cost(CardRegistry.get_card("Ornithopter")))
	assert_false(filter.matches_cost(CardRegistry.get_card("Lightning Bolt")))
	# PAST THE POOL: an empty Inventory, not an error.
	filter.cost_value = 99
	var shown := 0
	for card_name in CardRegistry.all_names():
		if filter.matches(CardRegistry.get_card(card_name)):
			shown += 1
	assert_eq(shown, 0, "nothing costs ninety-nine, and nothing breaks")
	# NEGATIVE, which the field cannot produce and the model survives.
	filter.cost_value = -1
	assert_false(filter.matches_cost(CardRegistry.get_card("Mountain")))
	filter.cost_mode = DeckFilter.Cost.GE
	assert_true(filter.matches_cost(CardRegistry.get_card("Mountain")),
		"everything is >= -1")
	# And a power of ZERO is a creature's answer, not "no creature".
	filter.cost_mode = DeckFilter.Cost.OFF
	filter.power_mode = DeckFilter.Rank.EQ
	filter.power_value = 0
	assert_true(filter.matches(CardRegistry.get_card("Ornithopter")), "0/2")
	assert_false(filter.matches(CardRegistry.get_card("Grizzly Bears")))


func test_the_number_field_cannot_be_typed_out_of_range() -> void:
	# The edges the FIELD holds, as against the model's above.
	await _cost_menu()
	_line("Equal to").pressed.emit()
	var spin := _spin()
	assert_eq(spin.min_value, 0.0, "no negative casting cost")
	assert_eq(spin.max_value, 20.0, "and nothing in the pool costs more")
	spin.get_line_edit().text = ""
	spin.apply()
	assert_eq(spin.value, 0.0, "an empty entry leaves the number where it was")
	spin.get_line_edit().text = "-4"
	spin.apply()
	assert_eq(spin.value, 0.0, "and a negative one is clamped to the floor")
	spin.get_line_edit().text = "bolt"
	spin.apply()
	assert_eq(spin.value, 0.0, "a word is not a number")
	spin.get_line_edit().text = "500"
	spin.apply()
	assert_eq(spin.value, 20.0, "past the pool is the top of the range")
	await get_tree().process_frame
	assert_eq(screen.filter.cost_value, 20, "and the filter was told")
	assert_eq(_shown(), 0, "an empty Inventory, which is the honest answer")
	_press("Done")


func test_the_medallion_keeps_the_comparison_over_a_press() -> void:
	# 1997's button toggles only the ENABLE bit — `CHECK_BUTTON(24,
	# "CASTCOST", global_filter_castcost, FN_ENABLE)` (deckdll.cpp:6653) —
	# and `GLE_FILTER`'s `valbase &= FN_ENABLE` keeps exactly that bit, so
	# the comparison survives. Ours folds the enable into the mode, so the
	# strip is what remembers.
	var cost: Button = screen._filter_bar.group_buttons("Other Filters")[0]
	await _cost_menu()
	_line("Equal to").pressed.emit()
	var spin := _spin()
	spin.value = 1
	_press("Done")
	await get_tree().process_frame
	assert_eq(screen.filter.cost_mode, DeckFilter.Cost.EQ)
	var one_drops := _shown()
	assert_gt(one_drops, 0)
	cost.pressed.emit()
	assert_eq(screen.filter.cost_mode, DeckFilter.Cost.OFF, "up is off")
	assert_gt(_shown(), one_drops)
	cost.pressed.emit()
	assert_eq(screen.filter.cost_mode, DeckFilter.Cost.EQ, "down is what it was")
	assert_eq(screen.filter.cost_value, 1, "with its number")
	assert_eq(_shown(), one_drops)


func test_the_gold_and_land_menus_still_close_on_the_pick() -> void:
	# Only a menu that carries a NUMBER stays open. A 1997 popup menu with
	# nothing else to do closes on the pick, as it always did.
	_right_click(screen._filter_bar.group_buttons("Color Filters")[5])
	await get_tree().process_frame
	assert_not_null(_menu(), "the Gold mini-menu")
	_line("Matching any selected color button").pressed.emit()
	await get_tree().process_frame
	assert_null(_menu(), "closed on the pick")
	assert_eq(screen.filter.gold_mode, DeckFilter.Gold.MATCH_ANY)


# --------------------- [1997] the polarity and the combination rules --

func test_the_strip_starts_wholly_depressed_and_shows_everything() -> void:
	# ch.10, "Filters Galore": *"when the button is depressed, it is on…
	# when the button is up, it's off, and cards represented by that button
	# are eliminated"*. A fresh strip is every medallion DOWN — the
	# OPPOSITE of s30's, where nothing lit means everything. The four
	# comparison medallions are the exception the manual itself makes: they
	# are the Other Filters, and up is where a comparison rests.
	for group in screen._filter_bar.group_names():
		for button in screen._filter_bar.group_buttons(group):
			var ranged: bool = button.get_meta("ranged", false)
			assert_eq(button.button_pressed, not ranged,
				"%s / %s at rest" % [group, button.get_meta("cue")])
	assert_false(screen.filter.active(), "nothing is hiding anything")
	assert_eq(_shown(), CardRegistry.all_names().size(), "so the whole pool is listed")


func test_the_groups_are_additive_within_and_exclusive_between() -> void:
	# *"Within each set of buttons, the filters are additive… Between sets,
	# however, the filters are exclusive. That means… if you have Green and
	# Instants both depressed, you'll see only green instants… if you chose
	# an odd filter combination, like Enchantments and Trample, no cards
	# would show up at all."*
	screen.filter.clear_all()
	screen.filter.toggle_color(Mtg.ManaColor.G)
	screen.filter.toggle_type(Mtg.CardType.INSTANT)
	screen._refresh_inventory()
	assert_gt(_shown(), 0, "green instants")
	for card_name in _names():
		var d := CardRegistry.get_card(card_name)
		assert_true(bool(d.types & Mtg.CardType.INSTANT), "%s is an instant" % card_name)
		assert_true(bool(d.color_mask() & Mtg.ManaColor.G), "%s is green" % card_name)
	assert_has(_names(), "Giant Growth")
	assert_does_not_have(_names(), "Counterspell", "blue is up")
	assert_does_not_have(_names(), "Grizzly Bears", "a creature, not an instant")
	# The manual's own odd pair, through the window's own page.
	screen.filter.toggle_type(Mtg.CardType.INSTANT)
	screen.filter.toggle_type(Mtg.CardType.ENCHANTMENT)
	for color in DeckFilter.COLOR_ORDER:
		if not screen.filter.color_on(color):
			screen.filter.toggle_color(color)
	for ability in DeckAbilities.Ability.values():
		screen.filter.tick_ability(ability, ability == DeckAbilities.Ability.TRAMPLE)
	screen._refresh_inventory()
	assert_true(screen.filter.ability_on, "the ticks pressed the switch")
	assert_eq(_shown(), 0, "Enchantments and Trample: no cards would show up at all")


func test_a_land_and_a_colourless_card_ignore_the_colour_group() -> void:
	# The two 1997 exemptions, pinned at the screen rather than the model:
	# *"so long as the Land filter is active, all lands are displayed,
	# regardless of which Color Filters are on"*, and *"there's no Color
	# Filter for colorless cards."*
	for color in DeckFilter.COLOR_ORDER:
		screen.filter.toggle_color(color)
	screen.filter.gold = false
	screen._refresh_inventory()
	assert_has(_names(), "Mountain", "every colour is up and a land still shows")
	assert_has(_names(), "Sol Ring", "and so does a colourless artifact")
	assert_does_not_have(_names(), "Lightning Bolt")
