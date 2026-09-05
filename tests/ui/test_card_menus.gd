extends GutTest
## THE REST OF THE RIGHT-CLICK MENUS — `docs/duel-todo.md` §6.12, and the
## last live entries of `@MENU_TERRITORY` (§6.3).
##
## The tables and the evidence behind each entry are in [CardMenu]; these
## tests pin that each menu is COMPLETE (the original greys what it cannot
## offer rather than shortening its menu), that the live entries do what
## the help file says they do, and that the gesture that opens the card
## menu is the one `Duel.hlp` describes.


var screen: DuelScreen
## The player's own value of each persisted key this script writes (null
## when their file had none), put back after every test.
var _saved: Dictionary = {}


func _persisted_keys() -> Array[String]:
	var keys: Array[String] = []
	for row in DuelOptions.MENU_TOGGLES:
		keys.append(String(row["key"]))
	keys.append("ExpandTextBoxOnBigCard")
	return keys


func before_each() -> void:
	# Remember-and-restore, never write-the-default-back: these are
	# persisted settings, and writing a default into user://settings.cfg
	# MATERIALISES it there for a player whose file never had the key
	# (Settings.clear_value exists for exactly that — see
	# test_game_audio.gd). Each test still starts from the defaults.
	_saved = {}
	for key in _persisted_keys():
		_saved[key] = Settings.get_value(key, null) if Settings.has_value(key) else null
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	for row in DuelOptions.MENU_TOGGLES:
		Settings.set_value(String(row["key"]), row["default"])
	Settings.set_value("ExpandTextBoxOnBigCard", false)


func after_each() -> void:
	for key in _persisted_keys():
		if _saved[key] == null:
			Settings.clear_value(key)
		else:
			Settings.set_value(key, _saved[key])


func _put(pid: int, card_name: String, sick := false) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name),
		g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, pid)
	inst.summoning_sick = sick
	return inst


func _labels(menu: PopupMenu) -> Array:
	var out: Array = []
	for i in menu.item_count:
		out.append(menu.get_item_text(i))
	return out


# ------------------------------------------------------------- the tables --

func test_the_small_card_menu_is_the_1997_table_verbatim() -> void:
	# `@MENU_SMALLCARD`, UIStrings.txt:936, eight entries in order.
	var bear := _put(0, "Grizzly Bears")
	screen._open_card_menu(bear, Vector2.ZERO)
	assert_eq(_labels(screen._card_menu), [
		"Original type", "Show full card", "View in full card",
		"Don't auto tap this card", "Show ID tags", "Show invisible effects",
		"Show all cards' summoning sickness", "Help...",
	])
	screen._card_menu.hide()


func test_the_library_menu_is_the_1997_table() -> void:
	screen._open_library_menu(0, Vector2.ZERO)
	assert_eq(_labels(screen._library_menu),
		["Count library cards", "Help..."], "@MENU_LIBRARY, :878")
	screen._library_menu.hide()


func test_the_hand_menu_is_help_and_nothing_else() -> void:
	# And the gesture reaches it: a right-click on a hand WINDOW must not
	# fall through to the territory underneath, which would open a menu
	# about the wrong thing.
	for row in screen._hand_rows:
		assert_true(row.gui_input.get_connections().size() > 0,
			"the hand window listens for the mini-menu")
	screen._open_hand_menu(Vector2.ZERO)
	assert_eq(_labels(screen._hand_menu), ["Help..."], "@MENU_HAND, :874")
	assert_true(screen._hand_menu.is_item_disabled(0))
	screen._hand_menu.hide()


func test_the_mana_pool_menu_lists_seven_spends_and_greys_them_all() -> void:
	# `@MENU_MANAPOOL`, :890. The seventh column is `artifact` — the
	# original tracked restricted artifact mana as a pool of its own,
	# which is exactly our ManaPool restricted pool.
	screen._open_mana_menu(Vector2.ZERO)
	assert_eq(_labels(screen._mana_menu), [
		"Spend 1 mana: black", "Spend 1 mana: blue", "Spend 1 mana: green",
		"Spend 1 mana: red", "Spend 1 mana: white",
		"Spend 1 mana: colorless", "Spend 1 mana: artifact", "Help...",
	])
	for i in screen._mana_menu.item_count:
		assert_true(screen._mana_menu.is_item_disabled(i),
			"nothing to spend INTO until a cost can be held open")
	screen._mana_menu.hide()


func test_the_full_card_menu_is_the_showcases_own() -> void:
	screen._open_full_card_menu(Vector2.ZERO)
	assert_eq(_labels(screen._full_card_menu),
		["Expand text box", "Help for this card...", "Help..."])
	screen._full_card_menu.hide()


func test_the_attack_window_menu_flips_with_the_window() -> void:
	# `@MENU_ATTACK` / `@MENU_MINIMIZEDATTACK` (:841, :846) — two of the
	# four menus §6.12's own table left out entirely.
	screen._combat_minimized = false
	screen._open_attack_menu(Vector2.ZERO)
	assert_eq(_labels(screen._attack_menu), ["Minimize", "Help..."])
	screen._attack_menu.hide()
	screen._combat_minimized = true
	screen._open_attack_menu(Vector2.ZERO)
	assert_eq(_labels(screen._attack_menu), ["Restore", "Help..."])
	screen._attack_menu.hide()


func test_the_spell_chain_menus_are_recorded_even_though_unbuilt() -> void:
	# The other two of the four §6.12 missed. Not live: our chain has no
	# minimised state, and the 1997 restore route is the Phase Bar's window
	# icon, which our icon already spends on the Combat window.
	assert_eq(CardMenu.SPELL_CHAIN[0]["label"], "Minimize")
	assert_eq(CardMenu.MINIMIZED_SPELL_CHAIN[0]["label"], "Restore")
	assert_false(bool(CardMenu.SPELL_CHAIN[0]["live"]))


# ------------------------------------------------------- the live entries --

func test_count_library_cards_prints_the_exact_number() -> void:
	# "The number of cards left in your library is represented inexactly,
	# as in real life. If you must know, you can right-click on a library."
	var count: int = screen.game.players[0].library.size()
	screen._open_library_menu(0, Vector2.ZERO)
	screen._on_library_menu_chosen(0)
	assert_string_contains(screen._prompt_label.text, str(count))
	assert_string_contains(screen._prompt_label.text, "library")


func test_show_full_card_docks_the_card_in_the_showcase() -> void:
	var bear := _put(1, "Grizzly Bears")
	screen._open_card_menu(bear, Vector2.ZERO)
	screen._on_card_menu_chosen(1)
	assert_eq(screen._card_preview._name_label.text, "Grizzly Bears")


func test_expand_text_box_grows_the_showcases_text_area() -> void:
	assert_false(screen._card_preview.text_is_expanded())
	screen._open_full_card_menu(Vector2.ZERO)
	screen._on_full_card_menu_chosen(0)
	assert_true(screen._card_preview.text_is_expanded())
	assert_true(bool(Settings.get_value("ExpandTextBoxOnBigCard", false)),
		"and it is remembered — 'These settings are retained'")
	screen._on_full_card_menu_chosen(0)
	assert_false(screen._card_preview.text_is_expanded(), "and toggles off")


# ------------------------------------------------- the three display toggles --

func test_show_id_tags_writes_the_instance_id_on_the_card() -> void:
	# "toggles the display of each card's unique ID code. This can be
	# useful when you need to determine exactly which of several otherwise
	# identical cards is the target of a specific spell or effect."
	var bear := _put(0, "Grizzly Bears")
	var card := MiniCard.new(bear)
	add_child_autofree(card)
	assert_false(card._id_tag.visible, "off by default")
	DuelOptions.set_toggle("ShowIDTagsOnCards", true)
	card.refresh()
	assert_true(card._id_tag.visible)
	assert_eq(card._id_tag.text, str(bear.id))


func test_summoning_sickness_is_creatures_only_until_all_cards_is_on() -> void:
	# `ShowAllCardsSummonSickness` — the exe's own key, and it is what the
	# entry means: not on/off for the spiral, but whether the mark reaches
	# permanents that are not creatures. §6.3 read it the other way.
	var mine := _put(0, "Mishra's Factory", true)
	screen.game.recalculate()
	assert_true(mine.summoning_sick, "the engine marks every permanent")
	var card := MiniCard.new(mine)
	add_child_autofree(card)
	assert_false(card._sick_spiral.visible, "a land is not marked by default")
	DuelOptions.set_toggle("ShowAllCardsSummonSickness", true)
	card.refresh()
	assert_true(card._sick_spiral.visible, "…and is once all cards are")


func test_a_creature_is_marked_either_way() -> void:
	var bear := _put(0, "Grizzly Bears", true)
	screen.game.recalculate()
	var card := MiniCard.new(bear)
	add_child_autofree(card)
	assert_true(card._sick_spiral.visible)


func test_show_invisible_effects_is_listed_and_greyed() -> void:
	# We have no effect cards — the original's "temporary yellow cards
	# that pop up all the time" are objects our engine does not model —
	# so the entry is shown and dark rather than dropped.
	assert_false(DuelOptions.menu_toggle_live("ShowInvisibleEffectCards"))
	var bear := _put(0, "Grizzly Bears")
	screen._open_card_menu(bear, Vector2.ZERO)
	var at := screen._card_menu.get_item_index(5)
	assert_eq(screen._card_menu.get_item_text(at), "Show invisible effects")
	assert_true(screen._card_menu.is_item_disabled(at))
	screen._card_menu.hide()


func test_a_toggle_flips_from_either_menu() -> void:
	var bear := _put(0, "Grizzly Bears")
	screen._open_card_menu(bear, Vector2.ZERO)
	screen._on_card_menu_chosen(4)          # Show ID tags
	assert_true(DuelOptions.toggle("ShowIDTagsOnCards"))
	screen._on_territory_menu_chosen(DuelScreen.REST_BASE + 3)
	assert_false(DuelOptions.toggle("ShowIDTagsOnCards"), "and back off")


# ----------------------------------------------- the Ctrl accelerators --
# `Show ID tags\tCtrl+T`, `Show invisible effects\tCtrl+I`, `Show all
# cards' summoning sickness\tCtrl+U` (`UIStrings.txt:927-929`), §6.3a.

func _key(keycode: Key, ctrl := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	event.ctrl_pressed = ctrl
	return event


func test_ctrl_t_flips_the_id_tag_setting() -> void:
	assert_false(DuelOptions.toggle("ShowIDTagsOnCards"))
	screen._unhandled_key_input(_key(KEY_T, true))
	assert_true(DuelOptions.toggle("ShowIDTagsOnCards"), "on")
	screen._unhandled_key_input(_key(KEY_T, true))
	assert_false(DuelOptions.toggle("ShowIDTagsOnCards"), "and off again")
	screen._unhandled_key_input(_key(KEY_U, true))
	assert_true(DuelOptions.toggle("ShowAllCardsSummonSickness"), "Ctrl+U too")
	# The menu opened afterwards shows the new state: it caches nothing.
	var bear := _put(0, "Grizzly Bears")
	screen._open_card_menu(bear, Vector2.ZERO)
	var at := screen._card_menu.get_item_index(6)
	assert_true(screen._card_menu.is_item_checked(at))
	assert_eq(screen._card_menu.get_item_accelerator(at),
		(KEY_MASK_CTRL | KEY_U) as Key, "and advertises the key it honours")
	assert_eq(screen._card_menu.get_item_accelerator(
		screen._card_menu.get_item_index(5)), KEY_NONE,
		"the dark entry advertises nothing")
	screen._card_menu.hide()


func test_ctrl_i_does_nothing_while_the_command_is_dark() -> void:
	assert_false(DuelOptions.menu_toggle_live("ShowInvisibleEffectCards"))
	screen._unhandled_key_input(_key(KEY_I, true))
	assert_false(DuelOptions.toggle("ShowInvisibleEffectCards"),
		"the keyboard is not a back door into a setting the menu greys")


func test_a_bare_t_does_not_flip_anything() -> void:
	screen._unhandled_key_input(_key(KEY_T))
	screen._unhandled_key_input(_key(KEY_U))
	assert_false(DuelOptions.toggle("ShowIDTagsOnCards"))
	assert_false(DuelOptions.toggle("ShowAllCardsSummonSickness"))


func test_an_accelerator_is_ignored_while_a_dialog_is_open() -> void:
	# A modal centre popup owns the keyboard, and so does one of the
	# duel's own windows — here the concede question, which is not in
	# `_modal_open()` (Return must keep answering it) but is a window.
	screen._on_territory_menu_chosen(DuelScreen.REST_BASE + 8)
	assert_not_null(screen._concede_dialog)
	screen._unhandled_key_input(_key(KEY_T, true))
	assert_false(DuelOptions.toggle("ShowIDTagsOnCards"),
		"not while the player is answering a window")
	screen._concede_dialog.dismiss()
	await get_tree().process_frame
	screen._unhandled_key_input(_key(KEY_T, true))
	assert_true(DuelOptions.toggle("ShowIDTagsOnCards"),
		"the moment the window is gone")


# ----------------------------------------------------------------- concede --

func test_concede_asks_before_it_gives_up() -> void:
	# "Concede announces to your opponent that you're giving up, accepting
	# a loss rather than continue this duel. You must confirm this
	# decision." The confirmation is the table's own entry 25.
	assert_eq(TerritoryMenu.CONCEDE_CONFIRM, "Yes, I'm sure")
	screen._on_territory_menu_chosen(DuelScreen.REST_BASE + 8)
	assert_not_null(screen._concede_dialog, "the confirmation is up")
	assert_false(screen.game.game_over, "and nothing has happened yet")
	screen._concede_dialog.dismiss()
	assert_false(screen.game.game_over, "backing out keeps the duel")


func test_confirming_concede_loses_the_duel() -> void:
	var seat := screen._human_seat()
	screen._on_territory_menu_chosen(DuelScreen.REST_BASE + 8)
	screen._confirm_concede()
	assert_true(screen.game.game_over)
	assert_eq(screen.game.winner, screen.game.opponent_of(seat))
	assert_true(screen.game.players[seat].has_lost)


# ------------------------------- whose territory was clicked (2026-09-02) --

func test_concede_from_the_other_territory_concedes_that_seat() -> void:
	# At a hotseat both halves are human, and the menu the second player
	# opened by right-clicking THEIR territory used to concede seat 0's
	# duel — _human_seat() answers 0 whenever seat 0 is human. The seat
	# whose territory was clicked is the one that gives up.
	screen._open_territory_menu(1, Vector2.ZERO)
	assert_eq(screen._territory_menu_pid, 1)
	screen._on_territory_menu_chosen(DuelScreen.REST_BASE + 8)
	screen._confirm_concede()
	assert_true(screen.game.game_over)
	assert_eq(screen.game.winner, 0, "seat 1 gave up, so seat 0 won")
	assert_true(screen.game.players[1].has_lost)
	assert_false(screen.game.players[0].has_lost)


func test_arrange_my_cards_from_the_other_territory_arranges_that_half() -> void:
	# "My cards" from the second player's own half are the second
	# player's, for the same reason.
	screen._open_territory_menu(1, Vector2.ZERO)
	screen._on_territory_menu_chosen(DuelScreen.REST_BASE + 0)
	assert_true(screen._arranged[1], "the half that was clicked")
	assert_false(screen._arranged[0], "and not seat 0's")
