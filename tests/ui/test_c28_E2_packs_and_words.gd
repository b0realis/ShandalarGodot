extends GutTest
## THE CARD PACKS OPEN (0.60.14, the owner's pack rulings of 2026-11-03):
## every pack the Embark offers — Packs 2 to 9, Pack 1 never — can join an
## ordinary adventure, all at once; the screen, its card-rule tooltips and
## the Help say what a pack brings: its own cards, a share of every random
## card (20% a pack, 60% at most), strong cards special, ante cards never on
## a shop's shelves, the first deck and the creatures' decks base cards.

var screen: EmbarkScreen
var _launch_before: bool
var _enabled_before: Array[String] = []


func before_each() -> void:
	_launch_before = AdventureExpansions.launch_enabled
	AdventureExpansions.read_launch(PackedStringArray())
	_enabled_before = Settings.enabled_card_packs().duplicate()
	AdventureSetup.forget()
	screen = load("res://game/adventure/embark_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	AdventureExpansions.read_launch(PackedStringArray([AdventureExpansions.LAUNCH_FLAG]) if _launch_before else PackedStringArray())
	AdventureSetup.forget()
	for id in CardPacks.available_ids():
		if CardPacks.is_enabled(id) != (id in _enabled_before):
			CardPacks.set_enabled(id, id in _enabled_before)


func _offered() -> Array[String]:
	return AdventureSetup.offered_packs(CardPacks.available_ids())


func _open() -> EmbarkScreen:
	var again: EmbarkScreen = load("res://game/adventure/embark_screen.tscn").instantiate()
	add_child_autofree(again)
	await get_tree().process_frame
	return again


func _page_text(title: String) -> String:
	for page in HelpPages.pages():
		if String(page["title"]) == title:
			var out := PackedStringArray()
			for block in page["blocks"]:
				if block is Dictionary and block.has("text"):
					out.append(String(block["text"]))
			return "\n".join(out)
	return ""


func _block(title: String, opening: String) -> String:
	for line in _page_text(title).split("\n"):
		if line.begins_with(opening):
			return line
	return ""


# ------------------------------------------------------------ the boxes --

## Ruling 1: all of Packs 2–9 tickable at once; Pack 1 stays out.
func test_every_offered_pack_can_be_ticked() -> void:
	var offered := _offered()
	assert_gt(offered.size(), 1, "the test packs are installed")
	assert_false("pack-1" in offered, "Pack 1 is never offered")
	assert_eq(screen._pack_checks.keys().size(), offered.size())
	for id in offered:
		var check := screen._pack_checks[id] as CheckBox
		assert_false(check.disabled, id + " can be ticked")
		assert_eq(check.modulate, Color.WHITE, id + " is not greyed")
		assert_false(check.tooltip_text.contains("Unavailable"), id + " is not refused")
		check.button_pressed = true
		assert_true(id in screen.setup.packs, id + " joins")
		check.button_pressed = false
		assert_false(id in screen.setup.packs, id + " leaves")
	for label in ["PacksAll", "PacksNone"]:
		assert_false((screen.find_child(label, true, false) as Button).disabled, label)
	screen.choose_all_packs(true)
	assert_eq(screen.setup.packs, offered, "All ticks every offered pack")
	screen.choose_all_packs(false)
	assert_eq(screen.setup.packs, [] as Array[String], "None unticks them")


## A choice of Packs 3–9 is remembered for the next visit, as Pack 2's was;
## Pack 1 is still dropped.
func test_a_remembered_choice_of_any_pack_comes_back() -> void:
	var offered := _offered()
	screen.choose_all_packs(true)
	screen.setup.remember()
	var again := await _open()
	assert_eq(again.setup.packs, offered, "every pack remembered")
	for id in offered:
		assert_true((again._pack_checks[id] as CheckBox).button_pressed, id + " shown ticked")
	Settings.set_value(AdventureSetup.KEY_PREFIX + "packs", "pack-1,pack-9,pack-3")
	var third := await _open()
	assert_eq(third.setup.packs, ["pack-9", "pack-3"] as Array[String], "Pack 1 never")


## Randomize may tick any offered pack, not only Pack 2.
func test_randomize_can_tick_every_pack() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2811
	var ticked := {}
	for draw in 40:
		screen.randomize_all(rng)
		for id in screen.setup.packs:
			ticked[id] = true
	for id in _offered():
		assert_true(ticked.has(id), id + " drawn")


## Setting out with a pack other than Pack 2 enables it and the record keeps it.
func test_setting_out_with_another_pack_keeps_it() -> void:
	if not "pack-9" in _offered():
		pass_test("Pack 9 is not installed here")
		return
	CardPacks.set_enabled("pack-9", false)
	(screen._pack_checks["pack-9"] as CheckBox).button_pressed = true
	(screen.find_child("HeroName", true, false) as LineEdit).text = "Open Packs"
	watch_signals(screen)
	screen.embark()
	assert_signal_emitted(screen, "embarked")
	var record: Dictionary = get_signal_parameters(screen, "embarked")[0]
	var ids: Array = (record["packs"] as Array).map(func(row: Dictionary) -> String: return String(row["id"]))
	assert_eq(ids, ["pack-9"], "the record keeps the pack")
	assert_true(CardPacks.is_enabled("pack-9"), "enabled for duels and deck building too")


# ------------------------------------------------------------ the words --

## The card-rule tooltips speak of pack cards, not of one pack.
func test_the_card_rule_tips_say_pack_cards() -> void:
	for rule in [AdventurePlayer.RULE_MEANT, AdventurePlayer.RULE_SHIPPED]:
		var tip: String = EmbarkScreen.RULE_TIPS[rule]
		assert_false(tip.contains("Fallen Empires"), rule)
		assert_false(tip.contains(" FE "), rule)
		assert_string_contains(tip, "pack card")


## The words beside the list: each pack's own cards, its share, the first deck.
func test_the_pack_words_tell_the_share() -> void:
	var about := (screen.find_child("PacksAbout", true, false) as Label).text
	assert_string_contains(about, "own cards")
	assert_string_contains(about, "shops and rewards")
	assert_string_contains(about, "20%")
	assert_string_contains(about, "60%")
	assert_string_contains(about, "first deck uses base cards")


# ------------------------------------------------------------- the Help --

const EMBARK_PAGE := "Shandalar — a new adventure"


func test_the_help_tells_any_pack_can_join() -> void:
	var packs := _block(EMBARK_PAGE, "Card packs lists")
	assert_ne(packs, "", "the Card packs block")
	assert_string_contains(packs, "Packs 2 to 9")
	assert_false(packs.contains("greyed"), "no pack is greyed")
	assert_false(packs.to_lower().contains("unavailable for new adventures"))
	assert_string_contains(packs, "first deck and the creatures' decks stay base cards")
	assert_string_contains(packs, "20%")
	assert_string_contains(packs, "60%")
	assert_string_contains(packs, "special")
	assert_string_contains(packs, "never sold in a shop")
	assert_string_contains(packs, "Amulet of Quoz")
	assert_string_contains(packs, "for duels and deck building too", "the global switch-on is still said")
	assert_string_contains(packs, "Fifth Edition", "Pack 7's reprints")


func test_the_help_card_rule_and_randomize_name_no_single_pack() -> void:
	var rule := _block(EMBARK_PAGE, "Card rule:")
	assert_false(rule.contains("Fallen Empires"))
	assert_string_contains(rule, "a pack's card (one not among the base cards)")
	var shuffle := _block(EMBARK_PAGE, "Randomize draws")
	assert_string_contains(shuffle, "ticks each card pack on the list, or not, at random")
	var page := _page_text(EMBARK_PAGE)
	assert_false(page.to_lower().contains("island"), "the prototype is never named")
	assert_false(page.contains("--expanded-adventure"))
