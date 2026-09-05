extends GutTest
## EVERY BADGE ANSWERS FOR ITS SET.
##
## The row in the title screen's bottom-left corner is eight expansion
## symbols and the pool they stand for. Until 2026-09-03 it was decoration
## with a tooltip; the owner asked for each icon to open "a mini popup
## window explaining what set is this, and basic set info, date, cards,
## and mini lore info". These pin the three halves of that: the FACTS file
## covers the pool, the numbers in it are true, and a click reaches the
## shell.

func test_every_set_in_the_pool_has_its_facts() -> void:
	for code in CardRegistry.SET_ORDER:
		var facts := SetBadges.facts_for(String(code))
		assert_false(facts.is_empty(), "facts for %s" % code)
		for key in ["name", "released", "printed", "lore"]:
			assert_true(facts.has(key), "%s carries %s" % [code, key])
		assert_gt(String(facts["lore"]).length(), 80,
			"%s: the lore is a paragraph, not a label" % code)


func test_the_printed_size_is_never_smaller_than_what_we_implement() -> void:
	# A set cannot hold fewer cards than this game took from it; if it
	# does, one of the two numbers is wrong and the popup would say so.
	for code in CardRegistry.SET_ORDER:
		var facts := SetBadges.facts_for(String(code))
		assert_between(SetBadges.cards_here(String(code)), 1,
			int(facts.get("printed", 0)), String(code))


func test_the_description_says_the_date_and_both_counts() -> void:
	var text := SetBadges.describe("arn")
	assert_string_contains(text, "December 1993")
	assert_string_contains(text, "of its 78 cards")
	assert_string_contains(text, "scimitar", "and what the set WAS")


func test_a_set_we_hold_whole_says_so_rather_than_counting() -> void:
	# Astral is the 1997 game's own twelve, all implemented.
	assert_string_contains(SetBadges.describe("past"), "all 12 of its cards")


func test_a_click_on_a_badge_asks_the_shell_for_that_set() -> void:
	var row := SetBadges.new()
	add_child_autofree(row)
	await get_tree().process_frame
	var heard: Array = []
	row.set_clicked.connect(func(code: String) -> void: heard.append(code))
	var badge: Control = row.get_node("badge_atq")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	badge.gui_input.emit(click)
	assert_eq(heard, ["atq"], "the anvil asks for Antiquities")


func test_the_whole_row_is_clickable_set_by_set() -> void:
	var row := SetBadges.new()
	add_child_autofree(row)
	await get_tree().process_frame
	for code in CardRegistry.SET_ORDER:
		assert_not_null(row.get_node_or_null("badge_%s" % code), String(code))
