extends GutTest
## THE DUEL'S MINI HELP, MENU BY MENU (2026-10-13, the owner's ruling:
## *"Maybe here we only keep focused mini help hover over and leave the main
## help as is reachable from the main menu."*). Every duel mini-menu's
## `Help...` was greyed — the Help screen closes to the title, so a duel
## could not open it. Each one is live now and opens a small panel over the
## table with the short help for exactly that menu's subject
## ([DuelMiniHelp], words from [method HelpPages.mini]); the Showcase's
## `Help for this card...` and the Phase Bar's `Help for this phase...` with
## them. The full Help stays the main menu's.

var screen: DuelScreen
const AT := Vector2(300, 200)


func before_each() -> void:
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 1000.0
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	if screen != null and screen.mini_help_open():
		screen._mini_help.dismiss()
	await get_tree().process_frame   # what the redraws let go of is freed


func _put(pid: int, card_name: String) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name), g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, pid)
	inst.summoning_sick = false
	return inst


func _index_of(menu: PopupMenu, label: String) -> int:
	for i in menu.item_count:
		if menu.get_item_text(i) == label:
			return i
	return -1


## Press [param label] on [param menu] the way the menu does — its own
## signal with the item's id — after checking the entry is live.
func _choose(menu: PopupMenu, label: String) -> void:
	var at := _index_of(menu, label)
	assert_true(at >= 0, "%s is on the menu" % label)
	if at < 0:
		return
	assert_false(menu.is_item_disabled(at), "%s is live" % label)
	var id := menu.get_item_id(at)
	menu.hide()
	menu.id_pressed.emit(id)


## The mini help is up, on [param subject], showing its words.
func _assert_help(subject: String, why: String) -> void:
	assert_true(screen.mini_help_open(), "%s: the mini help opened" % why)
	if not screen.mini_help_open():
		return
	assert_eq(screen._mini_help.subject, subject, why)
	var words := HelpPages.mini(subject)
	assert_false(words.is_empty(), "%s: the Help knows the subject" % why)
	assert_string_contains(screen._mini_help.shown_text(), String(words["text"]))
	assert_string_contains(screen._mini_help.shown_text(), String(words["title"]))
	screen._mini_help.dismiss()
	assert_false(screen.mini_help_open(), "%s: and it closes" % why)


# ------------------------------------------------------------ the words --

func test_every_subject_has_a_title_words_and_a_real_help_page() -> void:
	var titles: Array = []
	for page in HelpPages.pages():
		titles.append(String(page["title"]))
	for subject in HelpPages.MINI_SUBJECTS:
		var words := HelpPages.mini(subject)
		assert_ne(String(words.get("title", "")), "", subject)
		assert_gt(String(words.get("text", "")).length(), 40, "%s says something" % subject)
		assert_true(titles.has(String(words.get("page", ""))),
			"%s points at a Help page that exists: %s" % [subject, words.get("page", "")])


func test_the_words_are_short_and_say_no_sources() -> void:
	# A FEW SENTENCES — a hover help, not a page — and the Help's own rule:
	# facts for the player, no development notes or source citations.
	for subject in HelpPages.MINI_SUBJECTS:
		var text := String(HelpPages.mini(subject)["text"])
		assert_lt(text.length(), 520, "%s is short (%d)" % [subject, text.length()])
		var lower := text.to_lower()
		for forbidden in ["duel.hlp", "manual p.", "docs/", "source:", "[qol]",
				"help file", "interrupt", "greyed for now", "todo"]:
			assert_false(lower.contains(forbidden), "%s: %s" % [subject, forbidden])


func test_the_spell_chain_reads_the_casting_page_rather_than_copying_it() -> void:
	# ONE SOURCE: the chain's three sentences are the casting page's own.
	var page_text := HelpPages.all_text()
	var chain := String(HelpPages.mini(HelpPages.MINI_SPELL_CHAIN)["text"])
	var first := chain.substr(0, chain.find("act.") + 4)
	assert_string_contains(first, "Spell Chain")
	assert_string_contains(page_text, first)


func test_the_keys_named_are_the_keys_bound() -> void:
	var hand := String(HelpPages.mini(HelpPages.MINI_HAND)["text"])
	if Controls.text("duel_hand") != Controls.UNBOUND:
		assert_string_contains(hand, Controls.text("duel_hand"))
	var showcase := String(HelpPages.mini(HelpPages.MINI_SHOWCASE)["text"])
	if Controls.text("duel_read") != Controls.UNBOUND:
		assert_string_contains(showcase, Controls.text("duel_read"))


func test_every_phase_icon_has_its_own_help_on_both_halves() -> void:
	for slot in PhaseBar.SLOTS:
		var mine := HelpPages.mini_phase(PhaseStops.Bar.PHASE, slot, true, "T")
		var theirs := HelpPages.mini_phase(PhaseStops.Bar.PHASE, slot, false, "T")
		assert_gt(String(mine.get("text", "")).length(), 20, "phase slot %d" % slot)
		assert_true(String(theirs["text"]).begins_with("The same phase in your opponent's turn"),
			"the opponent's half says whose turn the words are written for")
		assert_string_contains(String(theirs["text"]), String(mine["text"]))
		assert_eq(String(mine["page"]), "Icons — the Phase Bar")
	for slot in CombatBar.TOOLTIPS.size():
		var step := HelpPages.mini_phase(PhaseStops.Bar.COMBAT, slot, true, "T")
		assert_gt(String(step.get("text", "")).length(), 20, "combat slot %d" % slot)
		assert_eq(String(step["page"]), "Icons — the Combat Bar")
	assert_true(HelpPages.mini_phase(PhaseStops.Bar.PHASE, 99, true, "T").is_empty())


func test_help_for_this_card_reads_the_glossary() -> void:
	# The honest meaning: what the Help itself says about the card — the
	# glossary entries for the abilities its rules text names...
	var angel := HelpPages.mini_card("Serra Angel",
		"Flying\nVigilance (Attacking doesn't cause this creature to tap.)")
	assert_eq(angel["title"], "Serra Angel")
	assert_string_contains(String(angel["text"]), "Flying and reach — ")
	assert_string_contains(String(angel["text"]), "Vigilance, haste and defender — ")
	assert_eq(angel["page"], "Abilities — Combat")
	# ...and the entries that name the card itself.
	var oyster := HelpPages.mini_card("Giant Oyster", "")
	assert_string_contains(String(oyster["text"]), "Giant Oyster — ")
	# A word inside a longer word is not that word.
	var none := HelpPages.mini_card("Lightning Bolt",
		"Lightning Bolt deals 3 damage to any target.")
	assert_string_contains(String(none["text"]), "nothing about this card")
	assert_false(String(HelpPages.mini_card("Test", "Overreaching grasp")["text"]).contains("Flying and reach"))
	# A basic land's name is a land type every page uses: only its words count.
	var forest := HelpPages.mini_card("Forest", "({T}: Add {G}.)", true)
	assert_string_contains(String(forest["text"]), "nothing about this card")
	# At most MINI_CARD_MAX entries, however many it names.
	var many := HelpPages.mini_card("Test", "Flying, first strike, trample, "
		+ "banding, protection from black, shroud, flanking")
	assert_eq(String(many["text"]).split("\n\n").size(), HelpPages.MINI_CARD_MAX)


# ------------------------------------------------------ menu by menu --

func test_the_territory_menus_help() -> void:
	screen._open_territory_menu(0, AT)
	_choose(screen._territory_menu, "Help...")
	_assert_help(HelpPages.MINI_TERRITORY, "@MENU_TERRITORY")


func test_the_small_card_menus_help() -> void:
	var bear := _put(0, "Grizzly Bears")
	screen._open_card_menu(bear, AT)
	_choose(screen._card_menu, "Help...")
	_assert_help(HelpPages.MINI_CARD, "@MENU_SMALLCARD")


func test_the_library_menus_help() -> void:
	screen._open_library_menu(0, AT)
	_choose(screen._library_menu, "Help...")
	_assert_help(HelpPages.MINI_LIBRARY, "@MENU_LIBRARY")


func test_the_hand_menus_help() -> void:
	screen._open_hand_menu(AT)
	_choose(screen._hand_menu, "Help...")
	_assert_help(HelpPages.MINI_HAND, "@MENU_HAND")


func test_the_mana_pool_menus_help_and_the_spends_stay_grey() -> void:
	screen._open_mana_menu(AT)
	assert_true(screen._mana_menu.is_item_disabled(0), "the spends stay greyed")
	_choose(screen._mana_menu, "Help...")
	_assert_help(HelpPages.MINI_MANA_POOL, "@MENU_MANAPOOL")


func test_the_showcase_menus_help() -> void:
	screen._open_full_card_menu(AT)
	_choose(screen._full_card_menu, "Help...")
	_assert_help(HelpPages.MINI_SHOWCASE, "@MENU_FULLCARD")


func test_help_for_this_card_needs_a_card_in_the_showcase() -> void:
	screen._card_preview.show_back()
	screen._open_full_card_menu(AT)
	var at := _index_of(screen._full_card_menu, "Help for this card...")
	assert_true(screen._full_card_menu.is_item_disabled(at), "nothing shown: greyed")
	screen._full_card_menu.hide()
	var angel := _put(0, "Serra Angel")
	screen._card_preview.show_card(angel)
	screen._open_full_card_menu(AT)
	_choose(screen._full_card_menu, "Help for this card...")
	assert_true(screen.mini_help_open(), "the card's help opened")
	assert_eq(screen._mini_help.subject, DuelScreen.MINI_HELP_CARD)
	var words := HelpPages.mini_card("Serra Angel", angel.data.oracle_text)
	assert_string_contains(screen._mini_help.shown_text(), String(words["text"]))
	assert_string_contains(screen._mini_help.shown_text(), "Serra Angel")
	# It opens BESIDE the Showcase, not over the card it is about.
	await get_tree().process_frame
	assert_gte(screen._mini_help.panel_rect().position.x,
		screen._card_preview.get_global_rect().end.x, "the card stays in view")
	screen._mini_help.dismiss()


func test_a_face_down_card_in_the_showcase_has_no_help_of_its_own() -> void:
	# A card face down in the game is nobody's to read (docs/card-states.md
	# §5.1): the Showcase shows its back, and its help is greyed.
	var masked := _put(0, "Grizzly Bears")
	masked.face_down = true
	screen._card_preview.show_card(masked)
	assert_null(screen._showcased_card())
	screen._open_full_card_menu(AT)
	var at := _index_of(screen._full_card_menu, "Help for this card...")
	assert_true(screen._full_card_menu.is_item_disabled(at))
	screen._full_card_menu.hide()


func test_the_attack_windows_help_both_ways() -> void:
	screen._combat_minimized = false
	screen._open_attack_menu(AT)
	_choose(screen._attack_menu, "Help...")
	_assert_help(HelpPages.MINI_COMBAT_WINDOW, "@MENU_ATTACK")
	screen._combat_minimized = true
	screen._open_attack_menu(AT)
	_choose(screen._attack_menu, "Help...")
	_assert_help(HelpPages.MINI_COMBAT_WINDOW, "@MENU_MINIMIZEDATTACK")
	screen._combat_minimized = false


func test_the_phase_bars_two_helps() -> void:
	screen._open_phase_menu(PhaseStops.Half.YOURS, PhaseStops.Bar.PHASE, 3, AT)
	_choose(screen._phase_menu, PhaseStops.MENU_HELP)
	_assert_help(HelpPages.MINI_PHASE_BAR, "@MENU_PHASEBAR Help...")
	screen._open_phase_menu(PhaseStops.Half.OPPONENTS, PhaseStops.Bar.PHASE, 0, AT)
	_choose(screen._phase_menu, PhaseStops.MENU_HELP_PHASE)
	assert_true(screen.mini_help_open())
	assert_eq(screen._mini_help.subject, DuelScreen.MINI_HELP_PHASE)
	var cue := screen._phase_menu_label(PhaseStops.Half.OPPONENTS, PhaseStops.Bar.PHASE, 0)
	var words := HelpPages.mini_phase(PhaseStops.Bar.PHASE, 0, false, cue)
	assert_string_contains(screen._mini_help.shown_text(), cue, "titled with the icon's own cue card")
	assert_string_contains(screen._mini_help.shown_text(), String(words["text"]))
	screen._mini_help.dismiss()


func test_the_combat_bars_two_helps() -> void:
	screen._open_phase_menu(PhaseStops.Half.YOURS, PhaseStops.Bar.COMBAT, 1, AT)
	_choose(screen._phase_menu, PhaseStops.MENU_HELP)
	_assert_help(HelpPages.MINI_COMBAT_BAR, "the Combat Bar's Help...")
	screen._open_phase_menu(PhaseStops.Half.YOURS, PhaseStops.Bar.COMBAT, 1, AT)
	_choose(screen._phase_menu, PhaseStops.MENU_HELP_PHASE)
	assert_string_contains(screen._mini_help.shown_text(),
		String(HelpPages.mini_phase(PhaseStops.Bar.COMBAT, 1, true, "")["text"]))
	screen._mini_help.dismiss()


func test_the_life_registers_help() -> void:
	screen._open_life_menu(0, AT)
	_choose(screen._life_menu, "Help...")
	_assert_help(HelpPages.MINI_LIFE, "@MENU_LIFE")


func test_the_graveyard_menu_opens_on_a_right_click_and_its_help_is_live() -> void:
	var g: MtgGame = screen.game
	var dead := CardInstance.new(CardRegistry.get_card("Grizzly Bears"), g._next_instance_id, 0)
	g._next_instance_id += 1
	g._instances[dead.id] = dead
	dead.zone = Mtg.Zone.GRAVEYARD
	g.players[0].graveyard.append(dead)
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.global_position = AT
	screen._grave_icons[0].gui_input.emit(right)
	var menu := screen._grave_menu
	assert_true(menu.visible, "a right-click on the plate opens @MENU_GRAVEYARD")
	assert_eq([menu.get_item_text(0), menu.get_item_text(1), menu.get_item_text(2),
		menu.get_item_text(3)], ["View the graveyard", "View exiled cards",
		"View both antes", "Help..."], "the 1997 table, verbatim (UIStrings.txt:901)")
	assert_false(menu.is_item_disabled(0), "a graveyard with a card in it")
	assert_true(menu.is_item_disabled(1), "no exiled cards")
	assert_true(menu.is_item_disabled(2), "no ante")
	_choose(menu, "View the graveyard")
	assert_true(screen.graveyard_is_open(), "the view opened")
	screen._close_graveyard()
	screen._exile_icons[0].gui_input.emit(right)
	assert_true(menu.visible, "the exile plate has the same menu")
	_choose(menu, "Help...")
	_assert_help(HelpPages.MINI_GRAVEYARD, "@MENU_GRAVEYARD")
	# The left click still opens the pile, as it did.
	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	left.pressed = true
	screen._grave_icons[0].gui_input.emit(left)
	assert_true(screen.graveyard_is_open(), "a left click opens the pile")
	screen._close_graveyard()
	await get_tree().process_frame   # the shelves it rebuilt are freed


func test_the_spell_chain_menu_opens_on_the_band_and_its_help_is_live() -> void:
	var g: MtgGame = screen.game
	var data := CardRegistry.get_card("Lightning Bolt")
	var inst := CardInstance.new(data, g._next_instance_id, 1)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	var item := StackItem.new()
	item.kind = Mtg.StackKind.SPELL
	item.controller = 1
	item.card = inst
	item.description = "Lightning Bolt (test)"
	g.stack.append(item)
	screen._rebuild_stack()
	var band: Control = screen._chain_box.get_child(0).get_child(0)
	assert_true(band is PanelContainer, "control: the tan band over the card")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.global_position = AT
	band.gui_input.emit(right)
	var menu := screen._chain_menu
	assert_true(menu.visible, "@MENU_SPELLCHAIN opens on the band")
	assert_false(menu.is_item_disabled(0),
		"Minimize is live since the polish pass of 2026-10-28 (the chain's title band)")
	_choose(menu, "Help...")
	_assert_help(HelpPages.MINI_SPELL_CHAIN, "@MENU_SPELLCHAIN")
	g.stack.clear()


func test_every_table_ends_in_a_live_help() -> void:
	for table in [CardMenu.SMALL_CARD, CardMenu.LIBRARY, CardMenu.HAND,
			CardMenu.MANA_POOL, CardMenu.FULL_CARD, CardMenu.ATTACK,
			CardMenu.MINIMIZED_ATTACK, CardMenu.SPELL_CHAIN,
			CardMenu.MINIMIZED_SPELL_CHAIN, CardMenu.GRAVEYARD]:
		var id := CardMenu.help_id(table)
		assert_eq(id, table.size() - 1, "Help... is the last entry")
		assert_true(bool(table[id]["live"]))
	var help_row: Dictionary = TerritoryMenu.REST[CardMenu.index_of(TerritoryMenu.REST, "Help...")]
	assert_true(TerritoryMenu.rest_is_live(help_row))


# ------------------------------------------------ the full Help stays put --

func test_the_full_help_is_the_main_menus_and_no_duel_route_reaches_it() -> void:
	# The main menu's Help button opens the Help screen...
	var main_src := FileAccess.get_file_as_string("res://game/main.gd")
	assert_string_contains(main_src, "res://game/help/help_screen.tscn")
	# ...and nothing in the duel or at an SGManalink table names it: the
	# mini help is the duel's only help, and it never leaves the duel.
	for dir in ["res://game/duel", "res://game/sgmanalink"]:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".gd"):
				continue
			var src := FileAccess.get_file_as_string(dir.path_join(file))
			assert_false(src.contains("help_screen"), "%s/%s" % [dir, file])


func test_opening_and_closing_it_never_leaves_the_duel() -> void:
	var scene := get_tree().current_scene
	screen._open_library_menu(0, AT)
	_choose(screen._library_menu, "Help...")
	assert_true(screen.mini_help_open())
	assert_true(screen.is_inside_tree(), "the duel is still on screen")
	screen._mini_help.dismiss()
	await get_tree().process_frame
	assert_eq(get_tree().current_scene, scene, "no scene change")
	assert_true(screen.is_inside_tree())
	assert_false(screen.game.game_over)
