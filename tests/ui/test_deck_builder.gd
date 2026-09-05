extends GutTest
## The Deck Builder screen: that every 1997 region and command is really
## there, that the Inventory and the Deck are two views of the same
## filter + model, and that the main menu's entry points at a scene that
## exists — the failure mode the owner explicitly ruled out.


var screen: DeckBuilderScreen


func before_each() -> void:
	CardRegistry.ensure_loaded()
	screen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func _walk(node: Node) -> Array:
	var out := [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out


func _button_texts() -> Array:
	var found := []
	for node in _walk(screen):
		if node is Button and node.text != "":
			found.append(node.text)
	return found


func _find(type: String) -> Array:
	var found := []
	for node in _walk(screen):
		if node.is_class(type) or node.get_script() != null \
				and node.get_script().get_global_name() == type:
			found.append(node)
	return found


# --------------------------------------------------------- the regions --

func test_the_screen_has_the_1997_regions() -> void:
	var showcase := 0
	var areas := 0
	var bars := 0
	for node in _walk(screen):
		if node is CardPreview:
			showcase += 1
		elif node is CardArea:
			areas += 1
		elif node is FilterBar:
			bars += 1
	assert_eq(showcase, 1, "the Showcase")
	# THREE card surfaces since the sideboard shipped: the Deck area, the
	# Inventory area and the [QoL] sideboard strip carved out of the deck
	# area's bottom edge.
	assert_eq(areas, 3, "the Deck area, the Sideboard strip and the Inventory")
	assert_eq(bars, 1, "the Filter bar")


func test_every_deck_surface_command_is_on_the_mini_menu() -> void:
	# The screenshot pass moved the command row off the top of the screen:
	# the 1997 bar along the bottom of the deck area holds five buttons and
	# `@DECKSURFACE_STANDALONE` holds eight commands, so the commands live
	# where the original kept them — the deck surface's right-click
	# mini-menu, which the `Deck` button also opens.
	screen._open_mini_menu()
	var texts := _button_texts()
	for label in DeckBuilderScreen.COMMANDS:
		# `Music` and `Sound Effects` are CHECKED menu items, so they are
		# drawn with their tick — `_menu_text` is the one place that knows.
		assert_true(texts.has(screen._menu_text(label)),
			"@DECKSURFACE_STANDALONE: %s" % label)
	for label in DeckBuilderScreen.EXTRA_COMMANDS:
		assert_true(texts.has("%s  [QoL]" % label),
			"[QoL] %s, marked as ours" % label)


func test_the_command_bar_is_the_1997_five_along_the_bottom() -> void:
	var texts := _button_texts()
	assert_true(texts.has("Stats (0 cards)"), "Stats, lettered with its count")
	assert_true(texts.has("Deck"), "the mini-menu button")
	assert_true(texts.has("* Deck1 *"), "the active slot is starred")
	assert_true(texts.has("Deck2"))
	assert_true(texts.has("Deck3"))
	assert_true(texts.has("Done"), "@DIALOGBUTTONS")
	# It closes the deck area along its bottom edge, as the screenshot has
	# it — not across the top of the screen, where it used to be.
	assert_gt(screen._command_row.position.y,
		screen._deck_rect().position.y + screen._deck_rect().size.y - 1.0,
		"the bar is below the deck area")


func test_the_deck_header_shows_the_deck_name() -> void:
	assert_eq(screen._header_label.text, "New Deck", "@NEWDECK")
	screen.deck.deck_name = "Knights of Alsadim"
	screen.refresh()
	assert_eq(screen._header_label.text, "Knights of Alsadim")


func test_the_inventory_starts_with_the_whole_pool() -> void:
	assert_eq(screen._inventory.entry_count(), CardRegistry.size(),
		"every Magic card included in the game")


func test_the_inventory_builds_only_one_page_of_widgets() -> void:
	# s30's ScrollableList renders the visible window only; 800 MiniCards
	# at once would be ten thousand nodes for twenty visible cards.
	var built := 0
	for node in _walk(screen._inventory):
		if node is MiniCard:
			built += 1
	assert_lt(built, 60, "one page of cards, not the whole pool")
	assert_gt(built, 0, "and that page is drawn")


# ------------------------------------------------------ adding, removing --

func test_clicking_an_inventory_card_puts_it_in_the_deck() -> void:
	screen._add_one("Lightning Bolt")
	assert_eq(screen.deck.count_of("Lightning Bolt"), 1)
	assert_eq(screen._deck_area.entry_count(), 1, "and it shows in the Deck area")


func test_clicking_a_deck_card_takes_one_out() -> void:
	screen._add_one("Lightning Bolt")
	screen._add_one("Lightning Bolt")
	screen._remove_one("Lightning Bolt")
	assert_eq(screen.deck.count_of("Lightning Bolt"), 1)


func test_right_clicking_a_deck_card_takes_the_whole_column() -> void:
	for _i in 4:
		screen._add_one("Lightning Bolt")
	screen._remove_all("Lightning Bolt")
	assert_eq(screen.deck.count_of("Lightning Bolt"), 0)
	assert_eq(screen._deck_area.entry_count(), 0)


func _cells(area: CardArea) -> Array:
	var found := []
	for node in _walk(area):
		if node is CardArea.Cell:
			found.append(node)
	return found


func test_a_real_click_on_an_inventory_card_adds_it() -> void:
	var cells := _cells(screen._inventory)
	assert_gt(cells.size(), 0, "the Inventory drew a page")
	var cell: CardArea.Cell = cells[0]
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	cell.gui_input.emit(release)
	assert_eq(screen.deck.count_of(cell.card_name), 1,
		"the card under the pointer went into the deck")


func test_a_card_dragged_from_the_inventory_lands_in_the_deck() -> void:
	# "you can... drag it there with the mouse, then release" (manual ch.10).
	var payload := {"card_name": "Mountain", "source": "inventory"}
	assert_true(screen._deck_area._can_drop_data(Vector2.ZERO, payload))
	screen._deck_area._drop_data(Vector2.ZERO, payload)
	assert_eq(screen.deck.count_of("Mountain"), 1)


func test_a_card_dragged_back_to_the_inventory_leaves_the_deck() -> void:
	# "drag it from this area into the Inventory area" (manual ch.10).
	screen._add_one("Mountain")
	var payload := {"card_name": "Mountain", "source": "deck"}
	assert_true(screen._inventory._can_drop_data(Vector2.ZERO, payload))
	screen._inventory._drop_data(Vector2.ZERO, payload)
	assert_eq(screen.deck.count_of("Mountain"), 0)


func test_a_surface_does_not_accept_its_own_cards() -> void:
	assert_false(screen._deck_area._can_drop_data(Vector2.ZERO,
		{"card_name": "Mountain", "source": "deck"}))


func test_a_refusal_is_shown_not_thrown() -> void:
	screen._remove_one("Lightning Bolt")
	assert_ne(screen._status_label.text, "", "the refusal is on screen")


# --------------------------------------------------------- the filters --

func test_a_filter_narrows_the_inventory() -> void:
	var before := screen._inventory.entry_count()
	screen.filter.toggle_type(Mtg.CardType.CREATURE)
	screen._refresh_inventory()
	assert_lt(screen._inventory.entry_count(), before, "creatures are filtered out")


func test_the_type_ahead_narrows_the_inventory() -> void:
	screen.filter.text = "lightning"
	screen._refresh_inventory()
	assert_lt(screen._inventory.entry_count(), 20)
	assert_gt(screen._inventory.entry_count(), 0)


func test_the_filter_bar_offers_every_group() -> void:
	# The screenshot pass took the four group HEADINGS off the strip — the
	# 1997 bar is one unlabelled row of medallions, grouped by a wider gap
	# and nothing else. The groups themselves are structure and survive:
	# `matches()` is additive within one and exclusive between them.
	var bar: FilterBar = _find("FilterBar")[0]
	for group in ["Color Filters", "Set Filters", "Type Filters", "Other Filters"]:
		assert_true(bar.group_names().has(group), group)
		assert_gt(bar.group_buttons(group).size(), 0, "%s has toggles" % group)
	assert_eq(bar.group_buttons("Color Filters").size(), 6,
		"five colours and @GOLD")
	assert_eq(bar.group_buttons("Type Filters").size(),
		DeckFilter.TYPE_ORDER.size())


func test_the_filter_strip_is_one_row() -> void:
	var bar: FilterBar = _find("FilterBar")[0]
	var tops := {}
	for group in bar.group_names():
		for button in bar.group_buttons(group):
			tops[button.global_position.y] = true
	assert_eq(tops.size(), 1, "every medallion sits on the same line")


func test_the_card_count_uses_the_1997_wording() -> void:
	assert_string_contains(screen._count_label.text, "cards are in the list")


# -------------------------------------------------------- the commands --

func test_clear_deck_then_restore_deck() -> void:
	screen._add_one("Lightning Bolt")
	screen._run_command("Clear deck")
	assert_eq(screen.deck.total(), 0)
	assert_eq(screen._clear_button.text, "Restore deck", "@DECKCLEAR_RESTORE")
	screen._run_command("Restore deck")
	assert_eq(screen.deck.count_of("Lightning Bolt"), 1)
	assert_eq(screen._clear_button.text, "Clear deck")


func test_new_deck_empties_the_surface() -> void:
	screen._add_one("Lightning Bolt")
	screen._run_command("New deck")
	# The deck was touched, so `@SAVE` asks first — answer "No".
	_answer("No")
	assert_eq(screen.deck.total(), 0)
	assert_eq(screen.deck.deck_name, "New Deck")


## Press a button by its label in the front-most dialog. The save prompt
## the audit pass added stands between several commands and their effect.
func _answer(label: String) -> void:
	var dialogs := screen.open_dialogs()
	assert_gt(dialogs.size(), 0, "a dialog is asking")
	for node in _walk(dialogs[-1]):
		if node is Button and node.text == label:
			node.pressed.emit()
			return
	fail_test("no '%s' button in the dialog" % label)


func test_consolidate_duplicate_cards_toggles_the_display() -> void:
	for _i in 3:
		screen._add_one("Lightning Bolt")
	assert_eq(screen._deck_area.entry_count(), 1, "grouped: one representative")
	screen._run_command("Consolidate duplicate cards")
	assert_eq(screen._deck_area.entry_count(), 3, "separately: one per copy")


func test_sort_deck_puts_lands_first() -> void:
	screen._add_one("Lightning Bolt")
	screen._add_one("Mountain")
	screen._run_command("Sort deck")
	assert_eq(screen.deck.names()[0], "Mountain",
		"Lands are always at the beginning")


func test_stats_opens_the_1997_window() -> void:
	screen._add_one("Mountain")
	screen._run_command("Stats")
	var titles := []
	for node in _walk(screen):
		if node is Label:
			titles.append(node.text)
	assert_true(titles.has("Stats (1 cards)"), "@STATS: 'Stats (%d cards)'")
	assert_true(titles.has("Card Type"), "@STATSSCREEN's first row heading")
	assert_true(titles.has("Mana Sources"), "@STATSSCREEN's mana row")


func test_the_load_dialog_lists_the_deck_files() -> void:
	screen._run_command("Load deck")
	var texts := _button_texts()
	var shipped := 0
	for text in texts:
		if String(text).ends_with(".deck"):
			shipped += 1
	assert_gt(shipped, 0, "@LOADDECKDIALOG lists the player decks")


func test_loading_a_deck_fills_the_surface() -> void:
	var path := DeckStore.all_deck_paths()[0]
	screen._load_deck(path)
	assert_gt(screen.deck.total(), 20, "a real deck arrived")
	assert_gt(screen._deck_area.entry_count(), 0)


func test_saving_needs_a_name_first() -> void:
	screen._add_one("Mountain")
	screen._run_command("Save deck")
	assert_string_contains(screen._status_label.text,
		"You must name your deck", "@NAMEYOURDECK")


func test_a_saved_deck_round_trips_and_is_playable() -> void:
	screen._load_deck(DeckStore.all_deck_paths()[0])
	screen.deck.deck_name = "Gut Test Deck"
	screen._write_deck()
	var path := DeckStore.path_for("Gut Test Deck")
	assert_true(FileAccess.file_exists(path), "the file was written")
	# The battle-setup screen's own test: strict load, no errors, playable.
	var reloaded := DeckList.load_file(path, true)
	assert_eq(reloaded.errors, [], "the setup screen can load what we save")
	assert_eq(reloaded.cards.size(), screen.deck.total())
	assert_true(DeckStore.all_deck_paths().has(path), "and it is listed")
	assert_eq(DeckStore.delete_deck(path), "", "cleaned up")


# ------------------------------------------------------- the menu entry --

func test_the_main_menu_opens_a_scene_that_exists() -> void:
	assert_true(ResourceLoader.exists(
		"res://game/deck_builder/deck_builder_screen.tscn"))
	var menu: Control = load("res://game/main.tscn").instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame
	var labels := []
	for node in _walk(menu):
		if node is Button:
			labels.append(node.text)
	assert_true(labels.has("Deck Builder"),
		"@SHELLSCREEN_TOOLS: '&Deck Builder:Build or Modify decks.'")


# ============================================================ AUDIT PASS ==
# Bugs found by driving the screen (2026-08-31). Every one of these failed
# before the fix that follows it in game/deck_builder/.

# ---------------------------------------------------------- the scroll --

func test_the_inventory_keeps_its_place_when_a_card_goes_into_the_deck() -> void:
	# The Inventory is the whole card pool and does not depend on the deck,
	# so putting a card in the deck must not throw the player back to
	# "Abomination". (s30 resets the carousel only on a FILTER change,
	# edit_deck.go:391-396.)
	var step := screen._inventory.scroll_step()
	screen._inventory.scroll_by(4)
	var kept := screen._inventory.offset()
	assert_eq(kept, 4 * step, "scrolled four steps in")
	screen._add_one("Lightning Bolt")
	assert_eq(screen._inventory.offset(), kept, "still where the player left it")


func test_changing_a_filter_returns_the_inventory_to_the_start() -> void:
	screen._inventory.scroll_by(4)
	assert_gt(screen._inventory.offset(), 0)
	screen.filter.toggle_type(Mtg.CardType.CREATURE)
	screen._refresh_inventory()
	assert_eq(screen._inventory.offset(), 0, "a new list starts at its beginning")


func test_the_scroll_bar_and_the_wheel_agree() -> void:
	# They used to disagree: the bar counted CARDS while the wheel counted
	# ROWS, so dragging the bar to its end and wheeling to the end left the
	# surface showing two different pages.
	var area: CardArea = screen._inventory
	area.scroll_to_end()
	var by_wheel := area.offset()
	area.scroll_to(0)
	area._bar.value = area._bar.max_value
	assert_eq(area.offset(), by_wheel, "the bar reaches exactly the last page")
	assert_eq(area.offset() % area.scroll_step(), 0, "and lands on a boundary")


func test_the_last_page_is_never_scrolled_past() -> void:
	var area: CardArea = screen._inventory
	# Scroll further than the list is long, whatever the page geometry —
	# the Inventory is one row of cards now, so a fixed 500 was no longer
	# past the end.
	for _i in area.entry_count():
		area.scroll_by(1)
	assert_lt(area.offset(), area.entry_count(), "still showing cards")
	assert_gt(area.offset() + area.page_size(), area.entry_count() - 1,
		"and the last card is on the last page")


func test_the_inventory_flows_in_columns_under_its_own_scroll_bar() -> void:
	# A scroll bar ALONG THE BOTTOM moves the cards sideways (manual ch.10:
	# "At the bottom of the Inventory area is a scroll bar you can use to
	# move through your inventory"), so the Inventory must read top-to-
	# bottom then left-to-right. The Deck, scrolled vertically, reads the
	# other way.
	assert_eq(screen._inventory.scroll_step(), screen._inventory.rows(),
		"one step of a bottom bar is one COLUMN of cards")
	assert_eq(screen._deck_area.scroll_step(), screen._deck_area.columns(),
		"one step of a side bar is one ROW of cards")


# ------------------------------------------------------------- resize --

func test_the_screen_follows_the_window_when_it_resizes() -> void:
	screen.size = Vector2(1600, 900)
	await get_tree().process_frame
	assert_eq(screen._inventory.position, screen._inventory_rect().position,
		"the Inventory sits on its own ground")
	assert_eq(screen._deck_area.size, screen._deck_rect().size,
		"the Deck area grew with the window")
	assert_lt(screen._filter_bar.position.y + screen._filter_bar.size.y,
		screen._inventory_rect().position.y, "the Filter bar is still above it")


func test_the_filter_bar_fits_inside_the_screen() -> void:
	# It did not: the Casting Cost mini-menu was flattened into an inline
	# OptionButton + SpinBox, which pushed the Other Filters group off the
	# right edge at 1280.
	await get_tree().process_frame
	assert_lte(screen._filter_bar.get_combined_minimum_size().x, screen.size.x,
		"the four groups fit the window the game opens in")


# ------------------------------------------------------------ dialogs --

func test_escape_closes_the_open_dialog_instead_of_leaving() -> void:
	# "Esc is just like clicking the Cancel button" (manual p.116) — and
	# with a dialog on screen the Cancel button is the DIALOG's.
	screen._run_command("Stats")
	assert_eq(screen.open_dialogs().size(), 1)
	screen._on_escape()
	assert_eq(screen.open_dialogs().size(), 0, "the dialog went, not the screen")


func test_only_one_mini_menu_opens_at_a_time() -> void:
	screen._open_mini_menu()
	screen._open_mini_menu()
	assert_eq(screen.open_dialogs().size(), 1, "rapid clicks do not stack menus")


# ------------------------------------------------------- the commands --

func test_the_playset_shortcut_reports_what_it_really_added() -> void:
	# It said "Added 4 X" even when the deck was full and nothing went in.
	screen.deck.counts["Mountain"] = DeckModel.MAX_TOTAL
	screen._inventory.card_bulk.emit("Lightning Bolt")
	assert_eq(screen.deck.count_of("Lightning Bolt"), 0, "the deck was full")
	assert_false(screen._status_label.text.begins_with("Added 4"),
		"and the screen does not claim otherwise")


func test_a_modified_deck_is_offered_a_save_before_it_is_thrown_away() -> void:
	# `@SAVE` (Menus.txt): "Do you wish to save %s?" — the manual's own
	# Restore Deck note: "you're prompted to save the current deck".
	screen.deck.deck_name = "Work In Progress"
	screen._add_one("Lightning Bolt")
	screen._run_command("New deck")
	assert_eq(screen.open_dialogs().size(), 1, "the prompt is on screen")
	assert_eq(screen.deck.count_of("Lightning Bolt"), 1, "nothing thrown away yet")


func test_an_unmodified_deck_is_thrown_away_without_a_prompt() -> void:
	screen._run_command("New deck")
	assert_eq(screen.open_dialogs().size(), 0)
	assert_eq(screen.deck.total(), 0)


func test_loading_a_deck_ends_the_chance_to_restore() -> void:
	# "Once you load a deck, any deck you have cleared previously can no
	# longer be restored" (manual ch.10).
	screen._add_one("Lightning Bolt")
	screen._run_command("Clear deck")
	assert_eq(screen._clear_button.text, "Restore deck")
	screen._load_deck(DeckStore.all_deck_paths()[0])
	assert_eq(screen._clear_button.text, "Clear deck", "the offer is withdrawn")
	assert_null(screen._cleared)


# ------------------------------------------------- decks we cannot play --

func test_a_deck_naming_cards_we_have_not_built_still_opens() -> void:
	# The builder is a TOOL: a deck file listing a card outside our pool
	# must open with the rest of its cards, not refuse the whole file.
	#
	# WHAT HAPPENS TO THOSE CARDS CHANGED IN THE PROXY PASS (2026-09-01).
	# They used to be DROPPED — so a deck opened here and saved came back
	# short, silently, and the player's own file was edited by looking at
	# it. They are now kept as PROXIES ([ProxyCard]): every count is
	# right, the file round-trips, and the deck is what says it cannot be
	# duelled with.
	var path := "user://decks/_gut_partial.deck"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://decks"))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("name: Partial\n4 Lightning Bolt\n2 Chaos Orb\n20 Mountain\n")
	file.close()
	screen._load_deck(path)
	assert_eq(screen.deck.count_of("Lightning Bolt"), 4, "what we do have came in")
	assert_eq(screen.deck.count_of("Mountain"), 20)
	assert_eq(screen.deck.count_of("Chaos Orb"), 2,
		"and what we do not have came in as a proxy, both copies")
	assert_eq(screen.deck.total(), 26, "nothing was lost on the way in")
	assert_eq(screen.deck.proxy_names(), ["Chaos Orb"] as Array[String])
	assert_string_contains(screen._status_label.text, "Chaos Orb",
		"and the screen names it")
	assert_string_contains(screen._legality_label.tooltip_text, "Chaos Orb",
		"...on the legality line too, which is where it stays")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# ------------------------------------------------------ the Load dialog --

func test_the_load_dialog_can_delete_one_of_the_players_own_decks() -> void:
	screen.deck.deck_name = "Gut Delete Me"
	screen._add_one("Mountain")
	screen._write_deck()
	var path := DeckStore.path_for("Gut Delete Me")
	assert_true(FileAccess.file_exists(path))
	assert_eq(DeckStore.delete_deck(path), "", "a player deck may go")
	assert_false(FileAccess.file_exists(path))
	var shipped := DeckStore.deck_paths_in(DeckStore.SHIPPED_DIR)
	if not shipped.is_empty():
		assert_ne(DeckStore.delete_deck(shipped[0]), "",
			"a deck the game ships may not")


# -------------------------------------------------------- the keyboard --

func test_the_areas_page_with_the_keyboard() -> void:
	var area: CardArea = screen._inventory
	area.grab_focus()
	assert_eq(area.offset(), 0)
	area.page_down()
	assert_eq(area.offset(), area.page_size() - area.page_size() % area.scroll_step(),
		"Page Down moves a whole page")
	area.home()
	assert_eq(area.offset(), 0, "Home returns to the first card")
	area.end()
	assert_gt(area.offset(), 0, "End reaches the last page")


# ---------------------------------------------------------- efficiency --

func test_putting_a_card_in_the_deck_does_not_re_filter_the_pool() -> void:
	# 800 cards through matches() + a sort, on every single click, was the
	# screen's whole cost. The Inventory depends on the FILTER, never on
	# the deck, so it is rebuilt only when the filter moves.
	screen._refresh_inventory()
	var before := screen.filter_passes
	screen._add_one("Lightning Bolt")
	screen._remove_one("Lightning Bolt")
	assert_eq(screen.filter_passes, before, "the pool was not walked again")
	screen.filter.toggle_color(Mtg.ManaColor.R)
	screen._refresh_inventory()
	assert_eq(screen.filter_passes, before + 1, "but a filter change does walk it")


func test_a_scrolled_page_reuses_its_widgets() -> void:
	# Paging used to queue_free every MiniCard and build a fresh one; a
	# MiniCard is ~20 nodes, so a wheel notch cost 400 node churns.
	#
	# The SECOND audit pass went one better and ROTATES the page's widgets
	# so that the ones already showing the right card keep it
	# (CardArea._rotate_cells), which means the widget in slot 0 afterwards
	# need not be the one that was in slot 0 before. What must hold — and
	# what this now says — is that the page is the SAME SET of widgets and
	# that it really did move.
	var area: CardArea = screen._inventory
	var first := area.cell_nodes()
	assert_gt(first.size(), 0)
	var was_showing: String = first[0].card_name
	area.scroll_by(1)
	var second := area.cell_nodes()
	assert_eq(second.size(), first.size(), "the same page")
	for cell in second:
		assert_true(first.has(cell), "no widget was built for the new page")
	assert_ne(second[0].card_name, was_showing, "and it shows a different card")


func test_a_scroll_rebinds_only_the_cards_that_are_new() -> void:
	# The rotation's whole point: rebinding a cell is a MiniCard.refresh
	# (art, frame, mana stripes, badges) at ~0.3 ms, and one notch of the
	# Inventory brings in ONE card. It used to pay for all ten on screen.
	var area: CardArea = screen._inventory
	var before := {}
	for cell in area.cell_nodes():
		before[cell] = cell.card_name
	area.scroll_by(1)
	var changed := 0
	for cell in area.cell_nodes():
		if before.get(cell, "") != cell.card_name:
			changed += 1
	assert_eq(changed, area.scroll_step(),
		"one step of new cards, not a whole page of rebinds")


# ======================================================= SCREENSHOT PASS ==
# The restyle to the owner's 1997 screenshot of the in-Shandalar Deck
# screen, and the [QoL] the owner asked for on top of it. Every test below
# names the region or the feature it pins.

# ------------------------------------------------------------ the skin --

func test_the_deck_area_is_a_quilt_of_1997_slot_carvings() -> void:
	# The screenshot's deck grid is `deck_slot_plaques` laid edge to edge,
	# every empty slot carrying a carved mana watermark. The Inventory is
	# NOT: it sits on Dekbar1's plain teal field, as it does in 1997.
	assert_true(screen._deck_area.slot_plaques, "the deck area is quilted")
	assert_false(screen._inventory.slot_plaques, "the Inventory is not")


func test_the_inventory_is_one_row_of_full_size_cards() -> void:
	# The screenshot shows a single rack of large cards, not two rows of
	# miniatures. The trade is stated in _build_inventory: fewer cards on
	# screen, so the filters and the type-ahead carry more of the work.
	assert_eq(screen._inventory.rows(), 1, "one row")
	assert_eq(screen._inventory._cell, MiniCard.SIZE, "drawn at 1:1")
	# ...and so is the deck area. The third audit pass took the 0.85 out:
	# one card size everywhere is MiniCard.SIZE's own rule and it names
	# this screen. See test_both_surfaces_draw_cards_at_the_one_size.
	assert_eq(screen._deck_area._cell, screen._inventory._cell,
		"the same card on both surfaces")


func test_the_type_medallions_are_the_cells_the_screenshot_shows() -> void:
	# The audit pass moved Enchantment to (2,6) and Sorcery to (0,5) by
	# matching silhouettes. A render of the real program disagrees: its
	# type run is Land, Artifacts, Creatures, Enchantments, Instants,
	# Interrupts, Sorceries, and correlating each medallion against all 27
	# cells puts Enchantments on the ringless crescent and Sorceries back
	# on (2,6). The gold ring is the discriminator — sets wear one, types
	# never do.
	assert_eq(FilterBar.TYPE_CELL[Mtg.CardType.ENCHANTMENT], [1, 3])
	assert_eq(FilterBar.TYPE_CELL[Mtg.CardType.SORCERY], [2, 6])
	# And the five colours are medallions in their own right, not the big
	# carved plaques — those are the deck area's watermarks.
	for color in DeckFilter.COLOR_ORDER:
		assert_true(FilterBar.COLOR_CELL.has(color),
			"%s has a medallion" % DeckFilter.COLOR_LABELS[color])


# -------------------------------------------------- [QoL] the deck slots --

func test_the_three_deck_slots_each_keep_their_own_deck() -> void:
	screen._add_one("Lightning Bolt")
	screen._switch_slot(1)
	assert_eq(screen.deck.total(), 0, "Deck2 starts empty")
	screen._add_one("Mountain")
	screen._switch_slot(0)
	assert_eq(screen.deck.count_of("Lightning Bolt"), 1, "Deck1 is as it was")
	screen._switch_slot(1)
	assert_eq(screen.deck.count_of("Mountain"), 1, "and so is Deck2")


func test_the_active_slot_is_starred_the_way_the_screenshot_stars_it() -> void:
	assert_eq(screen._slot_buttons[0].text, "* Deck1 *")
	assert_eq(screen._slot_buttons[2].text, "Deck3")
	screen._switch_slot(2)
	assert_eq(screen._slot_buttons[0].text, "Deck1")
	assert_eq(screen._slot_buttons[2].text, "* Deck3 *")


func test_a_new_deck_lands_in_the_slot_it_was_made_in() -> void:
	# Every command that REPLACES the model has to write it back into the
	# slot, or the slot keeps the deck the screen has stopped showing.
	screen._switch_slot(1)
	screen._add_one("Mountain")
	screen._run_command("New deck")
	# `New deck` on a modified deck asks `@SAVE` first; answer No.
	assert_eq(screen.open_dialogs().size(), 1, "the save prompt")
	for node in _walk(screen.open_dialogs()[0]):
		if node is Button and node.text == "No":
			node.pressed.emit()
			break
	screen._switch_slot(0)
	screen._switch_slot(1)
	assert_eq(screen.deck.total(), 0, "the slot holds the NEW deck, not the old")


# -------------------------------------------------------- [QoL] the undo --

func test_undo_puts_back_a_column_taken_by_a_right_click() -> void:
	# The screen's most destructive gesture takes every copy at once.
	for _i in 4:
		screen._add_one("Lightning Bolt")
	screen._remove_all("Lightning Bolt")
	assert_eq(screen.deck.count_of("Lightning Bolt"), 0)
	screen._run_command("Undo")
	assert_eq(screen.deck.count_of("Lightning Bolt"), 4, "all four are back")


func test_undo_is_one_step_and_says_so_when_there_is_none() -> void:
	screen._run_command("Undo")
	assert_string_contains(screen._status_label.text, "nothing to undo")


func test_undo_undoes_itself() -> void:
	screen._add_one("Mountain")
	screen._run_command("Undo")
	assert_eq(screen.deck.total(), 0)
	screen._run_command("Undo")
	assert_eq(screen.deck.count_of("Mountain"), 1, "the step is a toggle")


# ------------------------------------------------ [QoL] add basic land --

func test_add_basic_land_adds_the_whole_handful_at_once() -> void:
	screen._add_basic_land("Mountain", 17)
	assert_eq(screen.deck.count_of("Mountain"), 17,
		"seventeen lands for one gesture, not seventeen clicks")
	screen._run_command("Undo")
	assert_eq(screen.deck.count_of("Mountain"), 0, "and it is one undo step")


func test_the_land_dialog_offers_all_five_basics() -> void:
	screen._run_command("Add basic land")
	var texts := _button_texts()
	for basic in ["Plains", "Island", "Swamp", "Mountain", "Forest"]:
		assert_true(texts.has(basic), basic)


# ---------------------------------------------------------- [QoL] notes --

func test_deck_notes_survive_a_save_and_a_load() -> void:
	screen.deck.deck_name = "Note Test Deck"
	screen.deck.notes = "Weak to artifact removal.\nSwap in Disenchant."
	for _i in 4:
		screen._add_one("Mountain")
	screen._write_deck()
	var path := DeckStore.path_for("Note Test Deck")
	var report: Array = []
	var loaded := DeckStore.load_deck(path, report)
	assert_not_null(loaded)
	assert_eq(loaded.notes, "Weak to artifact removal.\nSwap in Disenchant.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_a_deck_file_written_before_notes_existed_still_loads() -> void:
	# The whole point of carrying notes as `# note:` comment lines: every
	# older file has none, and reads back with empty notes rather than an
	# error. This reads one the project SHIPS, which predates the field.
	var paths := DeckStore.deck_paths_in(DeckStore.SHIPPED_DIR)
	assert_gt(paths.size(), 0, "the project ships decks")
	var report: Array = []
	var loaded := DeckStore.load_deck(paths[0], report)
	assert_not_null(loaded, "%s still loads" % paths[0])
	assert_eq(loaded.notes, "", "and simply has no notes")
	assert_gt(loaded.total(), 0, "with its cards intact")


# --------------------------------------------------------- [QoL] export --

func test_export_writes_a_decklist_other_programs_can_read() -> void:
	screen.deck.deck_name = "Export Test"
	for _i in 3:
		screen._add_one("Lightning Bolt")
	screen._export_deck(".dec")
	var path := "%s/%s.dec" % [DeckStore.EXPORT_DIR,
		DeckStore.file_stem("Export Test")]
	assert_true(FileAccess.file_exists(path), "the file is there")
	var back := DeckList.load_file(path, true)
	assert_eq(back.errors, [], "and it parses")
	assert_eq(back.cards.count("Lightning Bolt"), 3, "with every copy")
	assert_eq(back.deck_name, "Export Test", "and its name")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_export_writes_the_1997_file_the_original_game_opens() -> void:
	screen.deck.deck_name = "Dck Test"
	for _i in 2:
		screen._add_one("Mountain")
	screen._export_deck(".dck")
	var path := "%s/%s.dck" % [DeckStore.EXPORT_DIR,
		DeckStore.file_stem("Dck Test")]
	assert_true(FileAccess.file_exists(path))
	var back := DeckList.load_file(path, true)
	assert_eq(back.errors, [], "the MicroProse parser reads it back")
	assert_eq(back.cards.count("Mountain"), 2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_an_empty_deck_refuses_to_export() -> void:
	screen._export_deck(".dec")
	assert_string_contains(screen._status_label.text, "nothing to export")


# --------------------------------------------- [QoL] the extended stats --

func test_the_stats_window_graphs_more_than_the_matrix() -> void:
	screen._add_one("Mountain")
	screen._add_one("Lightning Bolt")
	screen._run_command("Stats")
	var titles := []
	for node in _walk(screen):
		if node is Label:
			titles.append(node.text)
	assert_true(titles.has("Card Type"), "@STATSSCREEN's matrix is still there")
	for heading in ["Casting costs", "Colors", "Card types", "Land"]:
		assert_true(titles.has(heading), "[QoL] the %s graph" % heading)
	var averages := 0
	for text in titles:
		if String(text).begins_with("Average casting cost"):
			averages += 1
	assert_eq(averages, 1, "[QoL] and the average")


# ------------------------------------------- [QoL] the Inventory badge --

func test_an_inventory_card_says_how_many_are_already_in_the_deck() -> void:
	var badged := func() -> int:
		var found := 0
		for cell in screen._inventory.cell_nodes():
			if cell.badge.visible:
				found += 1
		return found
	assert_eq(badged.call(), 0, "nothing in the deck yet")
	var first: String = screen._inventory.cell_nodes()[0].card_name
	screen._add_one(first)
	assert_eq(badged.call(), 1, "the card just added wears its count")
	assert_eq(screen._inventory.cell_nodes()[0].badge_label.text, "1")


func test_the_badge_costs_a_page_walk_and_never_a_pool_walk() -> void:
	# It has to follow the deck, and the audit pass's whole optimisation is
	# that the deck changing must not re-filter 800 cards.
	screen._refresh_inventory()
	var before := screen.filter_passes
	var first: String = screen._inventory.cell_nodes()[0].card_name
	for _i in 3:
		screen._add_one(first)
	assert_eq(screen.filter_passes, before, "the pool was not walked")
	assert_eq(screen._inventory.cell_nodes()[0].badge_label.text, "3",
		"but the badge is current")


# ----------------------------------------------------- [QoL] the search --

func test_the_type_ahead_can_reach_into_card_text() -> void:
	screen.filter.search_rules = true
	screen.filter.text = "regenerate"
	screen._refresh_inventory()
	assert_gt(screen._inventory.entry_count(), 0,
		"cards whose TEXT says regenerate, none of which is named it")
	screen.filter.search_rules = false
	screen._refresh_inventory()
	assert_eq(screen._inventory.entry_count(), 0,
		"and off, the box is the manual's name-only type-ahead again")


func test_the_count_line_says_where_in_the_list_you_are() -> void:
	assert_string_contains(screen._count_label.text, "cards are in the list")
	assert_string_contains(screen._count_label.text, "(1-",
		"[QoL] one row of nine is eighty-eight pages; say which one")


# ==================================================== SECOND AUDIT PASS ==
# 2026-08-31, after the restyle. Every test below failed before the fix
# that follows it in game/deck_builder/.

# ----------------------------------------------------- the modal layer --

func test_two_clicks_on_stats_do_not_open_two_windows() -> void:
	# `_open_mini_menu` guarded itself and five other openers did not, so a
	# second press of the Stats button — or of the Deck Header, or of Load
	# deck — put a second copy of the same dialog on the screen.
	screen._run_command("Stats")
	screen._run_command("Stats")
	assert_eq(screen.open_dialogs().size(), 1, "one Stats window")


func test_two_clicks_on_the_deck_header_do_not_open_two_dialogs() -> void:
	screen._open_deck_info()
	screen._open_deck_info()
	assert_eq(screen.open_dialogs().size(), 1, "@TITLEDIALOG, once")


func test_two_clicks_on_load_deck_do_not_open_two_lists() -> void:
	screen._run_command("Load deck")
	screen._run_command("Load deck")
	assert_eq(screen.open_dialogs().size(), 1, "@LOADDECKDIALOG, once")


func test_a_dialog_puts_a_blocker_over_the_card_surfaces() -> void:
	# OriginalDialog is a panel and draws no blocker, so every click that
	# MISSED the panel went through to whatever was under it: with the
	# Stats window open a right-click still took a column out of the deck.
	var scrims := func() -> Array:
		var found := []
		for child in screen.get_children():
			if child.name == "DialogScrim" and not child.is_queued_for_deletion():
				found.append(child)
		return found
	assert_eq(scrims.call().size(), 0, "nothing in the way to begin with")
	screen._run_command("Stats")
	var blockers: Array = scrims.call()
	assert_eq(blockers.size(), 1, "the dialog brought one")
	var scrim: Control = blockers[0]
	assert_eq(scrim.mouse_filter, Control.MOUSE_FILTER_STOP,
		"and it swallows the click")
	assert_eq(scrim.size, screen.size, "over the whole screen")
	assert_gt(screen.get_children().find(screen.open_dialogs()[0]),
		screen.get_children().find(scrim), "under the dialog, over everything else")
	screen._on_escape()
	await get_tree().process_frame
	assert_eq(scrims.call().size(), 0, "and it goes with the dialog")


# --------------------------------------------------- saving and leaving --

func test_answering_yes_to_save_really_saves_before_the_deck_is_thrown_away() -> void:
	# THE DATA-LOSS BUG. `Save deck` can stop to ask `@DECKEXISTS`, so
	# `_confirm_discard` called it, got nothing, and threw the deck away
	# anyway — the player answered "yes, save it" and the file never moved.
	# Confirming the overwrite afterwards then wrote whatever deck had
	# replaced it.
	screen.deck.deck_name = "Gut Save Then Discard"
	for _i in 5:
		screen._add_one("Mountain")
	screen._write_deck()                     # the file holds five
	screen._add_one("Lightning Bolt")        # six, and dirty
	screen._run_command("New deck")
	_answer("Yes")
	assert_eq(screen.open_dialogs().size(), 1, "@DECKEXISTS asks first")
	assert_eq(screen.deck.total(), 6, "and nothing has been thrown away yet")
	_answer("OK")
	var path := DeckStore.path_for("Gut Save Then Discard")
	var back := DeckList.load_file(path, true)
	assert_eq(back.cards.size(), 6, "the deck the player asked to save")
	assert_eq(screen.deck.total(), 0, "and only then the new one")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_cancelling_the_overwrite_keeps_the_deck() -> void:
	screen.deck.deck_name = "Gut Cancel Overwrite"
	screen._add_one("Mountain")
	screen._write_deck()
	screen._add_one("Lightning Bolt")
	screen._run_command("New deck")
	_answer("Yes")
	_answer("Cancel")
	assert_eq(screen.deck.count_of("Lightning Bolt"), 1,
		"a save that did not happen does not discard either")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(
		DeckStore.path_for("Gut Cancel Overwrite")))


func test_saving_an_unnamed_deck_does_not_discard_it() -> void:
	# `Save deck` on a deck still called `New Deck` sends the player to
	# Deck Info for a name (`@NAMEYOURDECK`) and saves nothing — so the
	# command that asked must not go on and throw the deck away.
	screen._add_one("Mountain")
	assert_eq(screen.deck.deck_name, DeckModel.DEFAULT_NAME, "@NEWDECK")
	screen._run_command("Load deck")
	assert_eq(screen.open_dialogs().size(), 1, "@SAVE asks first")
	_answer("Yes")
	assert_eq(screen.deck.count_of("Mountain"), 1, "still on the surface")
	assert_string_contains(screen._status_label.text, "You must name your deck")


func test_leaving_asks_about_every_slot_that_has_unsaved_work() -> void:
	# The slots let a player keep three decks in hand and `Exit deck
	# builder` threw two of them away without a word — every prompt on this
	# screen only ever looked at the deck it could see.
	screen._switch_slot(1)
	screen.deck.deck_name = "Gut Slot Two"
	screen._add_one("Mountain")
	screen._switch_slot(0)
	assert_eq(screen.deck.total(), 0, "Deck1 is empty and untouched")
	screen._run_command("Exit deck builder")
	assert_eq(screen.open_dialogs().size(), 1, "@SAVE, about Deck2")
	assert_eq(screen._slot, 1, "and Deck2 is on the surface so it can be seen")
	_answer("Cancel")
	assert_eq(screen.deck.count_of("Mountain"), 1, "Cancel keeps everything")


func test_an_answered_slot_is_not_asked_about_twice() -> void:
	screen._switch_slot(2)
	screen.deck.deck_name = "Gut Slot Three"
	screen._add_one("Mountain")
	screen._switch_slot(1)
	screen.deck.deck_name = "Gut Slot Two Again"
	screen._add_one("Forest")
	screen._run_command("Exit deck builder")
	_answer("No")
	assert_eq(screen.open_dialogs().size(), 1, "the other slot's turn")
	_answer("Cancel")
	assert_eq(screen.open_dialogs().size(), 0, "and Cancel ends the walk")


# ------------------------------------------------------------ the undo --

func test_a_refused_change_does_not_eat_the_undo_step() -> void:
	# `_remember` ran BEFORE the mutation, so a refusal — a fifth copy in a
	# full deck, a Remove with nothing to remove — snapshotted the deck
	# anyway and quietly replaced the step the player wanted back.
	for _i in 4:
		screen._add_one("Lightning Bolt")
	screen._remove_all("Lightning Bolt")
	screen._remove_one("Lightning Bolt")     # refused: there are none
	screen._add_one("Not A Card At All")     # refused: not in the pool
	screen._run_command("Undo")
	assert_eq(screen.deck.count_of("Lightning Bolt"), 4,
		"the right-click is still the thing that comes back")


func test_the_menu_says_what_undo_would_put_back() -> void:
	# `_undo_label` was written by every mutation and read by nothing.
	for _i in 3:
		screen._add_one("Lightning Bolt")
	screen._remove_all("Lightning Bolt")
	screen._open_mini_menu()
	assert_true(_button_texts().has("Undo Remove all Lightning Bolt  [QoL]"),
		"the menu names the change, not just the word")


func test_a_playset_that_is_partly_refused_reports_and_undoes_what_it_did() -> void:
	screen.deck.counts["Mountain"] = DeckModel.MAX_TOTAL - 2
	screen._inventory.card_bulk.emit("Lightning Bolt")
	assert_eq(screen.deck.count_of("Lightning Bolt"), 2, "two fitted")
	assert_string_contains(screen._status_label.text, "Added 2")
	screen._run_command("Undo")
	assert_eq(screen.deck.count_of("Lightning Bolt"), 0, "and both come back out")


# ------------------------------- the two recovered 1997 commands --

func test_extra_cards_removes_what_shandalar_will_not_allow() -> void:
	# `@EXTRACARDSDIALOG` — "Extra Cards / There are too many of the
	# following Cards in your deck. / Remove Extra Cards / Edit Deck".
	# The screen said the sentence and could not act on it.
	for _i in 40:
		screen._add_one("Mountain")          # basics are exempt
	for _i in 7:
		screen._add_one("Lightning Bolt")    # a 47-card deck allows three
	assert_eq(DeckModel.duplicates_allowed(screen.deck.total()), 3)
	screen._run_command("Extra Cards")
	var texts := _button_texts()
	assert_true(texts.has("Remove Extra Cards"), "@EXTRACARDSDIALOG's own button")
	assert_true(texts.has("Edit Deck"), "and its other one")
	_answer("Remove Extra Cards")
	assert_eq(screen.deck.count_of("Lightning Bolt"), 3, "cut to the allowance")
	assert_eq(screen.deck.count_of("Mountain"), 40, "basics are never cut")
	screen._run_command("Undo")
	assert_eq(screen.deck.count_of("Lightning Bolt"), 7, "one undo step")


func test_extra_cards_says_so_when_there_are_none() -> void:
	for _i in 40:
		screen._add_one("Mountain")
	screen._run_command("Extra Cards")
	var said := false
	for node in _walk(screen.open_dialogs()[0]):
		if node is Label and String(node.text).contains("No card is over"):
			said = true
	assert_true(said, "the dialog answers rather than showing an empty list")


func test_move_by_color_takes_a_whole_colour_out_of_the_deck() -> void:
	# `@DECKSURFACE_ADVENTURE`'s "Move by color out of deck" through
	# `@GROUPMOVE`'s "Select Which Color(s) to Move".
	for _i in 4:
		screen._add_one("Lightning Bolt")
	for _i in 4:
		screen._add_one("Giant Growth")
	for _i in 10:
		screen._add_one("Mountain")
	screen._move_out_by_color([Mtg.ManaColor.R])
	assert_eq(screen.deck.count_of("Lightning Bolt"), 0, "the red went")
	assert_eq(screen.deck.count_of("Giant Growth"), 4, "the green stayed")
	assert_eq(screen.deck.count_of("Mountain"), 10,
		"and a land has no colour — @GROUPMOVE offers no Land option")
	screen._run_command("Undo")
	assert_eq(screen.deck.count_of("Lightning Bolt"), 4, "one undo step")


func test_the_group_move_dialog_offers_the_1997_six() -> void:
	screen._run_command("Move by color out of deck")
	var texts := _button_texts()
	for entry in DeckBuilderScreen.GROUP_MOVE:
		assert_true(texts.has("[  ] %s" % String(entry[0])),
			"@GROUPMOVE: %s" % String(entry[0]))


# ------------------------------------------- @LONGLIST's Select / Clear --

func test_the_filter_strip_offers_select_all_and_clear_all() -> void:
	# `@LONGLIST` — "Enable Filter / Select All / Clear All". The strip has
	# twenty-three toggles and had no way back from them: "show me only
	# white creatures" cost twenty-one clicks.
	var seen := []
	screen._filter_bar.menu_requested.connect(func(request: Dictionary) -> void:
		seen.append(request))
	screen._filter_bar.open_all_menu()
	assert_eq(seen.size(), 1)
	assert_eq(seen[0]["lines"], FilterBar.ALL_MENU, "the table's own two words")
	seen[0]["pick"].call(1)                  # Clear All
	screen._refresh_inventory()
	assert_eq(screen._inventory.entry_count(), 0, "every medallion is up")
	# TWO CLICKS, and it really is two now: this test used to put all eight
	# SET medallions back by hand to make the line below pass, which is the
	# defect the third audit pass found written down in its own pinning
	# test. `Clear All` leaves the set group alone — see DeckFilter.
	screen.filter.toggle_color(Mtg.ManaColor.W)
	screen.filter.toggle_type(Mtg.CardType.CREATURE)
	screen._refresh_inventory()
	assert_gt(screen._inventory.entry_count(), 0, "two clicks make a white run")
	seen[0]["pick"].call(0)                  # Select All
	screen._refresh_inventory()
	assert_eq(screen._inventory.entry_count(), CardRegistry.size(),
		"and one puts the whole pool back")


func test_a_right_click_on_a_plain_medallion_opens_that_menu() -> void:
	# The manual promises a mini-menu on "some of the filter buttons"; the
	# ones that have none of their own carry `@LONGLIST`'s instead, which
	# is what makes Select All reachable from the strip itself.
	var seen := []
	screen._filter_bar.menu_requested.connect(func(request: Dictionary) -> void:
		seen.append(request))
	var white: Button = screen._filter_bar.group_buttons("Color Filters")[0]
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	white.gui_input.emit(click)
	assert_eq(seen.size(), 1, "the medallion answered a right-click")
	assert_eq(seen[0]["title"], "Filters")


func test_the_recovered_1997_commands_are_on_the_mini_menu_unmarked() -> void:
	screen._open_mini_menu()
	var texts := _button_texts()
	for label in DeckBuilderScreen.MENU_COMMANDS:
		assert_true(texts.has(label),
			"%s is reachable, and unmarked because 1997 had it" % label)
	assert_true(texts.has("Filters  [QoL]"),
		"@LONGLIST's words on a strip the original gave no such button")


func test_every_menu_line_fits_inside_the_dialog() -> void:
	# The menu grew from twelve entries to fourteen and a fixed height put
	# the last two under the Cancel button.
	screen._open_mini_menu()
	var dialog := screen.open_dialogs()[0]
	await get_tree().process_frame
	var lines := 0
	for node in _walk(dialog):
		if node is Button and node.text != "Cancel":
			lines += 1
			assert_lte(node.global_position.y + node.size.y,
				dialog.global_position.y + dialog.size.y,
				"'%s' is inside the panel" % node.text)
	assert_eq(lines, screen._command_labels().size(), "every command is drawn")


# ------------------------------------------------ the type-ahead's Esc --

func test_escape_clears_the_type_ahead_before_it_leaves() -> void:
	# The box is on Ctrl+F and Escape walked straight past it into the
	# save prompt for leaving the screen.
	screen.filter.text = "bolt"
	screen._refresh_inventory()
	screen._on_escape()
	assert_eq(screen.filter.text, "", "the box emptied")
	assert_eq(screen._inventory.entry_count(), CardRegistry.size(),
		"and the Inventory is the whole pool again")
	assert_eq(screen.open_dialogs().size(), 0, "nothing is leaving yet")


# --------------------------------------------------------- the 1997 skin --

func test_no_dialog_wears_a_bare_godot_widget() -> void:
	# A SpinBox with Godot's own chrome in the middle of a 1997 dialog is a
	# defect on this screen. `OriginalDialog.field` is the era's sunken box.
	for command in ["Add basic land"]:
		screen._run_command(command)
		for node in _walk(screen.open_dialogs()[0]):
			if node is SpinBox:
				assert_true(node.get_line_edit().has_theme_stylebox_override("normal"),
					"%s's number field is dressed" % command)
		screen._on_escape()
		await get_tree().process_frame


func test_the_load_list_names_the_deck_and_its_size() -> void:
	# [QoL] The 1997 list could only show an eight-character DOS file name.
	# Ours carry a title and a count, and a player with a dozen saved decks
	# should not have to load one to find out which it is.
	var line := DeckStore.describe(DeckStore.deck_paths_in(DeckStore.SHIPPED_DIR)[0])
	assert_string_contains(line, "cards")
	assert_true(line.ends_with(".deck"), "and it still names the file")
	screen._run_command("Load deck")
	var named := 0
	for text in _button_texts():
		if String(text).contains(" cards · "):
			named += 1
	assert_gt(named, 0, "the dialog uses it")


# --------------------------------------------- [QoL] forking a deck slot --

func test_copy_deck_to_forks_the_deck_into_another_slot() -> void:
	# The slots were shipped for "trying a variant" and could not start one
	# from the deck you had: a variant meant forty cards again, or a save,
	# a load and a rename.
	screen.deck.deck_name = "Gut Original"
	for _i in 4:
		screen._add_one("Lightning Bolt")
	screen._copy_deck_to(1)
	assert_eq(screen.deck.deck_name, "Gut Original", "the surface is unchanged")
	screen._switch_slot(1)
	assert_eq(screen.deck.count_of("Lightning Bolt"), 4, "the copy came over")
	assert_eq(screen.deck.deck_name, "Gut Original (copy)",
		"and it is named so Save cannot overwrite the original by accident")
	screen._add_one("Mountain")
	screen._switch_slot(0)
	assert_eq(screen.deck.count_of("Mountain"), 0,
		"the two are separate models, not one shared by both slots")


func test_the_copy_dialog_offers_the_other_two_slots() -> void:
	screen._add_one("Mountain")
	screen._run_command("Copy deck to")
	var texts := _button_texts()
	assert_true(texts.has("Deck2"), "@DECKNUMBERS")
	assert_true(texts.has("Deck3"))
	for text in texts:
		assert_false(String(text).begins_with("Deck1"), "never the slot you are in")


func test_an_empty_deck_has_nothing_to_copy() -> void:
	screen._run_command("Copy deck to")
	assert_eq(screen.open_dialogs().size(), 0)
	assert_string_contains(screen._status_label.text, "nothing to copy")


# ------------------------------------------ [QoL] the complaint is a door --

func test_clicking_the_legality_line_opens_what_answers_it() -> void:
	# It was inert text, and it is the only place this screen ever complains.
	screen._legality_label.pressed.emit()
	assert_eq(screen.open_dialogs().size(), 1, "a short deck opens Stats")
	assert_string_contains(screen.open_dialogs()[0].get_child(1).get_child(0).text,
		"Stats")
	screen._on_escape()
	await get_tree().process_frame
	for _i in 40:
		screen._add_one("Mountain")
	for _i in 7:
		screen._add_one("Lightning Bolt")
	assert_false(deck_advice(screen).is_empty(), "now Shandalar complains")
	screen._legality_label.pressed.emit()
	assert_true(_button_texts().has("Remove Extra Cards"),
		"and the line opens the dialog that can fix it")


func deck_advice(s: DeckBuilderScreen) -> Array:
	return s.deck.over_duplicate_limit()


func test_the_legality_line_never_grows_the_left_column() -> void:
	# It is a Button now, and a wrapping Button grows its container rather
	# than trimming — which would push the left column into the Filter strip.
	for _i in 40:
		screen._add_one("Mountain")
	for name in ["Lightning Bolt", "Giant Growth", "Elvish Archers",
			"Grizzly Bears", "Craw Wurm"]:
		for _i in 8:
			screen._add_one(name)
	await get_tree().process_frame
	assert_lte(screen._legality_label.text.length(),
		DeckBuilderScreen.LEGALITY_CHARS, "the line is clipped")
	assert_gt(screen._legality_label.tooltip_text.length(),
		screen._legality_label.text.length(), "with the whole of it on the cue card")
	assert_lt(screen._left_column.position.y + screen._left_column.size.y,
		screen._filter_bar.position.y, "and the column still clears the strip")


# ------------------------------------------- paging, limits and geometry --

func test_every_page_shows_exactly_the_cards_its_offset_names() -> void:
	# The rotation only reorders the widget array; the binding must still be
	# `entries[offset + i]` for every slot, on every page, in both flows.
	var areas: Array[CardArea] = [screen._inventory, screen._deck_area]
	for area in areas:
		if area == screen._deck_area:
			for card_name in ["Mountain", "Forest", "Island", "Plains", "Swamp"]:
				for _i in 9:
					screen._add_one(card_name)
		var shown: Array = area._visible_entries()
		if shown.size() <= area.page_size():
			continue
		for hop in [1, 3, -2, 40, -40]:
			area.scroll_by(hop)
			var cells: Array[CardArea.Cell] = area.cell_nodes()
			for i in cells.size():
				var wanted: CardData = shown[area.offset() + i][0]
				assert_eq(cells[i].card_name, wanted.card_name,
					"slot %d of the page at offset %d" % [i, area.offset()])


func test_the_end_of_the_list_is_reachable_and_leaves_nothing_behind() -> void:
	var area: CardArea = screen._inventory
	area.scroll_to_end()
	assert_eq(area.offset(), area.max_offset())
	var cells := area.cell_nodes()
	assert_gt(cells.size(), 0, "the last page is not empty")
	assert_eq(cells[-1].card_name,
		area._visible_entries()[area.offset() + cells.size() - 1][0].card_name,
		"and its last slot is the list's last card")
	area.home()
	assert_eq(area.offset(), 0)
	assert_eq(area.cell_nodes()[0].card_name,
		area._visible_entries()[0][0].card_name, "and Home really goes home")


func test_the_two_1997_deck_limits_refuse_at_the_screen() -> void:
	# `@TOOMANYCARDS`: "The duel allows 200 unique cards - 500 total."
	var pool := CardRegistry.all_names()
	for i in DeckModel.MAX_UNIQUE:
		screen.deck.counts[pool[i]] = 1
	assert_eq(screen.deck.unique(), DeckModel.MAX_UNIQUE)
	assert_false(screen._add_one(pool[DeckModel.MAX_UNIQUE]),
		"the 201st distinct card is refused")
	assert_string_contains(screen._status_label.text, "too many cards")
	assert_true(screen._add_one(pool[0]), "but a copy of one already in fits")
	screen.deck.counts[pool[0]] = DeckModel.MAX_TOTAL
	assert_false(screen._add_one(pool[1]), "and the 501st card is refused")


func test_the_regions_do_not_overlap_at_either_window_height() -> void:
	# The restyle stacks five regions bottom-up and the left column's
	# height depends on how much the deck is complaining about.
	for name in ["Mountain", "Lightning Bolt", "Giant Growth"]:
		for _i in 9:
			screen._add_one(name)
	for height in [800.0, 720.0]:
		screen.size = Vector2(1280.0, height)
		await get_tree().process_frame
		var deck_rect := screen._deck_rect()
		var inv := screen._inventory_rect()
		assert_gt(deck_rect.size.y, 0.0, "the deck area has room at %d" % height)
		assert_lte(screen._command_row.position.y + DeckBuilderScreen.COMMAND_BAR_H,
			screen._filter_bar.position.y, "command bar clears the strip at %d" % height)
		assert_lte(screen._filter_bar.position.y + screen._filter_bar.size.y,
			inv.position.y, "the strip clears the Inventory at %d" % height)
		assert_lte(inv.position.y + inv.size.y, height, "and the Inventory fits")
		assert_lte(screen._left_column.position.y + screen._left_column.size.y,
			screen._filter_bar.position.y,
			"the left column clears the strip at %d" % height)
		assert_lte(screen._filter_bar.get_combined_minimum_size().x, 1280.0,
			"and twenty-three medallions plus the tail still fit 1280")


# ============================================================ THIRD PASS ==
# Six defects, each of them found by driving the restyled screen again and
# each pinned by the test below it, which failed before its fix.

## `Clear All` raised the SET filters too, and a strip with every set up
## shows nothing whatever else is pressed — so the very workflow the
## command shipped for ("show me only white creatures": Clear All, White,
## Creatures) produced an empty Inventory, with no cue saying which of the
## twenty-three buttons was responsible.
func test_clear_all_leaves_a_strip_that_can_still_show_cards() -> void:
	screen.filter.clear_all()
	screen._refresh_inventory()
	assert_eq(screen._inventory.entry_count(), 0,
		"Clear All on its own shows nothing, as the 1997 polarity says")
	screen.filter.colors[Mtg.ManaColor.W] = true
	screen.filter.types[Mtg.CardType.CREATURE] = true
	screen.filter.revision += 1
	screen._refresh_inventory()
	assert_gt(screen._inventory.entry_count(), 0,
		"Clear All, White, Creatures — the three clicks the command shipped for")
	for d in screen.filter.apply(screen._pool):
		assert_true(d.is_creature(), "%s is a creature" % d.card_name)
		assert_true(d.color_mask() & Mtg.ManaColor.W or d.color_mask() == 0,
			"%s is white" % d.card_name)


## `_confirm_discard` was the one dialog opener with no one-at-a-time
## guard, so `Load deck`, `New deck` and `Done` could each stack a second
## `@SAVE` prompt on the first — reachable with the keyboard, because the
## scrim under a dialog stops the MOUSE and a command-bar button that
## still holds focus answers the space bar.
func test_a_second_save_prompt_cannot_stack_on_the_first() -> void:
	screen._add_one("Lightning Bolt")
	screen._open_load_dialog()
	assert_eq(screen.open_dialogs().size(), 1, "@SAVE is up")
	screen._open_load_dialog()
	screen._new_deck()
	screen._exit()
	assert_eq(screen.open_dialogs().size(), 1,
		"and every other way in is refused while it is")


## The Inventory's `(1-9)` counts the cards ON SCREEN, and a resize changes
## how many that is. `_rebuild` can also clamp the offset. Neither emitted
## `scrolled`, so the line went on naming a page the player was not
## looking at.
func test_the_count_line_follows_a_resize() -> void:
	screen.size = Vector2(1280, 800)
	await get_tree().process_frame
	assert_string_contains(screen._count_label.text,
		"(1-%d)" % screen._inventory.page_size(), "the range at 1280")
	screen.size = Vector2(1024, 600)
	await get_tree().process_frame
	assert_string_contains(screen._count_label.text,
		"(1-%d)" % screen._inventory.page_size(),
		"and the range after the window narrows")


## `New deck` left the PREVIOUS deck armed on `Restore deck`: the mini-menu
## still read `Restore deck`, and pressing it threw the new deck away for
## one cleared before it existed. `Load deck` and the slot switch both
## already cleared it.
func test_a_new_deck_has_nothing_to_restore() -> void:
	screen._add_one("Lightning Bolt")
	screen._clear_deck()
	assert_true(screen._command_labels().has("Restore deck"),
		"a cleared deck can be restored")
	screen._new_deck()
	assert_eq(screen._cleared, null, "a new deck has nothing to restore")
	assert_false(screen._command_labels().has("Restore deck"),
		"and the mini-menu does not offer to")
	assert_eq(screen._clear_button.text, "Clear deck")


## `Undo` is about the CARDS. It also reset `_sorted`, so undoing one card
## threw the deck area back into insertion order and `Sort deck` had to be
## pressed again.
func test_undo_does_not_undo_the_sort() -> void:
	for card_name in ["Lightning Bolt", "Mountain", "Giant Growth"]:
		screen._add_one(card_name)
	screen._sort_deck()
	screen._add_one("Island")
	screen._undo_last()
	assert_true(screen._sorted, "the deck is still sorted")
	assert_eq(screen._deck_area.cell_nodes()[0].card_name,
		screen.deck.names()[0], "and the area still shows that order")


## ONE CARD SIZE, EVERYWHERE (MiniCard.SIZE's own rule, which names "the
## deck builder's grid"). The deck area used to draw its faces at 0.85 —
## a second card size on the one screen that shows two surfaces at once.
func test_both_surfaces_draw_cards_at_the_one_size() -> void:
	screen._add_one("Lightning Bolt")
	var areas: Array[CardArea] = [screen._deck_area, screen._inventory]
	for area in areas:
		assert_eq(area._cell, MiniCard.SIZE, "%s cell" % area.source_name)
		for cell in area.cell_nodes():
			assert_eq(cell.face.size, MiniCard.SIZE,
				"%s: %s size" % [area.source_name, cell.card_name])
			assert_eq(cell.face.scale, Vector2.ONE,
				"%s: %s is not rescaled" % [area.source_name, cell.card_name])
			assert_eq(cell.face.rotation_degrees, 0.0,
				"%s: %s is not turned" % [area.source_name, cell.card_name])


## *"Whatever card the mouse cursor is hovering over is displayed"* — and
## the wheel moves the cards under a cursor that has not moved. Nothing
## re-emitted `card_hovered` for the cell being rebound under the pointer,
## so one notch left the Showcase displaying a card that was no longer
## anywhere near it.
func test_the_showcase_follows_the_wheel_under_a_still_pointer() -> void:
	var seen: Array[String] = []
	screen._inventory.card_hovered.connect(func(d: CardData) -> void:
		seen.append(d.card_name))
	var cell: CardArea.Cell = screen._inventory.cell_nodes()[0]
	cell.mouse_entered.emit()
	assert_eq(seen.size(), 1, "the pointer arrived on a card")
	screen._inventory.scroll_by(1)
	var now: String = screen._inventory.cell_nodes()[0].card_name
	assert_eq(seen.size(), 2, "and the card that scrolled under it is shown")
	assert_eq(seen[-1], now, "which is the one now in that slot")
	cell.mouse_exited.emit()
	screen._inventory.scroll_by(1)
	assert_eq(seen.size(), 2, "with the pointer away, the wheel says nothing")


## `Save deck` on a deck still called `New Deck` says `@NAMEYOURDECK` and
## opens `Deck Info` for a name — and then dropped the save on the floor.
## The player named the deck, pressed OK, and nothing happened: no file, no
## message, and a status line still reading "You must name your deck before
## saving." The command dead-ended halfway through, which is also the
## `@SAVE` "Yes" path for an unnamed deck.
func test_naming_a_deck_finishes_the_save_it_was_asked_for() -> void:
	screen._add_one("Lightning Bolt")
	var carried_on := []
	screen._save_deck(func() -> void: carried_on.append("then"))
	assert_eq(screen.open_dialogs().size(), 1, "Deck Info is asking for a name")
	assert_string_contains(screen._status_label.text, "name your deck")
	for node in _walk(screen.open_dialogs()[-1]):
		if node is LineEdit:
			node.text = "Third Pass Named"
	_answer("OK")
	await get_tree().process_frame
	var path := DeckStore.path_for("Third Pass Named")
	assert_true(FileAccess.file_exists(path), "the deck really reached disk")
	assert_eq(carried_on.size(), 1,
		"and whatever was waiting on the save ran once it had")
	assert_false(screen._dirty, "the deck is saved, so it is not dirty")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## An OK that does NOT name the deck must not pretend the save happened.
func test_cancelling_the_name_leaves_the_deck_unsaved() -> void:
	screen._add_one("Lightning Bolt")
	var carried_on := []
	screen._save_deck(func() -> void: carried_on.append("then"))
	_answer("Cancel")
	await get_tree().process_frame
	assert_eq(carried_on.size(), 0, "nothing was saved, so nothing carried on")
	assert_eq(screen.deck.deck_name, DeckModel.DEFAULT_NAME)
	assert_eq(screen.deck.count_of("Lightning Bolt"), 1, "and the deck is intact")


# ================================== THIRD AUDIT PASS (2026-09-01) ==
# THE SIDEBOARD SURFACE. The ROADMAP's objection to building one — *"the
# screen would have been editing a field nothing reads"* — died when
# `Side&board between duels` started playing the `SB:` lines between the
# duels of a best-of-N match. What is pinned here is the owner's own three
# requirements: the pile is VISIBLY separate, cards move BOTH ways, and
# copies are counted across both piles.

func _sideboard_area() -> CardArea:
	return screen._sideboard_area


func test_the_sideboard_is_a_surface_of_its_own() -> void:
	var strip := _sideboard_area()
	assert_not_null(strip, "the third card surface exists")
	assert_ne(strip, screen._deck_area)
	assert_eq(strip.source_name, "sideboard", "so a drop can tell the piles apart")
	# CUE 1, the grid: it is below the deck area and does not overlap it.
	assert_gt(strip.position.y, screen._deck_area.position.y)
	assert_lte(screen._deck_area.position.y + screen._deck_area.size.y,
		strip.position.y, "the deck area stops where the strip starts")
	# ...and the command bar is BELOW it, not through it. The bar took its
	# position from the deck area, so carving the strip out of the deck
	# area's bottom put the bar straight across the strip's top row and
	# hid every `SB` tag behind it. A screenshot caught that; this is the
	# test that keeps it caught.
	assert_gte(screen._command_row.position.y, strip.position.y + strip.size.y,
		"the command bar closes the strip rather than crossing it")
	assert_lte(screen._command_row.position.y + DeckBuilderScreen.COMMAND_BAR_H,
		screen._filter_bar.position.y, "and still clears the Filter strip")
	# CUE 2, the count: its own heading, and the deck's own numbers line.
	screen._add_one_side("Shatter")
	assert_string_contains(strip.title, "Sideboard")
	assert_string_contains(strip.title, "1")
	assert_string_contains(screen._stats_label.text, "Sideboard: 1")
	# CUE 3, the card: every tile in this area is tagged, and no tile in
	# the deck area is.
	assert_eq(strip.corner_tag, "SB")
	assert_eq(screen._deck_area.corner_tag, "")
	var tagged := 0
	for cell in strip.cell_nodes():
		if cell.tag != null and cell.tag.visible:
			tagged += 1
	assert_eq(tagged, 1, "the card in the sideboard wears its tag")
	for cell in screen._deck_area.cell_nodes():
		assert_false(cell.tag.visible, "and a deck card wears none")


func test_the_strip_shows_the_sideboard_and_not_the_deck() -> void:
	screen._add_one("Lightning Bolt")
	screen._add_one_side("Shatter")
	var on_strip := []
	for cell in _sideboard_area().cell_nodes():
		on_strip.append(cell.card_name)
	assert_eq(on_strip, ["Shatter"])
	var in_deck := []
	for cell in screen._deck_area.cell_nodes():
		in_deck.append(cell.card_name)
	assert_eq(in_deck, ["Lightning Bolt"])


func test_a_card_moves_both_ways_between_the_piles() -> void:
	screen._add_one("Lightning Bolt")
	screen._move_to_sideboard("Lightning Bolt")
	assert_eq(screen.deck.count_of("Lightning Bolt"), 0)
	assert_eq(screen.deck.side_count_of("Lightning Bolt"), 1)
	screen._move_to_deck("Lightning Bolt")
	assert_eq(screen.deck.count_of("Lightning Bolt"), 1)
	assert_eq(screen.deck.side_count_of("Lightning Bolt"), 0)


func test_shift_click_is_the_one_handed_route_across() -> void:
	# The signal each surface emits on SHIFT-click, read as the same
	# sentence on all three: "send this one to the other pile".
	screen._inventory.card_shifted.emit("Shatter")
	assert_eq(screen.deck.side_count_of("Shatter"), 1, "Inventory -> sideboard")
	screen._add_one("Lightning Bolt")
	screen._deck_area.card_shifted.emit("Lightning Bolt")
	assert_eq(screen.deck.side_count_of("Lightning Bolt"), 1, "deck -> sideboard")
	_sideboard_area().card_shifted.emit("Lightning Bolt")
	assert_eq(screen.deck.count_of("Lightning Bolt"), 1, "sideboard -> deck")


func test_a_drop_means_what_the_source_says_it_means() -> void:
	# Three surfaces, so the source decides: dropping a sideboard card on
	# the deck MOVES it, dropping it on the Inventory throws it away.
	screen._add_one_side("Shatter")
	screen._dropped_on_deck("Shatter", "sideboard")
	assert_eq(screen.deck.count_of("Shatter"), 1)
	assert_eq(screen.deck.side_count_of("Shatter"), 0)
	screen._dropped_on_sideboard("Shatter", "deck")
	assert_eq(screen.deck.side_count_of("Shatter"), 1)
	assert_eq(screen.deck.count_of("Shatter"), 0)
	screen._dropped_on_inventory("Shatter", "sideboard")
	assert_eq(screen.deck.side_total(), 0, "dragged back to the pool, and gone")
	screen._dropped_on_sideboard("Terror", "inventory")
	assert_eq(screen.deck.side_count_of("Terror"), 1, "and the pool fills it")


func test_a_sideboard_change_is_one_undo_step() -> void:
	screen._add_one_side("Shatter")
	screen._add_one_side("Shatter")
	screen._remove_all_side("Shatter")
	assert_eq(screen.deck.side_total(), 0)
	screen._run_command("Undo")
	assert_eq(screen.deck.side_count_of("Shatter"), 2,
		"Undo puts the sideboard back, not just the deck")


func test_clicking_a_sideboard_card_takes_one_copy_out() -> void:
	screen._add_one_side("Shatter")
	screen._add_one_side("Shatter")
	_sideboard_area().card_activated.emit("Shatter")
	assert_eq(screen.deck.side_count_of("Shatter"), 1, "one copy, like the deck area")
	_sideboard_area().card_bulk.emit("Shatter")
	assert_eq(screen.deck.side_count_of("Shatter"), 0, "right-click takes the stack")


func test_the_legality_line_states_the_sideboard_size_rule() -> void:
	for _i in 40:
		screen._add_one("Mountain")
	for _i in DeckModel.SIDEBOARD_SIZE + 1:
		screen._add_one_side("Shatter")
	assert_string_contains(screen._legality_label.tooltip_text, "sideboard")
	assert_string_contains(screen._legality_label.tooltip_text, "Fifteen")
	assert_string_contains(screen._legality_label.tooltip_text, "modern Magic")


func test_the_sideboard_menu_says_how_and_moves_in_bulk() -> void:
	assert_true(DeckBuilderScreen.EXTRA_COMMANDS.has("Sideboard"),
		"it is on the mini-menu, marked [QoL] like every addition")
	for _i in 3:
		screen._add_one_side("Shatter")
	screen._run_command("Sideboard")
	var said := ""
	for node in _walk(screen.open_dialogs()[-1]):
		if node is Label:
			said += node.text + " "
	assert_string_contains(said, "Shift-click")
	assert_string_contains(said, "modern Magic")
	_answer("Done")
	await get_tree().process_frame
	screen._sideboard_bulk(true)
	assert_eq(screen.deck.count_of("Shatter"), 3, "the whole pile crossed over")
	assert_eq(screen.deck.side_total(), 0)
	screen._run_command("Undo")
	assert_eq(screen.deck.side_total(), 3, "in one undo step")


func test_consolidate_answers_for_both_piles_at_once() -> void:
	# One command about how duplicates are DISPLAYED. Grouping one pile
	# and splitting the other would be answering it twice.
	screen._add_one_side("Shatter")
	screen._add_one_side("Shatter")
	assert_eq(_sideboard_area().cell_nodes().size(), 1, "grouped to start")
	screen._run_command("Consolidate duplicate cards")
	assert_false(screen._deck_area.consolidated)
	assert_false(_sideboard_area().consolidated, "the strip followed")
	assert_eq(_sideboard_area().cell_nodes().size(), 2, "two faces now")


func test_the_stats_window_names_the_deck_type() -> void:
	# The one thing the 1997 Stats window showed that ours did not:
	# MicroProse's own ManaLink 1.3 readme, "the Deck Builder displays your
	# deck name and deck type ... in the title bar when you click the Stats
	# button". It counts the sideboard, because DeckFormat.legal does.
	screen._add_one("Black Lotus")
	screen._run_command("Stats")
	var said := ""
	for node in _walk(screen.open_dialogs()[-1]):
		if node is Label:
			said += node.text + " "
	assert_string_contains(said, "Deck type:")
	assert_string_contains(said, DeckFormat.HIGHLANDER, "one of each so far")
	_answer("OK")
	await get_tree().process_frame


func test_a_loaded_deck_keeps_its_sideboard_on_the_surface() -> void:
	# The whole point of Step 2 seen from the screen: open a shipped deck
	# and its fifteen sideboard cards are ON the strip, not lost.
	var path := DeckStore.deck_paths_in(DeckStore.SHIPPED_DIR)[0]
	screen._load_deck(path)
	assert_eq(screen.deck.side_total(), 15, "%s's sideboard came in" % path)
	assert_ne(screen.deck.group, "", "and so did its `# group:` line")
	assert_string_contains(_sideboard_area().title, "15")


# ============================ [QoL] IMPORT AND PROXIES (2026-09-01) ==
# `Import deck` reads a deck from anywhere, in any of the three formats,
# with every name this game does not implement becoming a [ProxyCard];
# `Add proxy card` is the deliberate stand-in. Both end in the same
# `DeckModel.add_proxy`, and the surfaces draw both with a [ProxyFace] —
# card-shaped, card-sized, plain paper, `proxy` where the rules go.

const NOT_A_CARD := "Zzz Notional Behemoth"


func _proxy_faces() -> Array:
	var found := []
	for node in _walk(screen):
		if node is ProxyFace:
			found.append(node)
	return found


func test_add_proxy_card_puts_the_stand_in_in_the_deck() -> void:
	screen._add_proxy(NOT_A_CARD, 3)
	assert_eq(screen.deck.count_of(NOT_A_CARD), 3)
	assert_eq(screen.deck.proxy_names(), [NOT_A_CARD] as Array[String])
	assert_string_contains(screen._status_label.text, "proxy")


func test_add_proxy_card_refuses_a_card_we_actually_have() -> void:
	# If the card is implemented there is nothing to stand in for, and the
	# real card is one click away in the Inventory.
	screen._add_proxy("Lightning Bolt", 1)
	assert_eq(screen.deck.total(), 0, "nothing was added")
	assert_string_contains(screen._status_label.text, "in the card pool")


func test_add_proxy_card_refuses_a_nameless_proxy() -> void:
	screen._add_proxy("", 4)
	assert_eq(screen.deck.total(), 0)
	assert_string_contains(screen._status_label.text, "needs a name")


func test_adding_proxies_is_one_undo_step() -> void:
	screen._add_proxy(NOT_A_CARD, 4)
	assert_eq(screen.deck.count_of(NOT_A_CARD), 4)
	screen._undo_last()
	assert_eq(screen.deck.count_of(NOT_A_CARD), 0, "all four, in one step")


func test_the_proxy_dialog_offers_a_name_and_a_number() -> void:
	screen._run_command("Add proxy card")
	assert_eq(screen.open_dialogs().size(), 1)
	var lines := 0
	var spins := 0
	for node in _walk(screen):
		if node is LineEdit:
			lines += 1
		elif node is SpinBox:
			spins += 1
	assert_gt(lines, 0, "somewhere to type the name")
	assert_gt(spins, 0, "and how many")


func test_a_proxy_in_the_deck_is_drawn_as_paper_not_as_a_card() -> void:
	# The bug this catches is invisible to a count: a proxy the deck area
	# could not build a MiniCard for used to be SKIPPED, so it was a card
	# in the deck that the player could not see and could not remove.
	screen._add_proxy(NOT_A_CARD, 2)
	screen.refresh()
	var faces := _proxy_faces()
	assert_gt(faces.size(), 0, "the deck area drew a proxy face")
	var drawn: ProxyFace = null
	for face in faces:
		if (face as ProxyFace).proxy_name == NOT_A_CARD:
			drawn = face
	assert_not_null(drawn, "and it is the card we put in")
	assert_eq(drawn.size, MiniCard.SIZE, "at the one card size")
	assert_eq(drawn.scale, Vector2.ONE, "never rescaled")


func test_the_deck_area_shows_a_proxy_beside_a_real_card() -> void:
	# Both kinds on one page, which is the case that makes the cell swap
	# its face rather than keeping the one it was built with.
	screen._add_one("Mountain")
	screen._add_proxy(NOT_A_CARD, 1)
	screen.refresh()
	var cards := 0
	var proxies := 0
	for cell in screen._deck_area.cell_nodes():
		if cell.proxy != null:
			proxies += 1
		elif cell.face != null:
			cards += 1
	assert_eq(cards, 1, "the Mountain is still a MiniCard")
	assert_eq(proxies, 1, "and the stand-in is a ProxyFace")


func test_the_showcase_enlarges_a_proxy_too() -> void:
	screen._show_in_showcase(ProxyCard.data_for(NOT_A_CARD))
	assert_true(screen._proxy_showcase.visible, "the paper face is shown")
	assert_false(screen._showcase.visible, "and the card face is not")
	assert_eq(screen._proxy_showcase.proxy_name, NOT_A_CARD)
	assert_eq(screen._proxy_showcase.size, CardPreview.SIZE,
		"at the enlarged card's own size")
	# ...and back, when the pointer reaches a real card again.
	screen._show_in_showcase(CardRegistry.get_card("Mountain"))
	assert_false(screen._proxy_showcase.visible)
	assert_true(screen._showcase.visible)


func test_the_legality_line_leads_with_the_proxies() -> void:
	# It is the only complaint on that line that no amount of adding or
	# cutting cards can answer.
	screen._add_proxy(NOT_A_CARD, 40)
	screen.refresh()
	assert_string_contains(screen._legality_label.tooltip_text, NOT_A_CARD)
	assert_string_contains(screen._legality_label.tooltip_text,
		"cannot be played")


func test_import_reads_a_pasted_decklist() -> void:
	screen._import_pasted("name: Pasted Brew\n4 Lightning Bolt\n20 Mountain\n")
	assert_eq(screen.deck.deck_name, "Pasted Brew")
	assert_eq(screen.deck.count_of("Lightning Bolt"), 4)
	assert_eq(screen.deck.count_of("Mountain"), 20)
	assert_string_contains(screen._status_label.text, "imported")


func test_import_turns_an_unknown_card_into_a_proxy_and_says_so() -> void:
	screen._import_pasted("name: Foreign\n4 Mountain\n2 %s\n" % NOT_A_CARD)
	assert_eq(screen.deck.count_of(NOT_A_CARD), 2, "kept, not dropped")
	assert_eq(screen.deck.total(), 6, "nothing was lost")
	assert_string_contains(screen._status_label.text, NOT_A_CARD,
		"and the screen names what it had to proxy")


func test_import_reads_a_pasted_1997_dck_without_being_told() -> void:
	# A pasted list has no extension to route on, so the format is
	# sniffed by the shape of its own lines.
	screen._import_pasted("Lord of Fate\n\n.101\t4\tMountain\n.0\t2\t%s\n"
		% NOT_A_CARD)
	assert_eq(screen.deck.deck_name, "Lord of Fate")
	assert_eq(screen.deck.count_of("Mountain"), 4)
	assert_eq(screen.deck.count_of(NOT_A_CARD), 2)


func test_import_refuses_nonsense() -> void:
	screen._import_pasted("this is not a decklist at all")
	assert_eq(screen.deck.total(), 0)
	assert_string_contains(screen._status_label.text, "not a decklist")


func test_import_refuses_an_empty_paste() -> void:
	screen._import_pasted("   \n\n")
	assert_string_contains(screen._status_label.text, "nothing to import")


func test_import_reads_a_file_the_player_points_at() -> void:
	var path := "user://decks/_gut_import_probe.dec"
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(DeckStore.USER_DIR))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("// NAME : Imported\n4x Lightning Bolt\n2 %s\nSB: 1 Shatter\n"
		% NOT_A_CARD)
	file.close()
	screen._import_file(path)
	assert_eq(screen.deck.deck_name, "Imported")
	assert_eq(screen.deck.count_of("Lightning Bolt"), 4)
	assert_eq(screen.deck.count_of(NOT_A_CARD), 2)
	assert_eq(screen.deck.side_count_of("Shatter"), 1, "the sideboard came too")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_an_imported_deck_is_dirty_so_leaving_asks_to_save() -> void:
	# It has no file of ours behind it, so walking away really would lose
	# it — unlike `Load deck`, which can always open the file again.
	screen._import_pasted("name: Unsaved\n4 Mountain\n")
	assert_true(screen._dirty)


func test_import_refuses_a_file_that_is_not_a_deck() -> void:
	var path := "user://decks/_gut_import_junk.deck"
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(DeckStore.USER_DIR))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("zero Mountain\nnot a line at all\n")
	file.close()
	screen._import_file(path)
	assert_eq(screen.deck.total(), 0, "nothing came in")
	assert_string_contains(screen._status_label.text, "not a valid deck file")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_the_import_dialog_offers_both_doors() -> void:
	screen._run_command("Import deck")
	var texts := _button_texts()
	assert_true(texts.has("From a file…"), "the file the player points at")
	assert_true(texts.has("Paste a decklist…"), "and the list they paste")


# ================= [QoL] THE LEGALITY ANALYSIS AND ITS SAVE WARNING ==
# The owner asked the builder to analyse deck legality — more than four
# copies, the restricted list, the banned list — and to WARN ON SAVE.
#
# What was missing was only the warning: `DeckFormat` already had the
# three rules and this screen already had a legality line, but the save
# path (`_save_deck` -> `_write_deck`) checked the deck's NAME and whether
# the file existed and nothing else. These pin the new half, and the first
# thing they pin is that it is a WARNING: the file is on disk before the
# dialog exists, so nothing here can stop a save.

func _fill_illegal_deck() -> void:
	screen.deck.deck_name = "Gut Illegal"
	for _i in 5:
		screen._add_one("Lightning Bolt")
	for _i in 2:
		screen._add_one("Black Lotus")
	screen._add_one("Contract from Below")


func _drop_saved(deck_name: String) -> void:
	var path := DeckStore.path_for(deck_name)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_saving_an_illegal_deck_still_writes_the_file() -> void:
	# THE RULE THAT MATTERS. A deck under construction is illegal most of
	# the time, and a builder that would not save half-built work would be
	# broken. The warning is shown AFTER the write for exactly this reason.
	_fill_illegal_deck()
	screen._write_deck()
	assert_true(FileAccess.file_exists(DeckStore.path_for("Gut Illegal")),
		"the deck was saved despite breaking three rules")
	assert_false(screen._dirty, "and the screen knows it is saved")
	_drop_saved("Gut Illegal")


func test_saving_an_illegal_deck_warns_and_names_every_card() -> void:
	_fill_illegal_deck()
	screen._write_deck()
	var dialogs := screen.open_dialogs()
	assert_eq(dialogs.size(), 1, "one warning went up")
	var said := ""
	for node in _walk(dialogs[0]):
		if node is Label:
			said += (node as Label).text + " "
	assert_string_contains(said, "Lightning Bolt")
	assert_string_contains(said, "Black Lotus")
	assert_string_contains(said, "Contract from Below")
	assert_string_contains(said, "saved either way")
	# One button, and it asks nothing — there is no question to answer.
	var buttons := []
	for node in _walk(dialogs[0]):
		if node is Button and (node as Button).text != "":
			buttons.append((node as Button).text)
	assert_eq(buttons, ["OK"], "a warning, not a question")
	_drop_saved("Gut Illegal")


func test_saving_a_legal_deck_says_nothing_at_all() -> void:
	# The common case has to stay silent, or the warning is noise.
	screen.deck.deck_name = "Gut Legal"
	for _i in 4:
		screen._add_one("Lightning Bolt")
	for _i in 20:
		screen._add_one("Mountain")
	screen._write_deck()
	assert_eq(screen.open_dialogs().size(), 0, "nothing to warn about")
	assert_string_contains(screen._status_label.text, "has been saved")
	_drop_saved("Gut Legal")


func test_one_restricted_card_does_not_warn_on_save() -> void:
	# A lone Sol Ring is legal in Restricted (Type 1). Warning about it
	# would cry wolf on a deck that is doing nothing wrong.
	screen.deck.deck_name = "Gut Sol Ring"
	screen._add_one("Sol Ring")
	for _i in 20:
		screen._add_one("Mountain")
	screen._write_deck()
	assert_eq(screen.open_dialogs().size(), 0)
	_drop_saved("Gut Sol Ring")


func test_the_legality_line_reports_the_tournament_rules() -> void:
	# A 60-card deck, so Shandalar's own duplicate allowance (four at 60+)
	# is not the tighter rule and the tournament line is what shows.
	for _i in 56:
		screen._add_one("Mountain")
	for _i in 2:
		screen._add_one("Black Lotus")
	screen._add_one("Contract from Below")
	screen.refresh()
	var said := screen._legality_label.tooltip_text
	assert_string_contains(said, "Black Lotus")
	assert_string_contains(said, "Contract from Below")
	assert_string_contains(said, "restricted list")


func test_the_stats_window_lists_the_deck_type_and_what_breaks_it() -> void:
	for _i in 5:
		screen._add_one("Lightning Bolt")
	screen._run_command("Stats")
	var said := ""
	for node in _walk(screen):
		if node is Label:
			said += (node as Label).text + " "
	assert_string_contains(said, "Deck type:")
	assert_string_contains(said, "5 copies of Lightning Bolt")


func test_the_model_reports_the_offences_and_the_deck_type() -> void:
	for _i in 5:
		screen._add_one("Lightning Bolt")
	assert_eq(screen.deck.format_offences().size(), 1)
	assert_eq(screen.deck.deck_type(), DeckFormat.UNRESTRICTED,
		"five of one card is the catch-all")


# ============================= THE 2026-09-03 PLAYTEST — TWO DEFECTS ==
# The owner's own words are quoted at the test that answers each. Every
# test in this section failed before the fix that follows it in
# game/deck_builder/.

# -------------------------------- 1. the press has a sprite of its own --

func _icon_toggles() -> Array:
	var found := []
	for group in screen._filter_bar.group_names():
		for button in screen._filter_bar.group_buttons(group):
			if button.has_meta("icon_cell"):
				found.append(button)
	return found


## WHAT A StyleBox ACTUALLY LOOKS LIKE, reduced to something two boxes can
## be compared on. A different INSTANCE is not a different look, and it was
## two instances of the very same dark stone that let the lettered toggles
## look split when they were not.
func _look(box: StyleBox) -> String:
	if box is StyleBoxTexture:
		var art: Texture2D = (box as StyleBoxTexture).texture
		return "tex:%d:%s" % [0 if art == null else art.get_instance_id(),
			(box as StyleBoxTexture).modulate_color]
	if box is StyleBoxFlat:
		return "flat:%s" % (box as StyleBoxFlat).bg_color
	return "other:%s" % box


func _assert_press_sprite(button: Button, who: String) -> void:
	assert_ne(_look(button.get_theme_stylebox("normal")),
		_look(button.get_theme_stylebox("pressed")),
		"%s: the raised face and the depressed one are two LOOKS" % who)


func _lettered_toggles() -> Array:
	var found := []
	for button in screen._filter_bar.group_buttons("Set Filters"):
		if button.has_meta("lettered"):
			found.append(button)
	return found


## *"Filter buttons do not feel responsive — on click an immediate press
## sprite should be displayed!"*
##
## Godot draws a HELD toggle in the box of the state it is ABOUT TO
## BECOME: `pressed` while it is latched off, `normal` while it is latched
## on (`BaseButton::get_draw_mode` inverts `pressing` when the button is
## latched — probed on the pinned 4.7.2 build). So those two boxes ARE the
## press. The bar used to bind ONE StyleBox instance to all five states
## and choose the art by the latched value, which made every draw mode
## identical: a capture of the Creatures medallion held down was
## pixel-identical to the same medallion at rest, max channel difference
## 0, in both latch states.
func test_a_filter_medallion_has_a_press_sprite() -> void:
	var toggles := _icon_toggles()
	assert_gt(toggles.size(), 15, "the strip's medallions")
	for button in toggles:
		_assert_press_sprite(button, button.tooltip_text)


## The other half of the same defect. `hover` and `hover_pressed` are
## those same two latch states UNDER THE POINTER — which is exactly where
## the pointer is for the whole of a click — so binding them to one box
## meant a filter sprang back to the look it started from on release and
## the click read as lost.
func test_the_two_hovers_tell_the_latch_apart() -> void:
	for button in _icon_toggles():
		assert_ne(_look(button.get_theme_stylebox("hover")),
			_look(button.get_theme_stylebox("hover_pressed")),
			"%s: on and off differ under the pointer too"
				% button.tooltip_text)


## AND THE FOCUS BOX MUST COVER NOTHING. Godot paints `focus` ON TOP of
## whatever the draw mode chose (probed: a toggle with five
## differently-coloured boxes reads the focus colour whatever its state or
## its latch), and every toggle on this strip is FOCUS_ALL. The opaque
## medallion the bar used to put there meant the FIRST CLICK froze that
## button at its resting art for the rest of the session.
func test_a_focused_filter_button_still_shows_its_own_state() -> void:
	for button in _icon_toggles() + _lettered_toggles():
		var ring: StyleBox = button.get_theme_stylebox("focus")
		assert_true(ring is StyleBoxFlat,
			"%s: the focus cue is a ring, not a face" % button.tooltip_text)
		assert_false((ring as StyleBoxFlat).draw_center,
			"%s: and it paints no centre" % button.tooltip_text)


## Unlimited and the promos are LETTERED — the original drew no set symbol
## for either — and they carried the same defect in stone: one box on all
## five states, with the on/off cue on the node's `modulate`, which is a
## single value for every draw mode and so cannot move under a finger.
func test_the_lettered_set_toggles_go_down_too() -> void:
	var lettered := _lettered_toggles()
	assert_gt(lettered.size(), 0, "Unlimited and the promos have no medallion")
	for button in lettered:
		_assert_press_sprite(button, button.text)
		assert_ne(_look(button.get_theme_stylebox("hover")),
			_look(button.get_theme_stylebox("hover_pressed")),
			"%s under the pointer" % button.text)


## AND WITH NO SKIN IMPORTED, where every [GameSkin] accessor returns null
## and the strip letters itself on flat 1997 bevel geometry. That path is
## `_paint_fallback` whole, so it is exercised directly rather than by
## unskinning the process out from under the other tests.
func test_the_skinless_fallback_has_a_press_sprite_too() -> void:
	var button := Button.new()
	button.toggle_mode = true
	autofree(button)
	screen._filter_bar._paint_fallback(button, "Cr")
	_assert_press_sprite(button, "the skinless bevel")
	assert_ne(_look(button.get_theme_stylebox("hover")),
		_look(button.get_theme_stylebox("hover_pressed")),
		"and under the pointer")
	assert_false((button.get_theme_stylebox("focus") as StyleBoxFlat).draw_center,
		"the focus ring covers nothing here either")


# ------------------- 2. the count in the card row's own bottom corner --

func _tally() -> Label:
	return screen._inventory._tally_label


func _tally_number() -> int:
	return int(_tally().text.split(" ")[0])


## *"The number of cards in the bottom row should be displayed in the
## bottom right — if you filter you immediately see this number get
## smaller and see the effect of the filter!"*
func test_the_inventory_letters_its_count_into_its_own_bottom_right() -> void:
	screen.size = Vector2(1280, 800)
	await get_tree().process_frame
	assert_true(_tally().visible, "the corner is lettered")
	assert_eq(_tally().text, "%d cards" % screen._inventory.entry_count())
	var area := screen._inventory.get_global_rect()
	var corner := _tally().get_global_rect()
	# ...INSIDE THE RIGHT-HAND SCROLL ARROW, which is the one thing that
	# moved it (2026-09-04, the arrows item): that column belongs to the
	# arrow now, so "hard against the right edge" means hard against the
	# edge of the cards, not of the area.
	assert_almost_eq(corner.position.x + corner.size.x,
		area.position.x + area.size.x - screen._inventory.arrow_pad(), 10.0,
		"hard against the right edge, inside the scroll arrow")
	assert_almost_eq(corner.position.y + corner.size.y,
		area.position.y + area.size.y, 10.0, "and the bottom one")


## The scroll bar gives up its own right-hand end for it, so the number
## never sits ON the bar it shares a row with.
func test_the_corner_count_clears_the_scroll_bar() -> void:
	screen.size = Vector2(1280, 800)
	await get_tree().process_frame
	var bar: ScrollBar = screen._inventory._bar
	assert_lte(bar.global_position.x + bar.size.x,
		_tally().global_position.x, "the bar stops short of the number")


## The filter's effect, visible without reading anything else on the
## screen — and through the SEARCH BOX, which is the fastest way to move
## the list.
func test_the_corner_count_shrinks_the_instant_the_search_box_changes() -> void:
	var before := _tally_number()
	screen._filter_bar.search_field.text = "el"
	screen._filter_bar.search_field.text_changed.emit("el")
	await get_tree().process_frame
	assert_lt(_tally_number(), before, "it got smaller")
	assert_eq(_tally().text,
		"%d cards" % screen.filter.apply(screen._pool).size(),
		"and it is the filter's own answer")


## A MEDALLION moves it too, which is the gesture the owner was pressing.
func test_the_corner_count_follows_a_filter_medallion() -> void:
	var before := _tally_number()
	screen.filter.toggle_type(Mtg.CardType.CREATURE)
	screen._refresh_inventory()
	assert_lt(_tally_number(), before, "creatures out of the list")


## WHAT THE NUMBER COUNTS when the list is paged, and it is not the
## obvious thing: every card the filter leaves standing, not the nine on
## the page. A page-sized number would read "9 cards" from Abu Ja'far to
## Zombie Master and report nothing at all.
func test_the_corner_count_is_the_whole_list_and_not_the_page() -> void:
	screen.size = Vector2(1280, 800)
	await get_tree().process_frame
	assert_gt(screen._inventory.entry_count(), screen._inventory.page_size(),
		"the unfiltered pool is many pages")
	assert_eq(_tally_number(), screen._inventory.entry_count())
	var was := _tally().text
	screen._inventory.page_down()
	await get_tree().process_frame
	assert_eq(_tally().text, was, "and paging the row does not move it")
	# The first index, not a literal: how many cards a page holds depends
	# on the window AND on what the row gives up to the two scroll arrows,
	# so a hard-coded "(10-" pins the arrow width by accident.
	assert_gt(screen._inventory.offset(), 0, "the row really paged")
	assert_string_contains(screen._count_label.text,
		"(%d-" % (screen._inventory.offset() + 1),
		"the PAGE is the other line's job, and it did move")


## One card is one card.
func test_the_corner_count_letters_a_single_card_in_the_singular() -> void:
	screen.filter.text = "black lotus"
	screen._refresh_inventory()
	assert_eq(screen._inventory.entry_count(), 1, "just the one")
	assert_eq(_tally().text, "1 card")


## Only the Inventory asks for one. The Deck area and the [QoL] sideboard
## strip letter no corner, and must therefore lose no scroll bar to it.
func test_only_the_inventory_letters_a_corner_count() -> void:
	assert_eq(screen._deck_area.tally, "", "the Deck area")
	assert_eq(screen._sideboard_area.tally, "", "the sideboard strip")
	assert_false(screen._deck_area._tally_label.visible)
	assert_false(screen._sideboard_area._tally_label.visible)


# --------------- 3. the door to the decks: ours, and any file on disk --
#
# The owner's playtest, 2026-09-04: *"A button to load existing decks from
# our collection, or any other from the disk for that matter."*
#
# TWO DIFFERENT THINGS BEHIND ONE BUTTON. The decks this game knows
# (`DeckStore.all_deck_paths`, under `DeckGroups.ORDER`'s headings) were
# already listed by `Load deck` and are listed by the SAME code — a second
# lister would be a second thing to keep in step with the first. What is new
# is the button on the bar, and the door out of that list to a file
# ANYWHERE, which needs a real file dialog.

const JUNK_DIR := "user://test_deck_disk"


func _write_file(name: String, body: String) -> String:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(JUNK_DIR))
	var path := JUNK_DIR.path_join(name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(body)
	file.close()
	return path


func _drop_file(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(JUNK_DIR))


func test_the_command_bar_carries_a_load_button() -> void:
	# It was on the mini-menu and on Ctrl+O, which are two places a player
	# who has never opened the mini-menu will not look.
	assert_true(_button_texts().has("Load"), "on the bar, beside Deck")
	var bar := screen._command_row.get_global_rect()
	for node in _walk(screen._command_row):
		if node is Button and (node as Button).text == "Load":
			assert_true(bar.encloses((node as Button).get_global_rect()),
				"and inside the bar, not spilling out of it")


func test_the_load_button_opens_the_one_deck_list_we_already_had() -> void:
	for node in _walk(screen):
		if node is Button and (node as Button).text == "Load":
			(node as Button).pressed.emit()
	assert_eq(screen.open_dialogs().size(), 1, "the Load Deck dialog")
	var texts := _button_texts()
	var listed := 0
	for text in texts:
		if String(text).contains(" cards · "):
			listed += 1
	assert_gt(listed, 0, "our own collection, described the way it always was")
	# The headings are DeckGroups', not a second grouping of our own.
	var heads: Array = []
	for node in _walk(screen.open_dialogs()[0]):
		if node is Label:
			heads.append((node as Label).text)
	var grouped := DeckGroups.grouped(DeckStore.all_deck_paths())
	for group in grouped:
		assert_true(heads.has(group), "under %s, the picker's own heading"
			% group)


func test_the_load_list_offers_a_file_from_anywhere_on_disk() -> void:
	screen._run_command("Load deck")
	assert_true(_button_texts().has("From disk…"),
		"*or any other from the disk for that matter*")
	for node in _walk(screen.open_dialogs()[0]):
		if node is Button and (node as Button).text == "From disk…":
			(node as Button).pressed.emit()
	await get_tree().process_frame
	var pickers: Array = screen.find_children("*", "FileDialog", true, false)
	assert_eq(pickers.size(), 1, "a real file dialog opened")
	var picker: FileDialog = pickers[0]
	assert_eq(picker.access, FileDialog.ACCESS_FILESYSTEM,
		"the WHOLE filesystem — res:// and user:// are what the list above is")
	assert_eq(picker.file_mode, FileDialog.FILE_MODE_OPEN_FILE)
	assert_eq(picker.filters.size(), DeckStore.IMPORT_FILTERS.size(),
		"every format DeckList reads: .deck, .dec and the 1997 .dck")
	picker.queue_free()


func test_a_deck_file_from_anywhere_on_disk_really_opens() -> void:
	var path := _write_file("friends_deck.deck",
		"name: Sent By A Friend\n4 Lightning Bolt\n20 Mountain\n")
	screen._load_from_disk(path)
	assert_eq(screen.deck.deck_name, "Sent By A Friend")
	assert_eq(screen.deck.count_of("Mountain"), 20)
	# It lands like an IMPORT: there is no file of ours behind it, so @SAVE
	# has to ask before it can be thrown away.
	assert_true(screen._dirty, "leaving without saving would lose it")
	_drop_file(path)


func test_a_1997_dck_from_a_real_install_opens_from_disk_too() -> void:
	# Routing is by EXTENSION, so a `.dck` out of a 1997 Decks folder finds
	# the MicroProse parser without anyone being asked which format it is.
	var ids := DeckStore.dck_ids()
	if ids.is_empty():
		pass_test("no id table on this machine")
		return
	var built := DeckModel.new()
	built.deck_name = "Nineteen Ninety Seven"
	built.counts["Mountain"] = 12
	var written: Array = []
	var refusal := DeckStore.export_deck(built, ".dck", written)
	assert_eq(refusal, "", "the .dck was written")
	assert_eq(written.size(), 1)
	var path := String(written[0])
	assert_true(FileAccess.file_exists(path), "the .dck is on disk")
	screen._load_from_disk(path)
	assert_eq(screen.deck.count_of("Mountain"), 12, "and it came back")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_a_file_that_will_not_parse_says_why_and_does_not_just_vanish() -> void:
	# *"Refuse nothing silently — a file that will not parse must say
	# why."* The status line under the Showcase is four seconds long and
	# three regions away from the file dialog the player was looking at.
	var path := _write_file("holiday.jpg", "ÿØÿà not a deck at all")
	var before := screen.deck.total()
	screen._load_from_disk(path)
	assert_eq(screen.deck.total(), before, "the deck on the surface is untouched")
	assert_eq(screen.open_dialogs().size(), 1, "and a window says so")
	var said := ""
	for node in _walk(screen.open_dialogs()[0]):
		if node is Label:
			said += (node as Label).text + "\n"
	assert_string_contains(said, "holiday.jpg", "it names the file")
	assert_string_contains(said, "not a valid deck file", "@DECKLOADERROR")
	assert_string_contains(said, path, "and where it looked")
	_drop_file(path)


func test_an_empty_file_is_refused_with_a_reason_as_well() -> void:
	var path := _write_file("empty.deck", "")
	screen._load_from_disk(path)
	assert_eq(screen.open_dialogs().size(), 1, "not silence")
	_drop_file(path)
