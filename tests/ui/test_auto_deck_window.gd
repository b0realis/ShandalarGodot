extends GutTest
## AUTODECK'S WINDOW AND THE POOL MEDALLION (2026-09-18): the
## gold line at the top of the mini-menu, the window it opens
## ([AutoDeckWindow]), the deck `Build me a deck` puts on the surface as
## one undoable step, and the three-card disc beside the dice that puts
## the pool the deck was built from in and out of the Inventory. The
## building itself is `tests/unit/test_auto_deck.gd`'s.


var screen: DeckBuilderScreen
var _saved: Variant = null


func before_each() -> void:
	CardRegistry.ensure_loaded()
	_saved = Settings.get_value(AutoDeckWindow.OPTIONS_SETTING, null) \
		if Settings.has_value(AutoDeckWindow.OPTIONS_SETTING) else null
	Settings.clear_value(AutoDeckWindow.OPTIONS_SETTING)
	screen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	if _saved == null:
		Settings.clear_value(AutoDeckWindow.OPTIONS_SETTING)
	else:
		Settings.set_value(AutoDeckWindow.OPTIONS_SETTING, _saved, false)


func _window() -> OriginalDialog:
	for dialog in screen.open_dialogs():
		if dialog.has_meta("auto_deck_window"):
			return dialog
	return null


## The window behind the dialog, for the wishes and the seed.
func _window_of() -> AutoDeckWindow:
	return _window().get_meta("auto_deck_window")


func _paste() -> OriginalDialog:
	for dialog in screen.open_dialogs():
		if dialog.name == "AutoDeckPaste":
			return dialog
	return null


func _in(name: String, root: Node = null) -> Node:
	var window: Node = root if root != null else _window()
	return null if window == null else window.find_child(name, true, false)


func _foot(text: String) -> Button:
	for node in _window().find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node
	return null


func _open() -> void:
	screen._run_command(DeckBuilderScreen.AI_COMMAND)
	await get_tree().process_frame
	assert_not_null(_window(), "AutoDeck's window")


func _lands() -> int:
	var n := 0
	for name in screen.deck.names():
		if DeckModel._card(name).is_land():
			n += int(screen.deck.counts[name])
	return n


# ------------------------------------------------------------- the menu --

func test_the_gold_line_at_the_top_of_the_mini_menu_opens_the_window() -> void:
	assert_eq(screen._command_labels()[0], DeckBuilderScreen.AI_COMMAND, "first on the list")
	assert_false(DeckBuilderScreen.EXTRA_COMMANDS.has(DeckBuilderScreen.AI_COMMAND),
		"not one of the [QoL] commands — it has its own colour")
	screen._open_mini_menu()
	await get_tree().process_frame
	assert_eq(screen.open_dialogs().size(), 1)
	var menu := screen.open_dialogs()[0]
	var first: Button = null
	var gold := 0
	for node in menu.find_children("*", "Button", true, false):
		var line := node as Button
		if line.text == "Cancel":
			continue
		if first == null:
			first = line
		if line.has_theme_color_override("font_color") \
				and line.get_theme_color("font_color") == UiChrome.CHOSEN:
			gold += 1
			assert_eq(line.text, DeckBuilderScreen.AI_COMMAND, "the one emphasised line")
	assert_not_null(first)
	assert_eq(first.text, DeckBuilderScreen.AI_COMMAND, "at the top")
	assert_eq(gold, 1, "one line in gold")
	first.pressed.emit()
	await get_tree().process_frame
	assert_not_null(_window(), "the line opens the window")
	assert_eq(screen.open_dialogs().size(), 1, "and the menu came down")


func test_the_window_shows_the_pool_and_the_wishes_with_their_defaults() -> void:
	await _open()
	var texts: Array = []
	for node in _window().find_children("*", "Label", true, false):
		texts.append((node as Label).text)
	assert_true(texts.has(AutoDeckWindow.TITLE), "the title")
	assert_true(texts.has(AutoDeckWindow.BRIEF), "the brief")
	for head in ["Card pool", "Colours", "Deck"]:
		assert_true(texts.has(head), head)
	assert_eq((_in("SourceSets") as Button).text, "[x] Cards from these sets", "sets by default")
	assert_eq((_in("Set_4ed") as Button).text, "[x] Fourth Edition", "Fourth Edition ticked")
	assert_eq((_in("Set_2ed") as Button).text, "[  ] Unlimited", "the rest not")
	for code in CardRegistry.active_set_order():
		assert_not_null(_in("Set_" + String(code)), "a line for %s" % code)
	assert_null(_in("SourceDealt"), "no dealt cards, no line for them")
	assert_eq((_in("SourceList") as Button).text, "[  ] A list of cards")
	assert_not_null(_in("FileButton"))
	assert_not_null(_in("PasteButton"))
	assert_eq((_in("ListLine") as Label).text, AutoDeckWindow.NO_LIST)
	for letter in ["W", "U", "B", "R", "G"]:
		var button: Button = _in("Color_" + letter)
		assert_not_null(button, letter)
		assert_true(button.toggle_mode)
		assert_false(button.button_pressed, "%s: no colour asked for" % letter)
		if ManaIcons.symbol(letter) != null:
			# The symbols are the skin's; the bare clone has none to wear.
			assert_not_null(button.icon, "%s wears its mana symbol" % letter)
	assert_true((_in("MaxColors_2") as Button).button_pressed, "two colours at most")
	for n in [1, 2, 3, 4, 5]:
		assert_not_null(_in("MaxColors_%d" % n), "up to five colours (2026-09-18)")
	assert_eq((_in("GoldLine") as Button).text, "[  ] " + AutoDeckWindow.GOLD_TEXT, "not a gold deck")
	assert_eq((_in("PowerNineLine") as Button).text, "[  ] " + AutoDeckWindow.POWER_TEXT,
		"the Power Nine off by default (2026-09-18)")
	assert_eq((_in("PowerNineLine") as Button).tooltip_text, AutoDeckWindow.POWER_TIP)
	assert_false(_window_of().builder().power_nine)
	# Variety (2026-09-26): a row of the builder's four levels, best by
	# default, each with a tooltip saying what the seed then moves.
	for level in AutoDeck.VARIETY_LEVELS:
		var button: Button = _in("Variety_%d" % level)
		assert_not_null(button, "a variety button for %d" % level)
		assert_eq(button.button_pressed, level == 0, "variety %d: %s" % [level, "down" if level == 0 else "up"])
		assert_false(button.tooltip_text.is_empty(), "variety %d has its tooltip" % level)
	assert_eq((_in("Variety_0") as Button).text, "Best")
	assert_eq((_in("Variety_100") as Button).text, "Wild")
	assert_eq(_window_of().builder().variety, 0, "the builder gets the default")
	# One more line (2026-09-18), the variety row (2026-09-26), and the
	# wishes still fit the window, the window the 1280x800 viewport.
	await get_tree().process_frame
	var body := _window().body()
	gut.p("AutoDeck window: body needs %.0f of %.0f; window %.0f tall" % [
		body.get_combined_minimum_size().y, body.size.y, _window().size.y])
	assert_lte(body.get_combined_minimum_size().y, body.size.y, "the wishes fit the window")
	assert_lte(_window().size.y, 800.0, "the window fits the viewport")
	assert_true((_in("Size_60") as Button).button_pressed, "sixty")
	assert_true((_in("Lean_balanced") as Button).button_pressed)
	assert_true((_in("Speed_medium") as Button).button_pressed)
	assert_true((_in("Rarity_") as Button).button_pressed, "any rarity")
	for value in AutoDeck.RARITIES:
		var button: Button = _in("Rarity_" + value)
		assert_not_null(button, "a rarity button for %s" % value)
		assert_eq(button.text, String(AutoDeckWindow.RARITY_LABELS[value]))
	assert_eq((_in("Rarity_common") as Button).text, "Common-pauper")
	assert_eq((_in("Rarity_rares") as Button).text, "Only rares")
	assert_true((_in("Lands_classic") as Button).button_pressed, "classic lands")
	assert_false((_in("Lands_nonclassic") as Button).button_pressed)
	assert_eq((_in("SeedEdit") as LineEdit).text, "", "no seed: a fresh roll every build")
	assert_eq((_in("SeedEdit") as LineEdit).placeholder_text, AutoDeckWindow.SEED_BLANK)
	assert_false((_in("LastSeedButton") as Button).visible, "nothing built yet")
	assert_false((_in("Size_40") as Button).button_pressed)
	assert_true((_in("TournamentLine") as Button).text.begins_with("[x] Tournament rules"))
	var keep: Button = _in("KeepLine")
	assert_true(keep.disabled, "nothing on the surface to build around")
	assert_true(keep.text.ends_with("(none yet)"), keep.text)
	var summary: Label = _in("SummaryLine")
	assert_true(summary.text.begins_with("60 cards from Fourth Edition — "), summary.text)
	assert_true(summary.text.contains("the builder's choice of colours, up to 2; balanced, medium."), summary.text)
	var build: Button = _in("BuildButton")
	assert_eq(build.text, AutoDeckWindow.BUILD_LABEL)
	assert_false(build.disabled)
	assert_not_null(_foot("Cancel"))
	assert_false(screen._pool_button.button_pressed, "the medallion stays up until a deck is built")
	screen._on_escape()
	await get_tree().process_frame
	assert_null(_window(), "Escape is Cancel")
	assert_eq(screen.deck.total(), 0, "and nothing was built")
	assert_null(screen._auto_pool)


func test_build_me_a_deck_puts_the_deck_on_the_surface_and_the_pool_in_force() -> void:
	await _open()
	_in("BuildButton").pressed.emit()
	await get_tree().process_frame
	assert_null(_window(), "the window came down")
	assert_eq(screen.deck.total(), 60, "sixty cards on the surface")
	assert_eq(screen.deck.side_total(), 0)
	assert_between(_lands(), 24 - AutoDeck.LAND_PLAY, 24 + AutoDeck.LAND_PLAY,
		"medium: 24 lands, settled to the curve (2026-09-26): %d" % _lands())
	assert_true(screen.deck.deck_name.ends_with(" Midrange"), screen.deck.deck_name)
	assert_true(screen.deck.notes.begins_with("Built by AutoDeck: 60 cards, "), screen.deck.notes)
	assert_true(screen.deck.notes.contains("Card pool: Fourth Edition ("), screen.deck.notes)
	assert_eq(screen._header_label.text, screen.deck.deck_name, "the header letters the name")
	assert_true(screen._dirty, "unsaved work")
	assert_not_null(screen._auto_pool, "the pool is kept")
	assert_eq(screen.sealed, screen._auto_pool, "and in force")
	assert_true(screen._pool_button.button_pressed, "the medallion is down")
	assert_false(screen._dice_button.button_pressed, "the dice are not")
	assert_true(screen._count_label.text.contains("pool cards"), screen._count_label.text)
	assert_true(screen._status_label.text.begins_with("%s — 60 cards built from Fourth Edition" % screen.deck.deck_name),
		screen._status_label.text)
	# One assertion for the whole deck, not one a name: the window rolls
	# a fresh seed, so the deck — and a per-name count — differs by run.
	var strays := PackedStringArray()
	for name in screen.deck.names():
		if screen._auto_pool.copies_of(name) < int(screen.deck.counts[name]):
			strays.append(name)
	assert_eq(strays.size(), 0, "every card came from the pool: %s" % ", ".join(strays))
	for land in AutoDeck.BASICS:
		assert_eq(screen._auto_pool.copies_of(land), 60, "%s is free in the pool" % land)
	assert_eq(screen._inventory.copies_shown(), screen._auto_pool.total() - 60,
		"the Inventory is the pool less what the deck took")
	var saved: Variant = Settings.get_value(AutoDeckWindow.OPTIONS_SETTING, null)
	assert_true(saved is Dictionary, "the wishes are remembered")
	assert_eq(int(saved["size"]), 60)
	# Undo: the surface before the build comes back, the pool stays.
	screen._undo_last()
	assert_eq(screen.deck.total(), 0, "the empty surface is back")
	assert_eq(screen.sealed, screen._auto_pool, "the pool stays in force")
	screen._undo_last()
	assert_eq(screen.deck.total(), 60, "and Undo's Undo is the deck again")
	await get_tree().process_frame


func test_the_wishes_reach_the_builder() -> void:
	await _open()
	_in("Color_U").pressed.emit()
	_in("Color_B").pressed.emit()
	_in("Size_40").pressed.emit()
	_in("Lean_creatures").pressed.emit()
	_in("Speed_fast").pressed.emit()
	_in("TournamentLine").pressed.emit()
	var summary: Label = _in("SummaryLine")
	assert_true(summary.text.begins_with("40 cards from Fourth Edition — "), summary.text)
	assert_true(summary.text.contains("blue-black, up to 2; creatures, fast."), summary.text)
	assert_true(summary.text.ends_with("creatures, fast."), "nothing beyond the defaults yet: " + summary.text)
	assert_true((_in("TournamentLine") as Button).text.begins_with("[  ]"), "the rules off")
	# The wishes of 2026-09-18: a gold deck, a rarity, the lands, the
	# Power Nine.
	_in("GoldLine").pressed.emit()
	_in("Rarity_uncommon_up").pressed.emit()
	_in("Lands_nonclassic").pressed.emit()
	_in("PowerNineLine").pressed.emit()
	assert_eq((_in("GoldLine") as Button).text, "[x] " + AutoDeckWindow.GOLD_TEXT)
	assert_eq((_in("PowerNineLine") as Button).text, "[x] " + AutoDeckWindow.POWER_TEXT)
	assert_true(summary.text.ends_with("creatures, fast. A gold deck, uncommon up, non-classic lands, the Power Nine."), summary.text)
	assert_true(_window_of().builder().power_nine, "the wish reaches the builder")
	# Variety (2026-09-26): the summary says it, the builder gets it.
	_in("Variety_50").pressed.emit()
	assert_true(summary.text.ends_with("the Power Nine, variety 50."), summary.text)
	assert_eq(_window_of().builder().variety, 50)
	_in("Variety_0").pressed.emit()
	assert_true(summary.text.ends_with("the Power Nine."), "back to best: " + summary.text)
	assert_eq(_window_of().builder().variety, 0)
	_in("BuildButton").pressed.emit()
	await get_tree().process_frame
	assert_eq(screen.deck.total(), 40)
	assert_between(_lands(), 15 - AutoDeck.LAND_PLAY, 15 + AutoDeck.LAND_PLAY,
		"fast: 15 lands in 40, settled to the curve (2026-09-26): %d" % _lands())
	assert_true(screen.deck.deck_name.begins_with("Blue-Black "), screen.deck.deck_name)
	assert_true(screen.deck.deck_name.ends_with(" Rush"), screen.deck.deck_name)
	assert_true(screen.deck.notes.contains("Built without the tournament rules"), screen.deck.notes)
	assert_true(screen.deck.notes.contains("A gold deck: multicoloured cards preferred, but the pool had none the deck could cast."),
		"Fourth Edition has no gold card: " + screen.deck.notes)
	assert_true(screen.deck.notes.contains("Rarity: uncommons, rares and legends."), screen.deck.notes)
	assert_true(screen.deck.notes.contains("Non-classic lands:"), screen.deck.notes)
	assert_true(screen.deck.notes.contains("The Power Nine asked for, but the pool, the rarity wish and the colours allowed none."),
		"Fourth Edition has none of the nine: " + screen.deck.notes)
	for land in ["Plains", "Mountain", "Forest"]:
		assert_eq(screen.deck.count_of(land), 0, "no %s" % land)
	for name in screen.deck.names():
		if AutoDeck.BASICS.has(name):
			continue
		var tier := DeckStats.rarity_tier(DeckModel._card(name))
		assert_true(tier != "common", "%s is %s: no commons in an uncommon-up deck" % [name, tier])
	# Reopened, the window remembers.
	await _open()
	assert_true((_in("Color_U") as Button).button_pressed)
	assert_true((_in("Color_B") as Button).button_pressed)
	assert_false((_in("Color_W") as Button).button_pressed)
	assert_true((_in("Size_40") as Button).button_pressed)
	assert_true((_in("Lean_creatures") as Button).button_pressed)
	assert_true((_in("Speed_fast") as Button).button_pressed)
	assert_true((_in("TournamentLine") as Button).text.begins_with("[  ]"))
	assert_true((_in("GoldLine") as Button).text.begins_with("[x]"))
	assert_true((_in("Rarity_uncommon_up") as Button).button_pressed)
	assert_true((_in("Lands_nonclassic") as Button).button_pressed)
	assert_true((_in("PowerNineLine") as Button).text.begins_with("[x]"), "the Power Nine remembered")
	_in("PowerNineLine").pressed.emit()
	assert_true((_in("PowerNineLine") as Button).text.begins_with("[  ]"))
	assert_false((_in("SummaryLine") as Label).text.contains("Power Nine"), (_in("SummaryLine") as Label).text)
	# A gold deck is two colours at least, whatever the cap says.
	_in("Color_U").pressed.emit()
	_in("Color_B").pressed.emit()
	_in("MaxColors_1").pressed.emit()
	assert_true((_in("SummaryLine") as Label).text.contains("the builder's choice of colours, up to 2;"),
		(_in("SummaryLine") as Label).text)
	_in("GoldLine").pressed.emit()
	assert_true((_in("SummaryLine") as Label).text.contains("the builder's choice of colours, up to 1;"),
		(_in("SummaryLine") as Label).text)
	_in("MaxColors_5").pressed.emit()
	assert_true((_in("SummaryLine") as Label).text.contains("up to 5;"), (_in("SummaryLine") as Label).text)
	_in("MaxColors_2").pressed.emit()
	_in("Color_U").pressed.emit()
	_in("Color_B").pressed.emit()
	# A third colour asked for widens the cap in the summary.
	_in("Color_R").pressed.emit()
	assert_true((_in("SummaryLine") as Label).text.contains("blue-black-red, up to 3;"),
		(_in("SummaryLine") as Label).text)


## The builder is seeded and its notes give the roll back; the window's
## seed field (2026-09-18) takes it, so the same pool, wishes and seed
## build the same deck again — and `Last build` puts the roll back.
func test_a_seed_builds_the_same_deck_again() -> void:
	await _open()
	var edit: LineEdit = _in("SeedEdit")
	var summary: Label = _in("SummaryLine")
	edit.text = "12ab3"
	edit.text_changed.emit(edit.text)
	assert_eq(edit.text, "123", "digits only")
	assert_eq(int(_window_of().options["seed"]), 123)
	assert_true(summary.text.ends_with("balanced, medium. Seed 123 — the same deck again."), summary.text)
	_in("BuildButton").pressed.emit()
	await get_tree().process_frame
	var first := screen.deck.duplicate_model()
	assert_true(first.notes.contains("Seed 123: the same pool and wishes build this deck again."), first.notes)
	# Reopened, the seed is remembered and said out loud; the same deck
	# comes of it.
	await _open()
	assert_eq((_in("SeedEdit") as LineEdit).text, "123")
	assert_true((_in("SummaryLine") as Label).text.ends_with("Seed 123 — the same deck again."),
		(_in("SummaryLine") as Label).text)
	var last: Button = _in("LastSeedButton")
	assert_true(last.visible)
	assert_eq(last.text, "Last build: 123")
	_in("BuildButton").pressed.emit()
	await get_tree().process_frame
	assert_eq(screen.deck.counts, first.counts, "the same deck again")
	assert_eq(screen.deck.deck_name, first.deck_name)
	# Blanked, every build is a fresh roll — and the roll is the last
	# build's, for the button to put back.
	await _open()
	_window_of().set_seed(0)
	assert_eq((_in("SeedEdit") as LineEdit).text, "")
	assert_false((_in("SummaryLine") as Label).text.contains("Seed"), (_in("SummaryLine") as Label).text)
	_in("BuildButton").pressed.emit()
	await get_tree().process_frame
	var rolled := int(Settings.get_value(AutoDeckWindow.OPTIONS_SETTING, {})["last_seed"])
	assert_gt(rolled, 0, "the roll remembered")
	assert_ne(rolled, 123)
	assert_true(screen.deck.notes.contains("Seed %d:" % rolled), screen.deck.notes)
	await _open()
	assert_eq((_in("SeedEdit") as LineEdit).text, "", "blank stays blank")
	assert_eq((_in("LastSeedButton") as Button).text, "Last build: %d" % rolled)
	_in("LastSeedButton").pressed.emit()
	assert_eq((_in("SeedEdit") as LineEdit).text, str(rolled), "the last roll put back")
	assert_true((_in("SummaryLine") as Label).text.ends_with("Seed %d — the same deck again." % rolled))
	# A seed beyond the builder's own range is held to it.
	_window_of().set_seed(5_000_000)
	assert_eq(int(_window_of().options["seed"]), AutoDeckWindow.SEED_MOST)
	assert_eq(_window_of().builder().seed, AutoDeckWindow.SEED_MOST)


func test_the_sets_tick_and_untick_and_no_set_builds_nothing() -> void:
	await _open()
	_in("Set_4ed").pressed.emit()
	assert_eq((_in("Set_4ed") as Button).text, "[  ] Fourth Edition")
	var summary: Label = _in("SummaryLine")
	assert_true(summary.text.begins_with("60 cards from no set — 0 on offer, 0 names;"), summary.text)
	assert_true(summary.text.ends_with(" Nothing to build from yet."), summary.text)
	assert_true((_in("BuildButton") as Button).disabled, "nothing to build from")
	_in("Set_2ed").pressed.emit()
	_in("Set_drk").pressed.emit()
	assert_eq((_in("Set_2ed") as Button).text, "[x] Unlimited")
	assert_true((_in("SummaryLine") as Label).text.begins_with("60 cards from Unlimited, The Dark — "),
		(_in("SummaryLine") as Label).text)
	assert_false((_in("BuildButton") as Button).disabled)
	for code in ["4ed", "arn", "atq"]:
		_in("Set_" + code).pressed.emit()
	assert_true((_in("SummaryLine") as Label).text.begins_with("60 cards from 5 sets — "),
		"more than three sets are counted: %s" % (_in("SummaryLine") as Label).text)


func test_a_pasted_list_is_a_pool() -> void:
	await _open()
	_in("PasteButton").pressed.emit()
	await get_tree().process_frame
	var paste := _paste()
	assert_not_null(paste, "the paste box")
	assert_not_null(_window(), "over the window, which stays")
	var edit: TextEdit = _in("PasteEdit", paste)
	edit.text = "this is not a list"
	_in("ReadButton", paste).pressed.emit()
	await get_tree().process_frame
	assert_not_null(_paste(), "a bad list keeps the box up")
	assert_true(screen._status_label.text.begins_with(AutoDeckWindow.PASTE_ERROR), screen._status_label.text)
	edit.text = "# pool\n4 Lightning Bolt\n2 Serra Angel\nSB: 1 Disenchant\n1 No Such Card\n"
	_in("ReadButton", paste).pressed.emit()
	await get_tree().process_frame
	assert_null(_paste(), "read, the box comes down")
	assert_eq((_in("SourceList") as Button).text, "[x] A list of cards", "and the list is the pool")
	assert_eq((_in("SourceSets") as Button).text, "[  ] Cards from these sets")
	assert_eq((_in("ListLine") as Label).text, "7 cards (3 names) from a pasted list")
	assert_true(screen._status_label.text.begins_with("7 cards read from a pasted list — 1 name the game does not have: No Such Card"),
		screen._status_label.text)
	assert_true((_in("SummaryLine") as Label).text.begins_with("60 cards from a pasted list — 7 on offer, 3 names;"),
		(_in("SummaryLine") as Label).text)
	_in("BuildButton").pressed.emit()
	await get_tree().process_frame
	assert_eq(screen.deck.total(), 60)
	assert_eq(screen.deck.count_of("Lightning Bolt"), 4)
	assert_eq(screen.deck.count_of("Serra Angel"), 2)
	assert_eq(screen.deck.count_of("Disenchant"), 1, "the sideboard line counted")
	assert_eq(_lands(), 53, "the rest is basic land")
	assert_true(screen.deck.notes.contains("Card pool: a pasted list (7 cards on offer)."), screen.deck.notes)
	assert_true(screen.deck.notes.contains("The pool ran out after 7 spells; 29 extra basic lands fill the deck."), screen.deck.notes)
	assert_eq(screen._auto_pool.copies_of("Lightning Bolt"), 4)
	assert_eq(screen._inventory.copies_shown(), 5 * 60 - 53, "the pool's spells are all placed; the basics remain")
	# Pressing the list line with a list already read only picks it.
	await _open()
	assert_eq((_in("SourceSets") as Button).text, "[x] Cards from these sets",
		"a list is not remembered between visits — it was never on disk")


func test_the_dealt_cards_are_a_pool_when_one_is_in_force() -> void:
	var pool := SealedPool.new()
	var library: Array = []
	for card_name in CardRegistry.all_names():
		library.append(CardRegistry.get_card(card_name))
	pool.deal(library, 1997)
	screen._enter_sealed(pool)
	await _open()
	var dealt: Button = _in("SourceDealt")
	assert_not_null(dealt, "the dealt cards are on offer")
	var spells := AutoDeck.pool_total(AutoDeck.pool_from_counts(pool.counts))
	assert_eq(dealt.text, "[  ] The dealt cards (%d cards)" % spells)
	dealt.pressed.emit()
	assert_eq(dealt.text, "[x] The dealt cards (%d cards)" % spells)
	assert_true((_in("SummaryLine") as Label).text.begins_with("60 cards from the dealt cards — %d on offer" % spells),
		(_in("SummaryLine") as Label).text)
	_in("Size_40").pressed.emit()
	_in("BuildButton").pressed.emit()
	await get_tree().process_frame
	assert_eq(screen.deck.total(), 40)
	var over := PackedStringArray()
	for name in screen.deck.names():
		if not AutoDeck.BASICS.has(name) and int(screen.deck.counts[name]) > pool.copies_of(name):
			over.append(name)
	assert_eq(over.size(), 0, "no more of a card than were dealt: %s" % ", ".join(over))
	assert_true(screen.deck.notes.contains("Card pool: the dealt cards ("), screen.deck.notes)
	assert_ne(screen.sealed, pool, "the builder's own pool took the dealt one's place")
	assert_eq(screen.sealed, screen._auto_pool)
	assert_true(screen._pool_button.button_pressed)
	assert_false(screen._dice_button.button_pressed)
	await _open()
	assert_eq((_in("SourceDealt") as Button).text, "[x] The pool in force (%d cards)" % spells,
		"reopened, the pool in force is the one on offer, and remembered")


func test_the_cards_on_the_surface_can_be_built_around() -> void:
	for i in 4:
		screen._add_one("Lightning Bolt")
	screen._add_one("Plains")
	await _open()
	var keep: Button = _in("KeepLine")
	assert_false(keep.disabled)
	assert_eq(keep.text, "[  ] Build around the 4 non-land cards already on the surface")
	keep.pressed.emit()
	assert_eq(keep.text, "[x] Build around the 4 non-land cards already on the surface")
	_in("Color_G").pressed.emit()
	_in("BuildButton").pressed.emit()
	await get_tree().process_frame
	assert_eq(screen.deck.total(), 60)
	assert_eq(screen.deck.count_of("Lightning Bolt"), 4, "kept")
	assert_true(screen.deck.deck_name.begins_with("Red-Green "), "the kept cards' red and the green asked for: %s" % screen.deck.deck_name)
	assert_true(screen.deck.notes.contains("Built around the 4 cards already on the surface."), screen.deck.notes)
	screen._undo_last()
	assert_eq(screen.deck.total(), 5, "Undo is the five cards again")
	assert_eq(screen.deck.count_of("Plains"), 1)


# -------------------------------------------------------- the medallion --

func test_the_pool_medallion_sits_between_the_dice_and_stats() -> void:
	var disc: Button = screen._pool_button
	assert_not_null(disc)
	assert_eq(disc.name, "PoolButton")
	assert_eq(disc.get_meta("icon_cell"), FilterBar.POOL_CELL, "the three cards, composed on a stone")
	assert_eq(disc.size, Vector2(FilterBar.DICE_SIZE, FilterBar.DICE_SIZE), "the dice's size")
	assert_true(disc.toggle_mode, "it latches")
	assert_false(disc.button_pressed, "up: no pool yet")
	assert_false(disc.disabled)
	var dice: Button = screen._dice_button
	assert_gt(disc.position.x, dice.position.x + dice.size.x - 1.0, "right of the dice")
	assert_lt(disc.position.x + disc.size.x, screen._stats_button.global_position.x, "left of Stats")
	assert_almost_eq(disc.position.y, dice.position.y, 0.51, "on the dice's line")
	assert_true(disc.tooltip_text.begins_with("Card pool"), disc.tooltip_text)
	assert_ne(FilterBar.POOL_CELL, FilterBar.DICE_CELL, "its own cell on the sheet")


func test_the_medallion_opens_the_window_until_there_is_a_pool_and_then_toggles_it() -> void:
	screen._pool_button.pressed.emit()
	await get_tree().process_frame
	assert_not_null(_window(), "no pool yet: the window")
	assert_false(screen._pool_button.button_pressed, "and the disc stays up")
	_in("BuildButton").pressed.emit()
	await get_tree().process_frame
	assert_true(screen._pool_button.button_pressed)
	assert_eq(screen.sealed, screen._auto_pool)
	var pool_count := screen._count_label.text
	# Up: the whole library, the deck untouched.
	screen._pool_button.set_pressed_no_signal(false)
	screen._pool_button.pressed.emit()
	await get_tree().process_frame
	assert_null(screen.sealed, "the whole library")
	assert_false(screen._pool_button.button_pressed)
	assert_eq(screen.deck.total(), 60, "the deck stays")
	assert_not_null(screen._auto_pool, "the pool is kept for the next press")
	assert_true(screen._count_label.text.begins_with("%d cards" % CardRegistry.size()), screen._count_label.text)
	assert_eq(screen._status_label.text, "The whole library is back in the Inventory")
	# Down: the pool again.
	screen._pool_button.set_pressed_no_signal(true)
	screen._pool_button.pressed.emit()
	await get_tree().process_frame
	assert_eq(screen.sealed, screen._auto_pool)
	assert_true(screen._pool_button.button_pressed)
	assert_eq(screen._count_label.text, pool_count)
	assert_true(screen._status_label.text.begins_with("Card pool — "), screen._status_label.text)


func test_one_medallion_down_at_a_time() -> void:
	await _open()
	_in("BuildButton").pressed.emit()
	await get_tree().process_frame
	assert_true(screen._pool_button.button_pressed)
	assert_false(screen._dice_button.button_pressed)
	# A Sealed Deck pool takes over: the dice go down, the disc comes up.
	var pool := SealedPool.new()
	var library: Array = []
	for card_name in CardRegistry.all_names():
		library.append(CardRegistry.get_card(card_name))
	pool.deal(library, 7)
	screen._enter_sealed(pool)
	assert_true(screen._dice_button.button_pressed)
	assert_false(screen._pool_button.button_pressed)
	assert_eq(screen.sealed, pool)
	assert_true(screen._status_label.text.begins_with("Sealed Deck — "), screen._status_label.text)
	# The disc brings the builder's pool back.
	screen._pool_button.set_pressed_no_signal(true)
	screen._pool_button.pressed.emit()
	await get_tree().process_frame
	assert_eq(screen.sealed, screen._auto_pool)
	assert_true(screen._pool_button.button_pressed)
	assert_false(screen._dice_button.button_pressed)
	screen._leave_sealed()
	assert_false(screen._pool_button.button_pressed)
	assert_false(screen._dice_button.button_pressed)


func test_the_help_explains_the_disc_and_the_command() -> void:
	var entries := HelpPages.icon_entries()
	var found := false
	for entry in entries:
		var art: Dictionary = entry.get("icon", {})
		if art.get("src", "") == HelpPages.SRC_FILTER and int(art.get("row", 99)) == FilterBar.POOL_CELL[0] \
				and int(art.get("col", 99)) == FilterBar.POOL_CELL[1]:
			found = true
			assert_true(String(entry["name"]).begins_with("Card pool"), String(entry["name"]))
	assert_true(found, "the pool disc is in the icon glossary")
