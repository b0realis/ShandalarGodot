extends GutTest
## A CARD WITH NO KNOWN 1997 NUMBER IS LEFT OUT OF THE `.dck` (the bug
## campaign c12, fixer F7, after F4's h5-2 note). The 1997 deck loader reads
## only a card line's number (deckdll.c `load_deck`, `sscanf(".%d %d")`),
## and number 0 is Air Elemental, so a card our table
## (`cards/data/dck_ids.txt`) has no number for was written `.0` and came
## back in the original game as an Air Elemental. Such a card is now left
## out of the file, and the export says how many were.

var model: DeckModel
var ids: Dictionary


func before_each() -> void:
	ids = DeckStore.dck_ids()
	model = DeckModel.new()
	model.deck_name = "Kird Ape Sligh"
	model.counts["Mountain"] = 20
	model.counts["Lightning Bolt"] = 4
	model.counts["Kird Ape"] = 4         # no 1997 number in the table
	model.counts["Air Elemental"] = 2    # number 0, a real one


func _card_lines(text: String) -> Array[String]:
	var out: Array[String] = []
	for line in text.split("\n"):
		if line.begins_with(".") and not line.begins_with(".v"):
			out.append(line)
	return out


func test_a_card_with_no_known_number_is_left_out() -> void:
	assert_false(ids.has("Kird Ape"), "control: no number for Kird Ape")
	assert_eq(int(ids.get("Air Elemental", -1)), 0, "control: Air Elemental is number 0")
	var lines := _card_lines(model.to_dck_text(ids))
	for line in lines:
		assert_false(line.ends_with("\tKird Ape"), "no line for it, not even .0: " + line)
	assert_true(lines.has(".0\t2\tAir Elemental"), "Air Elemental's own 0 is still written")
	assert_true(lines.has(".164\t20\tMountain"))
	assert_eq(lines.size(), 3, "Mountain, Lightning Bolt, Air Elemental: %s" % [lines])


func test_the_original_game_reads_no_air_elemental_it_was_not_given() -> void:
	# What the 1997 loader makes of the file: the numbers alone.
	var by_number := {}
	for line in _card_lines(model.to_dck_text(ids)):
		var parts := line.substr(1).split("\t")
		by_number[int(parts[0])] = int(by_number.get(int(parts[0]), 0)) + int(parts[1])
	assert_eq(int(by_number.get(0, 0)), 2, "two Air Elementals, the two in the deck")


func test_the_sideboard_leaves_them_out_too() -> void:
	model.sideboard["Juzam Djinn"] = 1    # no number either
	var text := model.to_dck_text(ids)
	assert_false(text.contains("Juzam Djinn"))
	assert_false(text.contains(".vNone"), "a sideboard of nothing the game knows has no section")
	model.sideboard["Shatter"] = 2
	text = model.to_dck_text(ids)
	assert_true(text.contains(".vNone\n.223\t2\tShatter\n"), text)
	assert_false(text.contains("Juzam Djinn"))


func test_the_export_says_how_many_were_left_out() -> void:
	model.sideboard["Juzam Djinn"] = 1
	assert_eq(model.dck_left_out(ids), 5, "four Kird Apes and a Juzam Djinn")
	assert_eq(model.dck_left_out_note(ids),
		"Left out of the .dck: 5 cards with no known 1997 card number.")
	model.counts.erase("Kird Ape")
	assert_eq(model.dck_left_out_note(ids),
		"Left out of the .dck: 1 card with no known 1997 card number.")
	model.sideboard.erase("Juzam Djinn")
	assert_eq(model.dck_left_out(ids), 0)
	assert_eq(model.dck_left_out_note(ids), "", "nothing left out, nothing said")
