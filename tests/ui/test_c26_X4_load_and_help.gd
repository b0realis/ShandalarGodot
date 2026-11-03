extends GutTest
## THE 0.60.13 BUG CAMPAIGN, X4, on screen: the saved adventures refusing a
## campaign whose pack is not installed, naming it (h3-1); the shop's place
## whose pack is unavailable (the owner's polish, 2026-11-03); and the Help
## as the game now is (h3-3).

const FOLDER := "user://c26_x4_load"

var _enabled_before: Array[String] = []
var _hidden := {}


func before_each() -> void:
	_enabled_before = Settings.enabled_card_packs().duplicate()
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	AdventurePlayer.saves_folder = FOLDER
	_clear()


func after_each() -> void:
	_clear()
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	for id in _hidden:
		CardPacks._available[id] = _hidden[id]
	_hidden.clear()
	for id in CardPacks.available_ids():
		if CardPacks.is_enabled(id) != (id in _enabled_before):
			CardPacks.set_enabled(id, id in _enabled_before)


func _clear() -> void:
	var dir := DirAccess.open(FOLDER)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
	AdventurePlayer.forget_saves()


func _hero() -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.player_name = "Mira Thorn"
	setup.seed_text = "48271"
	setup.packs = [FallenEmpiresPack.ID]
	var record := setup.resolve({FallenEmpiresPack.ID: "1.0.0"})
	return AdventurePlayer.begin(record, AdventureSetup.make_world(record))


func _page_text(title: String) -> String:
	for page in HelpPages.pages():
		if String(page["title"]) == title:
			var out := PackedStringArray()
			for block in page["blocks"]:
				if block is Dictionary and block.has("text"):
					out.append(String(block["text"]))
			return "\n".join(out)
	return ""


# ------------------------------------------------------------------ h3-1 --

func test_resume_refuses_a_campaign_whose_pack_is_missing_and_names_it() -> void:
	_hero().autosave()
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	_hidden[FallenEmpiresPack.ID] = CardPacks._available[FallenEmpiresPack.ID]
	CardPacks._available.erase(FallenEmpiresPack.ID)
	var screen: LoadAdventureScreen = load("res://game/adventure/load_adventure_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var row := screen.initial_selection()
	assert_gt(row, 0, "control: the autosave is listed")
	assert_false(screen.continue_adventure(row), "not taken up")
	await get_tree().process_frame
	assert_true(is_instance_valid(screen) and screen.is_inside_tree(), "the list stays")
	var note := (screen.find_child("Note", true, false) as Label).text
	assert_string_contains(note, "Pack 2 (Pack-2-Fallen-Empires.zip)", "the missing pack named")
	assert_false(note.contains("could not be read"), "the save itself is whole")
	assert_true(get_tree().root.get_children().all(func(n: Node) -> bool: return not n is WorldScreen),
		"no world opened")


# --------------------------------------------------------- the shop place --

func test_the_shop_place_whose_pack_is_off_names_it() -> void:
	var player := _hero()
	var slot := 1
	CardShop.offers(player, slot)
	CardShop.town_record(player, slot)["cards"][0] = "Thallid"
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	var pane := CardShopPane.new()
	pane.player = player
	pane.slot = slot
	add_child_autofree(pane)
	await get_tree().process_frame
	var place := pane._row.get_child(0) as Control
	assert_false(bool(place.get_meta("available")))
	var words := place.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	assert_has(words, "Pack 2\nunavailable", "the place names its pack")
	assert_string_contains(place.tooltip_text, "Pack 2 · Fallen Empires")
	pane.choose(0)
	assert_eq(pane.ask_text(), "Enable this card's pack, Pack 2 · Fallen Empires, to buy it.")
	assert_true(pane._buy.disabled)


# ------------------------------------------------------------------ h3-3 --

func test_the_help_tells_the_packs_as_the_embark_offers_them() -> void:
	var embark := _page_text("Shandalar — a new adventure")
	assert_false(embark.contains("not implemented yet"), "Pack 2 joins adventures since 0.60.7")
	assert_string_contains(embark, "Any of Packs 2 to 9 can join an adventure", "all at once since 0.60.14")
	assert_false(embark.contains("unavailable for new adventures"), "no box is greyed since 0.60.14")
	assert_string_contains(embark, "ticks each card pack on the list, or not, at random")
	assert_string_contains(embark, "its allowance is halved, rounded down", "the card rule's non-base halving")
	assert_string_contains(embark, "only to a deck of 40 cards or more, or with the Tome")
	assert_false(embark.contains("--expanded-adventure"), "the prototype is never named in Help")


func test_the_help_tells_four_tabs_and_the_t_key() -> void:
	var deck := _page_text("Your deck and your hero's record")
	assert_false(deck.contains("three tabs"))
	assert_string_contains(deck, "four tabs")
	for tab in HeroStats.TABS:
		assert_true(deck.contains(tab), tab)
	assert_string_contains(deck, "W turns it to the wizards, J to the journal, T to the tasks")


func test_the_help_tells_the_saves_as_the_list_and_ctrl_s_are() -> void:
	var saves := _page_text("Saved adventures")
	assert_false(saves.contains("Continue takes"), "the list has one load action, Resume")
	assert_false(saves.contains("(or Ctrl+S) offers ten slots"))
	assert_string_contains(saves, "Ctrl+S saves at once to the adventure's own Quickslot")
	assert_string_contains(saves, "a pack that is not installed is named")
	var all := HelpPages.all_text()
	assert_false(all.contains("ten named slots (Ctrl+S too)"))
	assert_false(all.contains("Ctrl+S the save slots over the town"))
