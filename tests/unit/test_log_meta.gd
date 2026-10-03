extends GameTest
## THE LOG'S SECOND COLUMN — [member MtgGame.log_meta], one Dictionary per
## line of [member MtgGame.log_lines], index for index (2026-09-07,
## `[QoL]`). The duel log window and the running `duel_log.txt` read it
## to mark steps, label seats and colour card names; the engine writes
## it and never reads it back.
##
## What is pinned: the two columns never drift apart; a cast names its
## card, its colour and its caster; a basic land carries the colour it
## taps for; a sentence that opens with a player's name is that player's
## and a possessive is not; the turn header knows whose turn it is; a
## draw is logged without naming the card; and a probe's lines never
## happened in either column.


func _last() -> Dictionary:
	return g.log_meta[g.log_meta.size() - 1]


func _find(fragment: String) -> Dictionary:
	for i in g.log_lines.size():
		if g.log_lines[i].contains(fragment):
			return g.log_meta[i]
	return {}


func test_the_two_columns_are_index_for_index() -> void:
	assert_gt(g.log_lines.size(), 0, "a set-up game has logged")
	assert_eq(g.log_meta.size(), g.log_lines.size())
	g.log_line("a plain line")
	assert_eq(g.log_meta.size(), g.log_lines.size())
	for key in ["turn", "step", "pid", "kind", "card", "colors"]:
		assert_true(_last().has(key), "every entry carries %s" % key)


func test_a_cast_names_the_card_its_colour_its_caster_and_its_kind() -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	var meta := _find("P0 casts Lightning Bolt")
	assert_eq(meta.get("kind"), "cast")
	assert_eq(meta.get("card"), "Lightning Bolt")
	assert_eq(meta.get("colors"), Mtg.ManaColor.R)
	assert_eq(meta.get("pid"), 0)
	assert_eq(meta.get("turn"), g.turn_number)
	assert_eq(meta.get("step"), Mtg.Step.MAIN1, "written in the step it happened in")


func test_a_basic_land_carries_the_colour_it_taps_for() -> void:
	var island := give_hand(0, "Island")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.play_land(0, island))
	var meta := _find("P0 plays Island")
	assert_eq(meta.get("kind"), "play")
	assert_eq(meta.get("card"), "Island")
	assert_eq(meta.get("colors"), Mtg.ManaColor.U,
		"an Island is colourless and reads blue — the colour it taps for")


func test_a_sentence_opening_with_a_name_is_that_seats_and_a_possessive_is_not() -> void:
	g.log_line("P1 discards Forest")
	assert_eq(_last().get("pid"), 1, "the sentence opens with P1's name")
	g.log_line("P1's damage to Grizzly Bears is prevented")
	assert_eq(_last().get("pid"), -1, "a possessive is about a card, not an act")
	g.log_line("Serra Angel is destroyed")
	assert_eq(_last().get("pid"), -1)
	g.log_line("P10 is not a player here")
	assert_eq(_last().get("pid"), -1, "the name must be followed by a space")


func test_the_longer_name_wins_a_prefix_tie() -> void:
	var h := MtgGame.new()
	var filler: Array = []
	for i in 30:
		filler.append("Forest")
	h.setup(filler, filler, "Bob", "Bobby", 20, 20, 1)
	h.log_line("Bobby plays Forest")
	assert_eq(h.log_meta[h.log_meta.size() - 1].get("pid"), 1, "Bobby's, not Bob's")
	h.log_line("Bob plays Forest")
	assert_eq(h.log_meta[h.log_meta.size() - 1].get("pid"), 0)


func test_the_turn_header_knows_whose_turn_it_is() -> void:
	advance_to_next_turn()
	var meta := _find("== Turn 2 — P1 ==")
	assert_eq(meta.get("kind"), "turn")
	assert_eq(meta.get("pid"), 1)
	assert_eq(meta.get("turn"), 2)


func test_a_draw_is_logged_without_naming_the_card() -> void:
	var before := g.log_lines.size()
	g.draw_cards(1, 1)
	assert_eq(g.log_lines[before], "P1 draws a card")
	assert_eq(g.log_meta[before].get("kind"), "draw")
	assert_eq(g.log_meta[before].get("pid"), 1)
	assert_eq(g.log_meta[before].get("card"), "", "the opponent's hand is theirs to know")
	g.draw_cards(0, 3)
	assert_eq(g.log_lines[g.log_lines.size() - 1], "P0 draws 3 cards")


func test_a_destroyed_creature_is_the_lines_card() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	g.destroy(bear)
	var meta := _find("Grizzly Bears is destroyed")
	assert_eq(meta.get("card"), "Grizzly Bears")
	assert_eq(meta.get("colors"), Mtg.ManaColor.G)
	assert_eq(meta.get("kind"), "", "a consequence has no kind")


func test_a_line_before_the_first_turn_has_no_step() -> void:
	var h := MtgGame.new()
	var filler: Array = []
	for i in 30:
		filler.append("Forest")
	h.setup(filler, filler, "P0", "P1", 20, 20, 1)
	assert_eq(h.log_meta[0].get("step"), -1, "no step before the first turn")
	assert_eq(h.log_meta[0].get("turn"), 0)


# ----------------------------- private lines (bug pass 2026-10-03) --------

func test_a_private_tutor_line_is_private_to_its_searcher() -> void:
	# Demonic Tutor's find is hidden information: the log keeps the full
	# sentence (the audit trail), and the meta tells every reader which
	# seat may read it and what everyone else is shown.
	advance_to_step(Mtg.Step.MAIN1)
	var tutor := give_hand(0, "Demonic Tutor")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, tutor, []))
	resolve_stack()
	var meta := _find("searches their library and finds")
	assert_false(meta.is_empty(), "the search was logged")
	assert_eq(int(meta.get("private_to", -1)), 0, "private to the searcher")
	assert_eq(String(meta.get("public", "")),
		"P0 searches their library and finds a card", "the table's version")
	assert_eq(String(meta["card"]), "", "and the meta names no card")


func test_a_revealed_search_line_stays_public() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	g.search_library(0, Callable(), "Pick a card", false, true, "Test — revealed card")
	var meta := _find("searches their library and finds")
	assert_false(meta.is_empty())
	assert_false(meta.has("private_to"), "a revealed find is public")
	assert_false(meta.has("public"))


func test_a_card_put_back_on_top_is_private_to_its_owner() -> void:
	# Sylvan Library's put-back: hand to library, both hidden.
	var bear := give_hand(1, "Grizzly Bears")
	g.put_from_hand_on_top_of_library(bear)
	var meta := _last()
	assert_eq(g.log_lines[g.log_lines.size() - 1], "P1 puts Grizzly Bears on top of their library")
	assert_eq(int(meta.get("private_to", -1)), 1)
	assert_eq(String(meta.get("public", "")), "P1 puts a card on top of their library")


func test_a_public_line_carries_no_privacy_keys() -> void:
	g.log_line("a plain line")
	assert_false(_last().has("private_to"))
	assert_false(_last().has("public"))


# ------------------------- face-down permanents (bug pass 2026-10-03) --

## A face-down permanent has no name (CR 708.2). A line that names one —
## here add_counters's "Shivan Dragon gets 1 +1/+1 counter(s)" — is the
## controller's secret: the log keeps the audit sentence, the meta says
## whose it is and what everyone else reads.
func test_a_line_naming_a_face_down_creature_is_private_to_its_controller() -> void:
	var dragon := give_hand(1, "Shivan Dragon")
	g.put_from_hand_face_down(dragon, 1)
	g.add_counters(dragon, "+1/+1", 1)
	var meta := _last()
	assert_string_contains(g.log_lines[g.log_lines.size() - 1], "Shivan Dragon")
	assert_eq(int(meta.get("private_to", -1)), 1)
	assert_false(String(meta.get("public", "")).contains("Shivan Dragon"))
	assert_string_starts_with(String(meta.get("public", "")), "A face-down creature gets 1")
	assert_eq(String(meta["card"]), "")


func test_a_line_naming_both_seats_face_down_creatures_is_nobodys() -> void:
	var dragon := give_hand(1, "Shivan Dragon")
	g.put_from_hand_face_down(dragon, 1)
	var angel := give_hand(0, "Serra Angel")
	g.put_from_hand_face_down(angel, 0)
	g.log_line("Shivan Dragon stares at Serra Angel")
	var meta := _last()
	assert_eq(int(meta.get("private_to", -1)), MtgGame.FACE_DOWN_NOBODY)
	assert_eq(String(meta.get("public", "")), "A face-down creature stares at a face-down creature")


func test_a_face_up_creatures_line_stays_public() -> void:
	var dragon := put_battlefield(1, "Shivan Dragon")
	g.add_counters(dragon, "+1/+1", 1)
	assert_false(_last().has("private_to"))
