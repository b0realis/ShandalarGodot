extends GutTest
## Hunt 2026-10-21 (rules) — A DECK LIST HAS A SIZE, NOT ONLY A LINE.
##
## The bug pass of 2026-10-03 capped ONE count line at
## [constant DeckList.MAX_COUNT] (500) because `5000000 Forest` froze the
## setup screen. The total stayed open (whole-project review 2026-10-21,
## "Seen by the reviewers, unchecked"): a 44 KB file of 4,000
## `500 Forest` lines expanded to two million names in one parse, and a
## few megabytes of them would exhaust memory in the setup screen's deck
## list, the Deck Builder's import or the Load list — every one of them
## parses each file it shows. Now a list stops growing at
## [constant DeckList.MAX_TOTAL] cards, both piles together, and says so
## once.

const LINE := "500 Forest"


func _text(lines: int, line := LINE) -> String:
	var out := PackedStringArray()
	for i in lines:
		out.append(line)
	return "\n".join(out)


func test_a_huge_list_stops_at_the_total() -> void:
	var deck := DeckList.new()
	deck.parse(_text(4000), "huge", false)
	assert_lte(deck.cards.size(), DeckList.MAX_TOTAL)
	assert_eq(deck.errors.size(), 1, "one line says why, not four thousand")
	assert_string_contains(deck.errors[0], "too many cards")


func test_the_sideboard_counts_toward_the_total() -> void:
	var deck := DeckList.new()
	deck.parse(_text(4000, "SB: 500 Forest"), "huge", false)
	assert_lte(deck.cards.size() + deck.sideboard.size(), DeckList.MAX_TOTAL)


func test_the_dck_format_stops_too() -> void:
	var lines := PackedStringArray(["Huge (Gr, 4th Edition)"])
	for i in 4000:
		lines.append(".1\t500\tForest")
	lines.append(".vNone")
	for i in 4000:
		lines.append(".1\t500\tProxy Number %d" % i)
	var deck := DeckList.new()
	deck.parse_dck("\n".join(lines), "huge", false)
	assert_lte(deck.cards.size() + deck.sideboard.size(), DeckList.MAX_TOTAL)
	assert_false(deck.errors.is_empty())


func test_an_ordinary_oversized_deck_still_loads_whole() -> void:
	# A 600-card deck is a deck the Deck Builder refuses to PLAY (its own
	# 500-card limit), not a file to cut short: the player must see all of
	# it to trim it.
	var deck := DeckList.new()
	deck.parse("300 Forest\n300 Island\nSB: 15 Mountain", "big", true)
	assert_eq(deck.cards.size(), 600)
	assert_eq(deck.sideboard.size(), 15)
	assert_true(deck.errors.is_empty())
