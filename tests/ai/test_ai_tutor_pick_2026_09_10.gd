extends GameTest
## THE TUTOR'S PICK (2026-09-10, [member AiProfile.tutors_for_the_turn]).
##
## [method AiPlayer.answer_card] answered every gain ask with one question —
## [method Evaluator.card_value], the printed worth of a card as a thing to
## have — so a search of our own library took the DEAREST card in the deck
## and never the card the turn wanted. Three things followed, and all three
## are pinned here on the arm that has the knob and the arm that does not:
##
##  * A LAND WAS NEVER FETCHED. Every land prices at a flat 1.5, below any
##    spell in the pool, so a Demonic Tutor on two lands with a hand of
##    four-drops fetched a fourth four-drop.
##  * THE CARD WE COULD CAST WAS PASSED OVER for the card we could not: a
##    Mahamoti Djinn four turns away beats a Hypnotic Specter castable
##    next turn, because 11 is bigger than 6.
##  * THE BOARD WAS NOT LOOKED AT. A Wrath of God and a Jayemdae Tome both
##    print at 5.0, so which one came back was the order the shuffle left
##    them in — the same answer across four creatures and across an empty
##    table.
##
## Nothing here names a card. The seam is a card ask whose candidates all
## sit in the LIBRARY ([method AiPlayer._tutor_ask]), the shape every tutor
## in this pool has; the readings are [method AiPlayer._land_light],
## [method AiPlayer._colour_shortfall], [method Evaluator.land_value] and
## the two board readings [method AiPlayer._size_and_aim] already opens
## with.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.tutors_for_the_turn = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.tutors_for_the_turn = false
	return profile


## Put [param names] into [param pid]'s library, in the order given (the
## first is the first candidate a search offers, which is what decides a
## tie under the null).
func _library(pid: int, names: Array) -> Array[CardInstance]:
	g.players[pid].library.clear()
	var out: Array[CardInstance] = []
	for n in names:
		var inst := _make_instance(pid, n)
		inst.zone = Mtg.Zone.LIBRARY
		g.players[pid].library.append(inst)
		out.append(inst)
	return out


## The library as a search offers it — the ask a Demonic Tutor makes.
func _candidates(pid: int) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for inst in g.players[pid].library:
		out.append(inst)
	return out


## What the seat fetches from its own library right now.
func _fetch(ai: AiPlayer, prompt := "Search your library for a card") -> String:
	var picked := ai.answer_card(g, 0, _candidates(0), prompt)
	return "" if picked == null else picked.data.card_name


func _lands(pid: int, names: Array) -> void:
	for n in names:
		put_battlefield(pid, n)


# ------------------------------------------------------------- the seam --

func test_the_seam_is_a_library_ask_and_nothing_else() -> void:
	var ai := _ai(_on())
	_library(0, ["Ancestral Recall", "Serra Angel"])
	assert_true(ai._tutor_ask(0, _candidates(0)), "a search of our own library")
	# A hand ask is not one: a Sylvan Library's discard, a Mind Twist.
	var in_hand: Array[CardInstance] = [give_hand(0, "Serra Angel")]
	assert_false(ai._tutor_ask(0, in_hand), "a card in hand is not a fetch")
	# Nor is a board ask: which permanent a Clone copies, which body a
	# Lord of the Pit eats.
	var on_table: Array[CardInstance] = [put_battlefield(0, "Grizzly Bears")]
	assert_false(ai._tutor_ask(0, on_table))
	# Nor is a search of THEIR library — no card in this pool makes one,
	# and the rule refuses it before one does.
	_library(1, ["Serra Angel"])
	var theirs: Array[CardInstance] = [g.players[1].library[0]]
	assert_false(ai._tutor_ask(0, theirs))
	assert_false(ai._tutor_ask(0, [] as Array[CardInstance]), "an empty search")


# ----------------------------------------------------- a land when short --

func test_it_fetches_a_land_when_short_and_the_null_fetches_the_tome() -> void:
	# Two lands, a hand of three- and four-drops with no land in it, and
	# nothing our two sources can cast: the fetch is the land drop.
	for arm in ["on", "off"]:
		before_each()
		var ai := _ai(_on() if arm == "on" else _off())
		_lands(0, ["Underground Sea", "Tundra"])
		give_hand(0, "The Abyss")
		give_hand(0, "Disrupting Scepter")
		_library(0, ["Library of Alexandria", "Swords to Plowshares",
			"Jayemdae Tome", "Ancestral Recall"])
		if arm == "on":
			assert_eq(_fetch(ai), "Library of Alexandria",
				"short of land, so a land — and the best one offered")
		else:
			assert_eq(_fetch(ai), "Jayemdae Tome",
				"the null takes the dearest card in the library")


func test_the_land_is_the_one_that_fixes_the_colour() -> void:
	# Untamed Wilds' own ask: only basics are offered, so the whole
	# decision is WHICH. Three Forests down and a {B}{B} card in hand.
	for arm in ["on", "off"]:
		before_each()
		var ai := _ai(_on() if arm == "on" else _off())
		_lands(0, ["Forest", "Forest", "Forest"])
		give_hand(0, "Sengir Vampire")
		_library(0, ["Forest", "Forest", "Swamp", "Island"])
		var expected := "Swamp" if arm == "on" else "Forest"
		assert_eq(_fetch(ai, "Search your library for a basic land card"),
			expected, arm)


func test_no_land_is_fetched_when_the_drop_is_already_in_hand() -> void:
	# Forge's first clause, and ours: a land in hand covers the turn, so
	# the search is for a spell.
	var ai := _ai(_on())
	_lands(0, ["Underground Sea", "Tundra"])
	give_hand(0, "The Abyss")
	give_hand(0, "Island")
	_library(0, ["Library of Alexandria", "Ancestral Recall"])
	assert_eq(_fetch(ai), "Ancestral Recall")


func test_no_land_is_fetched_when_the_hand_can_already_be_cast() -> void:
	# Forge's third clause. Two sources and a Counterspell in hand: we are
	# short of land but not stuck, and the fetch is worth more as a spell.
	var ai := _ai(_on())
	_lands(0, ["Underground Sea", "Tundra"])
	give_hand(0, "Counterspell")
	_library(0, ["Library of Alexandria", "Swords to Plowshares"])
	assert_eq(_fetch(ai), "Swords to Plowshares")


func test_the_castable_clause_reads_the_board_and_not_what_is_untapped() -> void:
	# A search resolves with the lands that paid for it TAPPED, so a
	# clause asked of the open pool would read "nothing castable" on every
	# board in the game. It is asked of the permanents that make mana.
	var ai := _ai(_on())
	_lands(0, ["Underground Sea", "Tundra"])
	assert_eq(ai._mana_permanents(g), 2)
	for inst in g.players[0].battlefield:
		g.tap_permanent(inst)
	assert_eq(ai._mana_permanents(g), 2, "they untap (CR 502.1)")


func test_a_seat_with_lands_enough_does_not_fetch_one() -> void:
	var ai := _ai(_on())
	_lands(0, ["Plains", "Plains", "Plains", "Plains"])
	_library(0, ["Plains", "Serra Angel"])
	assert_eq(_fetch(ai), "Serra Angel", "four lands is not short")


# ------------------------------------------------ what next turn can cast --

func test_it_takes_the_creature_next_turn_can_cast() -> void:
	# Three sources, so next turn pays four. A Mahamoti Djinn is seven.
	for arm in ["on", "off"]:
		before_each()
		var ai := _ai(_on() if arm == "on" else _off())
		_lands(0, ["Underground Sea", "Tundra", "City of Brass"])
		give_hand(0, "Island")
		_library(0, ["Mahamoti Djinn", "Hypnotic Specter", "Swords to Plowshares"])
		var expected := "Hypnotic Specter" if arm == "on" else "Mahamoti Djinn"
		assert_eq(_fetch(ai), expected, arm)


func test_the_filter_lets_everything_through_once_the_mana_is_there() -> void:
	# No turn number gates the step: late in a game every candidate fits
	# and the pick is the board's, which is Forge's `turn <= 3` without
	# the number.
	var ai := _ai(_on())
	_lands(0, ["Island", "Island", "Island", "Island", "Island", "Island",
		"Island", "Island"])
	give_hand(0, "Island")
	_library(0, ["Mahamoti Djinn", "Hypnotic Specter"])
	assert_eq(_fetch(ai), "Mahamoti Djinn", "eight sources reach the seven-drop")


func test_nothing_castable_falls_back_to_the_whole_library() -> void:
	# A search that can only offer cards out of reach still answers with
	# one: "fail to find" is legal but is never the better line here.
	var ai := _ai(_on())
	_lands(0, ["Island", "Island", "Island", "Island"])
	give_hand(0, "Counterspell")
	_library(0, ["Mahamoti Djinn", "Colossus of Sardia"])
	assert_eq(_fetch(ai), "Colossus of Sardia", "the best of what is left")


# -------------------------------------------- the card worth most on this board --

func test_the_sweeper_is_the_pick_only_when_the_board_wants_it() -> void:
	# Wrath of God and Jayemdae Tome both print at 5.0 and the Tome is
	# offered first, so the null answers "Tome" whatever is on the table.
	for arm in ["on", "off"]:
		before_each()
		var ai := _ai(_on() if arm == "on" else _off())
		_lands(0, ["Plains", "Plains", "Plains", "Plains", "Plains"])
		give_hand(0, "Island")
		put_battlefield(1, "Serra Angel")
		put_battlefield(1, "White Knight")
		put_battlefield(1, "White Knight")
		put_battlefield(1, "Savannah Lions")
		_library(0, ["Jayemdae Tome", "Wrath of God", "Disrupting Scepter"])
		var expected := "Wrath of God" if arm == "on" else "Jayemdae Tome"
		assert_eq(_fetch(ai), expected, arm)


func test_the_same_library_across_an_empty_board_takes_the_tome() -> void:
	# The other half of the same pin: the reading is the BOARD's, not the
	# card's, so with nothing to sweep the Wrath is the worst card offered.
	for arm in ["on", "off"]:
		before_each()
		var ai := _ai(_on() if arm == "on" else _off())
		_lands(0, ["Plains", "Plains", "Plains", "Plains", "Plains"])
		give_hand(0, "Island")
		_library(0, ["Jayemdae Tome", "Wrath of God", "Disrupting Scepter"])
		assert_eq(_fetch(ai), "Jayemdae Tome", arm)


func test_a_leveller_is_read_by_what_each_side_would_lose() -> void:
	# Balance prices at 3.0 printed — below a Serra Angel — so the null
	# never fetches it. With the knob it is read the way the caster reads
	# it ([method AiPlayer._level_value]), which on a board of fourteen
	# lands to four is the best card in the deck.
	for arm in ["on", "off"]:
		before_each()
		var ai := _ai(_on() if arm == "on" else _off())
		for _i in 4:
			put_battlefield(0, "Plains")
		for _i in 14:
			put_battlefield(1, "Plains")
		put_battlefield(1, "Serra Angel")
		put_battlefield(1, "Serra Angel")
		give_hand(0, "Island")
		_library(0, ["Balance", "Serra Angel"])
		var expected := "Balance" if arm == "on" else "Serra Angel"
		assert_eq(_fetch(ai), expected, arm)


func test_the_leveller_reading_needs_the_leveller_s_own_knob() -> void:
	# [method AiPlayer._level_value] belongs to levels_boards; with that
	# knob off the tutor prices a Balance the way the caster does, which
	# is its printed worth.
	var profile := _on()
	profile.levels_boards = false
	var ai := _ai(profile)
	for _i in 4:
		put_battlefield(0, "Plains")
	for _i in 14:
		put_battlefield(1, "Plains")
	give_hand(0, "Island")
	_library(0, ["Balance", "Serra Angel"])
	assert_eq(_fetch(ai), "Serra Angel", "3.0 against a 4/4 flier")


# ------------------------------------------- what the knob must not touch --

func test_a_cost_still_eats_the_least_valuable() -> void:
	# The knob sits after the cost and tribute branches, so neither moves.
	var ai := _ai(_on())
	var elf := put_battlefield(0, "Llanowar Elves")
	put_battlefield(0, "Serra Angel")
	var fodder: Array[CardInstance] = []
	for inst in g.players[0].battlefield:
		fodder.append(inst)
	assert_eq(ai.answer_card(g, 0, fodder, "Sacrifice a creature"), elf)


func test_a_tribute_still_gives_up_the_worst() -> void:
	var ai := _ai(_on())
	var elf := put_battlefield(0, "Llanowar Elves")
	put_battlefield(0, "Serra Angel")
	var fodder: Array[CardInstance] = []
	for inst in g.players[0].battlefield:
		fodder.append(inst)
	assert_eq(ai.answer_card(g, 0, fodder,
		"The Abyss: choose a nonartifact creature to be destroyed"), elf)


func test_an_ordered_ask_is_still_answered_first_come() -> void:
	# Natural Selection's restack comes ranked by the card itself, and the
	# candidates are library cards — the one library ask that must NOT be
	# re-sorted. [member PlayerChoice.ordered] answers it above the knob.
	var ai := _ai(_on())
	var cards := _library(0, ["Swords to Plowshares", "Mahamoti Djinn"])
	var agent := ai as DecisionAgent
	var picked := agent.choose_card(g, 0, cards,
		"Select card order or DONE to shuffle.", true, false, true)
	assert_eq(picked, cards[0], "the card's own order stands")


# ------------------------------------------------------------ the ladder --

func test_the_rung_is_sorcerer_and_wizard() -> void:
	assert_false(AiProfile.apprentice().tutors_for_the_turn)
	assert_false(AiProfile.magician().tutors_for_the_turn)
	assert_true(AiProfile.sorcerer().tutors_for_the_turn)
	assert_true(AiProfile.wizard().tutors_for_the_turn)


func test_the_lab_can_run_both_arms() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("tutors_for_the_turn=off"), "")
	assert_false(profile.tutors_for_the_turn)
	assert_eq(profile.apply_overrides("tutors_for_the_turn=on"), "")
	assert_true(profile.tutors_for_the_turn)
