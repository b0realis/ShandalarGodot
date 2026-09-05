extends GutTest
## THE FIVE FORMATS ([DeckFormat]) — `Unrestricted` / `Wild` /
## `Restricted (Type 1)` / `Tournament (Type 1.5)` / `Highlander`.
##
## Two halves are pinned here and they are different claims:
##
##   * [method DeckFormat.classify] must reproduce the ORIGINAL's own
##     `check_deck_type()` (`shandalar-src/src/deck/deckdll.cpp:2908`) —
##     including its early return for Highlander and its most-permissive-
##     wins resolution.
##   * [method DeckFormat.legal] must refuse exactly what that algorithm's
##     branches say is out of place, with a reason that names the card.
##
## The card names used are real cards from our pool, so a rule that stops
## matching the registry fails here rather than silently passing every
## deck.


func _deck(pairs: Array) -> Array:
	var out: Array = []
	for pair in pairs:
		for _i in pair[0]:
			out.append(pair[1])
	return out


func test_the_five_names_are_the_1997_strings_in_the_1997_order() -> void:
	# `@SHELLPAGE_MULTIDUEL`, Program/Text.res:2854-2859.
	assert_eq(DeckFormat.ORDER, ["Unrestricted", "Wild", "Restricted (Type 1)",
		"Tournament (Type 1.5)", "Highlander"] as Array[String])


func test_every_format_has_a_one_line_summary() -> void:
	for format in DeckFormat.ORDER:
		assert_true(DeckFormat.SUMMARY.has(format), format)
		assert_ne(String(DeckFormat.SUMMARY[format]), "", format)


# ============================================== basics are never counted ==

func test_basic_lands_are_exempt_from_every_limit() -> void:
	assert_true(DeckFormat.is_basic("Plains"))
	assert_true(DeckFormat.is_basic("Mountain"))
	assert_false(DeckFormat.is_basic("Strip Mine"), "a nonbasic land is not basic")
	assert_false(DeckFormat.is_basic("Grizzly Bears"))
	var lands := _deck([[40, "Plains"]])
	for format in DeckFormat.ORDER:
		assert_eq(DeckFormat.legal(lands, format), "",
			"40 Plains is legal in %s" % format)


# =========================================================== Highlander ==

func test_highlander_is_one_of_each_and_needs_no_list() -> void:
	var singleton := ["Grizzly Bears", "Lightning Bolt", "Serra Angel"]
	assert_eq(DeckFormat.legal(singleton, DeckFormat.HIGHLANDER), "")
	var doubled := _deck([[2, "Grizzly Bears"], [1, "Lightning Bolt"]])
	var refusal := DeckFormat.legal(doubled, DeckFormat.HIGHLANDER)
	assert_ne(refusal, "")
	assert_true(refusal.contains("Grizzly Bears"), "the refusal names the card")
	# ...and basics are still exempt, which is the whole "except basic
	# lands" clause.
	assert_eq(DeckFormat.legal(singleton + _deck([[20, "Forest"]]),
		DeckFormat.HIGHLANDER), "")


func test_a_singleton_deck_classifies_as_highlander_whatever_is_in_it() -> void:
	# The original checks Highlander FIRST and returns immediately, so a
	# singleton Black Lotus does not drag the deck down the ladder.
	assert_eq(DeckFormat.classify(["Black Lotus", "Grizzly Bears"]),
		DeckFormat.HIGHLANDER)


# ============================================================ the lists ==

func test_the_restricted_list_is_the_games_own_table() -> void:
	# Spot-checked against `deckdll.cpp:652-702`. The whole table is kept
	# by name; these are the entries our card pool can actually produce.
	for card_name in ["Black Lotus", "Ancestral Recall", "Time Walk",
			"Timetwister", "Mox Ruby", "Sol Ring", "Library of Alexandria",
			"Strip Mine", "Wheel of Fortune", "Demonic Tutor"]:
		assert_true(DeckFormat.RESTRICTED.has(card_name), card_name)
		assert_true(CardRegistry.has_card(card_name),
			"%s is in our pool, so the rule can actually fire" % card_name)


func test_the_ante_cards_are_banned_and_are_in_our_pool() -> void:
	# `deckdll.cpp:642-650` flags these RST_ANTE | RST_BANNED together.
	for card_name in ["Contract from Below", "Darkpact", "Jeweled Bird",
			"Tempest Efreet", "Bronze Tablet", "Demonic Attorney", "Rebirth"]:
		assert_true(DeckFormat.BANNED.has(card_name), card_name)
		assert_true(CardRegistry.has_card(card_name), card_name)


func test_a_banned_card_is_refused_everywhere_but_unrestricted() -> void:
	var deck := _deck([[1, "Contract from Below"], [4, "Grizzly Bears"]])
	assert_eq(DeckFormat.legal(deck, DeckFormat.UNRESTRICTED), "",
		"Unrestricted is the catch-all")
	for format in [DeckFormat.WILD, DeckFormat.RESTRICTED_T1,
			DeckFormat.TOURNAMENT_T15]:
		var refusal := DeckFormat.legal(deck, format)
		assert_ne(refusal, "", format)
		assert_true(refusal.contains("Contract from Below"), format)


# ======================================================= the copy limit ==

func test_five_copies_break_every_format_but_unrestricted() -> void:
	var deck := _deck([[5, "Grizzly Bears"]])
	assert_eq(DeckFormat.legal(deck, DeckFormat.UNRESTRICTED), "")
	for format in [DeckFormat.WILD, DeckFormat.RESTRICTED_T1,
			DeckFormat.TOURNAMENT_T15]:
		assert_true(DeckFormat.legal(deck, format).contains("Grizzly Bears"),
			format)
	assert_eq(DeckFormat.classify(deck), DeckFormat.UNRESTRICTED)


func test_four_copies_are_fine() -> void:
	var deck := _deck([[4, "Grizzly Bears"], [4, "Lightning Bolt"]])
	for format in [DeckFormat.WILD, DeckFormat.RESTRICTED_T1,
			DeckFormat.TOURNAMENT_T15]:
		assert_eq(DeckFormat.legal(deck, format), "", format)
	assert_eq(DeckFormat.classify(deck), DeckFormat.TOURNAMENT_T15,
		"ordinary cards at four make a 1.5 deck")


# ============================== the three formats the lists actually part ==

func test_one_black_lotus_is_type_1_but_not_type_1_5() -> void:
	var deck := _deck([[1, "Black Lotus"], [4, "Grizzly Bears"]])
	assert_eq(DeckFormat.legal(deck, DeckFormat.WILD), "")
	assert_eq(DeckFormat.legal(deck, DeckFormat.RESTRICTED_T1), "",
		"one copy is what Restricted means")
	var refusal := DeckFormat.legal(deck, DeckFormat.TOURNAMENT_T15)
	assert_ne(refusal, "", "1.5 bars the restricted list entirely")
	assert_true(refusal.contains("Black Lotus"))
	assert_eq(DeckFormat.classify(deck), DeckFormat.RESTRICTED_T1)


func test_two_black_lotuses_are_wild_and_nothing_stricter() -> void:
	var deck := _deck([[2, "Black Lotus"], [4, "Grizzly Bears"]])
	assert_eq(DeckFormat.legal(deck, DeckFormat.WILD), "",
		"Wild ignores the restricted list")
	for format in [DeckFormat.RESTRICTED_T1, DeckFormat.TOURNAMENT_T15]:
		assert_true(DeckFormat.legal(deck, format).contains("Black Lotus"),
			format)
	assert_eq(DeckFormat.classify(deck), DeckFormat.WILD)


func test_classify_takes_the_most_permissive_answer() -> void:
	# `deckdll.cpp:3174-3191` walks Unrestricted first and stops at the
	# first hit, so one bad card names the whole deck.
	var deck := _deck([[5, "Grizzly Bears"], [1, "Black Lotus"],
		[4, "Lightning Bolt"]])
	assert_eq(DeckFormat.classify(deck), DeckFormat.UNRESTRICTED)


func test_a_deck_is_always_legal_in_the_format_it_classifies_as() -> void:
	# The invariant that ties the two halves together: `classify` files a
	# deck under a name, and `legal` must agree that it belongs there.
	# Run over the real shipped decks, which is where it caught something:
	# Blue Skies plays an Ancestral Recall and Mountain Artillery a Sol
	# Ring, so neither is Tournament (Type 1.5) — both are Restricted
	# (Type 1), and the rule really does fire on decks we ship.
	for path in DeckStore.deck_paths_in(DeckStore.SHIPPED_DIR):
		var deck := DeckList.load_file(path, true)
		var format := DeckFormat.classify(deck.cards)
		assert_eq(DeckFormat.legal(deck.cards, format), "",
			"%s is legal in %s" % [path.get_file(), format])
		assert_ne(format, DeckFormat.UNRESTRICTED,
			"%s holds no banned card and nothing five times" % path.get_file())


func test_the_shipped_decks_sit_where_their_restricted_cards_put_them() -> void:
	# `big_green.deck` MOVED on 2026-09-01, and the move is the point: its
	# single Regrowth was legal in Tournament (Type 1.5) only because
	# Regrowth had fallen off the MODERN Vintage list, which is the list we
	# were carrying. The DCI restricted it from March 1994 until 2013, so
	# the era-correct list has it and the deck is Restricted (Type 1). The
	# deck itself is untouched and still legal — one copy is what
	# Restricted (Type 1) allows.
	var expected := {
		"blue_skies.deck": DeckFormat.RESTRICTED_T1,        # Ancestral Recall
		"mountain_artillery.deck": DeckFormat.RESTRICTED_T1,  # Sol Ring
		"big_green.deck": DeckFormat.RESTRICTED_T1,         # Regrowth
		"black_red_raiders.deck": DeckFormat.TOURNAMENT_T15,
		"white_knights.deck": DeckFormat.TOURNAMENT_T15,
	}
	for path in DeckStore.deck_paths_in(DeckStore.SHIPPED_DIR):
		var file := path.get_file()
		if not expected.has(file):
			continue
		assert_eq(DeckFormat.classify(DeckList.load_file(path, true).cards),
			expected[file], file)


func test_an_empty_deck_offends_nothing() -> void:
	for format in DeckFormat.ORDER:
		assert_eq(DeckFormat.legal([], format), "", format)


# ================================== THIRD AUDIT PASS (2026-09-01) ==
# THE SIDEBOARD WAS NEVER INSPECTED. `legal()` took one array and every
# caller passed `DeckList.cards`, so a `Restricted (Type 1)` deck could
# carry four Black Lotus in its `SB:` lines and pass — in the battle-setup
# screen, in the Deck Lab's `--format` flag, everywhere. That was harmless
# only while nothing read `SB:`; `Side&board between duels` now swaps
# those cards INTO the deck between the duels of a match.
#
# Counting the two piles together is the MODERN convention and is marked
# as such at the site: the original's classifier walks one pile because
# the 1997 Deck Builder had no sideboard at all.

func test_a_banned_card_hidden_in_the_sideboard_is_caught() -> void:
	var main := _deck([[4, "Grizzly Bears"], [20, "Forest"]])
	var side := ["Contract from Below"]
	assert_eq(DeckFormat.legal(main, DeckFormat.TOURNAMENT_T15), "",
		"the maindeck alone offends nothing — this is what used to pass")
	for format in [DeckFormat.WILD, DeckFormat.RESTRICTED_T1,
			DeckFormat.TOURNAMENT_T15]:
		var refusal := DeckFormat.legal(main, format, side)
		assert_ne(refusal, "", "%s catches it now" % format)
		assert_true(refusal.contains("Contract from Below"),
			"the refusal names the card")
		assert_true(refusal.contains("sideboard"),
			"and says where it is, or the player cannot find it")


func test_a_restricted_card_in_the_sideboard_counts_against_type_1() -> void:
	var main := ["Black Lotus"] + _deck([[20, "Forest"]])
	assert_eq(DeckFormat.legal(main, DeckFormat.RESTRICTED_T1), "",
		"one Black Lotus is Type 1 legal")
	var refusal := DeckFormat.legal(main, DeckFormat.RESTRICTED_T1,
		["Black Lotus"])
	assert_ne(refusal, "", "a second copy in the sideboard is still a second copy")
	assert_true(refusal.contains("Black Lotus"))


func test_the_copy_limit_counts_both_piles() -> void:
	# The owner's own example: four Lightning Bolt in the deck plus one in
	# the sideboard is five copies.
	var main := _deck([[4, "Lightning Bolt"], [20, "Mountain"]])
	assert_eq(DeckFormat.legal(main, DeckFormat.WILD), "", "four is fine")
	var refusal := DeckFormat.legal(main, DeckFormat.WILD, ["Lightning Bolt"])
	assert_ne(refusal, "", "the fifth is not")
	assert_true(refusal.contains("5 copies"), refusal)


func test_highlander_counts_the_sideboard_too() -> void:
	var main := ["Grizzly Bears", "Lightning Bolt"]
	assert_eq(DeckFormat.legal(main, DeckFormat.HIGHLANDER), "")
	assert_ne(DeckFormat.legal(main, DeckFormat.HIGHLANDER, ["Grizzly Bears"]),
		"", "a second copy is a second copy wherever it sits")


func test_unrestricted_still_allows_anything_in_either_pile() -> void:
	assert_eq(DeckFormat.legal(_deck([[9, "Lightning Bolt"]]),
		DeckFormat.UNRESTRICTED,
		["Contract from Below", "Contract from Below"]), "")


func test_an_empty_sideboard_changes_nothing() -> void:
	# The compatibility promise: every caller that passes one pile is
	# checked exactly as it was before this parameter existed.
	var main := _deck([[4, "Grizzly Bears"], [1, "Black Lotus"]])
	for format in DeckFormat.ORDER:
		assert_eq(DeckFormat.legal(main, format, []),
			DeckFormat.legal(main, format), format)
		assert_eq(DeckFormat.classify(main, []), DeckFormat.classify(main))


func test_the_shipped_decks_are_legal_with_their_sideboards() -> void:
	# The decks we SHIP have to satisfy the rule we just started
	# enforcing. Three of them did not when this test was written: Black-
	# Red Raiders held six Terror across the two piles, Blue Skies five
	# Counterspell and White Knights five Disenchant. Their sideboards were
	# rebalanced in the same pass rather than the rule being softened.
	for path in DeckStore.deck_paths_in(DeckStore.SHIPPED_DIR):
		var deck := DeckList.load_file(path, true)
		assert_eq(deck.sideboard.size(), 15, "%s has a sideboard" % path.get_file())
		var format := DeckFormat.classify(deck.cards, deck.sideboard)
		assert_eq(DeckFormat.legal(deck.cards, format, deck.sideboard), "",
			"%s is legal in %s with its sideboard" % [path.get_file(), format])
		var counted := DeckFormat.nonbasic_counts(
			DeckFormat.both_piles(deck.cards, deck.sideboard))
		for card_name in counted:
			assert_lte(int(counted[card_name]), DeckFormat.COPY_LIMIT,
				"%s: %s across both piles" % [path.get_file(), card_name])


# ================== THE ERA-CORRECT RESTRICTED LIST (2026-09-01) ==
# THE BUG: [constant DeckFormat.RESTRICTED] was the MODERN Vintage list,
# kept on the argument that *"the 1997 card pool does the historical
# filtering — what survives the intersection is exactly the era's list."*
# That argument works in one direction only. It filters out cards ADDED to
# the list after 1997 (they are not in our pool, so they never match); it
# cannot restore cards REMOVED from it since, and those ARE in our pool.
# Eleven of them were going unflagged, so the game was telling the player
# a deck was Tournament-legal when the era says it was not.
#
# The list below is the DCI's own, as printed in _The Duelist_ #22
# (1 January 1998) — a contemporaneous printed source about paper Magic,
# so it ranks with the 1998 Advanced Strategy Guide rather than with the
# game's own artefacts. Twenty-five cards; these are the ones our pool
# actually contains.

## Every card on the 1 January 1998 Classic (Type 1) restricted list that
## this project implements. The other names on that list (the Moxes and so
## on) are already covered by the tests above.
const ERA_RESTRICTED_IN_POOL: Array[String] = [
	"Ancestral Recall", "Balance", "Berserk", "Black Lotus", "Black Vise",
	"Braingeyser", "Demonic Tutor", "Fastbond", "Fork", "Ivory Tower",
	"Library of Alexandria", "Maze of Ith", "Mirror Universe",
	"Mox Emerald", "Mox Jet", "Mox Pearl", "Mox Ruby", "Mox Sapphire",
	"Recall", "Regrowth", "Sol Ring", "Time Walk", "Timetwister",
	"Underworld Dreams", "Wheel of Fortune",
]

## The eleven that were MISSING — the bug, named. Every one is in the pool
## and every one has since been unrestricted in Vintage, which is exactly
## why the modern table did not carry them.
const THE_ELEVEN: Array[String] = [
	"Berserk", "Black Vise", "Braingeyser", "Fork", "Ivory Tower",
	"Maze of Ith", "Mind Twist", "Mirror Universe", "Recall", "Regrowth",
	"Underworld Dreams",
]


func test_every_era_restricted_card_we_implement_is_on_the_list() -> void:
	CardRegistry.ensure_loaded()
	for card_name in ERA_RESTRICTED_IN_POOL:
		assert_true(CardRegistry.has_card(card_name),
			"%s is in the pool (if it is not, drop it from this list)" % card_name)
		assert_true(DeckFormat.RESTRICTED.has(card_name),
			"%s is on the DCI's 1998 Type 1 restricted list" % card_name)


func test_the_eleven_that_were_missing_are_flagged_now() -> void:
	# The regression this whole section exists for: each of these, alone,
	# used to pass Tournament (Type 1.5) — the format that bars restricted
	# cards entirely.
	for card_name in THE_ELEVEN:
		assert_true(CardRegistry.has_card(card_name),
			"%s is in our pool, which is what made this a real bug" % card_name)
		assert_ne(DeckFormat.legal([card_name], DeckFormat.TOURNAMENT_T15), "",
			"one %s is barred from Tournament (Type 1.5)" % card_name)
		assert_eq(DeckFormat.legal([card_name], DeckFormat.RESTRICTED_T1), "",
			"...and one is exactly what Restricted (Type 1) allows")
		assert_ne(DeckFormat.legal([card_name, card_name],
			DeckFormat.RESTRICTED_T1), "", "but two %s is not" % card_name)


func test_the_intersection_argument_is_only_true_one_way() -> void:
	# The reasoning the bug hid behind, stated as a test so it cannot come
	# back. Cards ADDED to the list after 1997 really are harmless — they
	# are not in the pool, so no deck can hold one...
	for card_name in ["Treasure Cruise", "Dig Through Time", "Ponder",
			"Trinisphere", "Tolarian Academy"]:
		assert_true(DeckFormat.RESTRICTED.has(card_name), card_name)
		assert_false(CardRegistry.has_card(card_name),
			"%s is a decade too late for this pool" % card_name)
	# ...but cards REMOVED from it since are in the pool and needed adding
	# by hand, which is the half the argument missed.
	for card_name in THE_ELEVEN:
		assert_true(CardRegistry.has_card(card_name), card_name)


func test_the_modern_entries_our_pool_holds_are_recorded_not_hidden() -> void:
	# The other direction, and it is left ALONE on purpose: these three are
	# on the modern Vintage list, are in our pool, and are NOT on the 1998
	# list. Removing a restriction loosens the rules, so the decision is
	# the owner's (docs/ROADMAP.md) — this test just pins that we know.
	for card_name in ["Mana Crypt", "Mana Vault", "Time Vault"]:
		assert_true(CardRegistry.has_card(card_name), card_name)
		assert_true(DeckFormat.RESTRICTED.has(card_name),
			"%s stays restricted until the owner says otherwise" % card_name)
		assert_false(ERA_RESTRICTED_IN_POOL.has(card_name),
			"%s is not on the 1998 list" % card_name)


func test_the_shipped_decks_are_still_legal_under_the_era_list() -> void:
	# "Check what this breaks." One deck moved — big_green, for its single
	# Regrowth — and it moved from Tournament (Type 1.5) to Restricted
	# (Type 1), which is a format it is legal in. No deck was rebalanced.
	for path in DeckStore.deck_paths_in(DeckStore.SHIPPED_DIR):
		var deck := DeckList.load_file(path, true)
		var format := DeckFormat.classify(deck.cards, deck.sideboard)
		assert_eq(DeckFormat.legal(deck.cards, format, deck.sideboard), "",
			"%s is legal in %s" % [path.get_file(), format])
		assert_ne(format, DeckFormat.UNRESTRICTED,
			"%s is not the catch-all" % path.get_file())


# ============ THE WHOLE ANALYSIS AT ONCE — `offences` (2026-09-01) ==
# [method DeckFormat.legal] takes ONE format and stops at the FIRST
# refusal, which is what a gate wants. A deck builder wants every offence
# at once, because the player is about to go and fix them and a warning
# that names one of five sends them back four more times.

func test_offences_reports_every_broken_rule_not_just_the_first() -> void:
	var deck := _deck([[5, "Lightning Bolt"], [2, "Black Lotus"],
		[1, "Contract from Below"], [4, "Grizzly Bears"], [20, "Mountain"]])
	var found := DeckFormat.offences(deck)
	assert_eq(found.size(), 3, "three broken rules, three lines")
	var joined := " ".join(found)
	assert_true(joined.contains("Lightning Bolt"), "the copy limit")
	assert_true(joined.contains("Black Lotus"), "the restricted list")
	assert_true(joined.contains("Contract from Below"), "the banned list")
	assert_false(joined.contains("Grizzly Bears"), "four is not an offence")
	assert_false(joined.contains("Mountain"), "and basics are never counted")


func test_offences_and_legal_say_the_same_words_about_a_card() -> void:
	# One vocabulary, not two: the refusal a gate shows and the warning the
	# builder shows are the same sentence about the same card.
	var deck := _deck([[5, "Lightning Bolt"]])
	var refusal := DeckFormat.legal(deck, DeckFormat.WILD)
	var warned: String = DeckFormat.offences(deck)[0]
	assert_true(refusal.ends_with(warned),
		"'%s' ends with '%s'" % [refusal, warned])


func test_a_clean_deck_has_no_offences() -> void:
	assert_eq(DeckFormat.offences(_deck([[4, "Grizzly Bears"],
		[20, "Forest"]])), [] as Array[String])
	assert_eq(DeckFormat.offences([]), [] as Array[String])


func test_one_restricted_card_is_not_an_offence() -> void:
	# It is legal in Restricted (Type 1) and only bars Tournament
	# (Type 1.5), so it is a fact about which format the deck fits —
	# `classify` says that — and not a mistake. Reporting it would cry wolf
	# on every deck with a Sol Ring in it.
	assert_eq(DeckFormat.offences(_deck([[1, "Sol Ring"]])),
		[] as Array[String])
	assert_ne(DeckFormat.legal(_deck([[1, "Sol Ring"]]),
		DeckFormat.TOURNAMENT_T15), "", "...though 1.5 still bars it")
	assert_eq(DeckFormat.classify(_deck([[1, "Sol Ring"], [2, "Forest"],
		[2, "Grizzly Bears"]])), DeckFormat.RESTRICTED_T1,
		"which is what `classify` is for")


func test_the_worse_offence_wins_when_a_card_breaks_two_rules() -> void:
	# Five Contract from Below is banned AND over the limit; it is banned.
	var found := DeckFormat.offences(_deck([[5, "Contract from Below"]]))
	assert_eq(found.size(), 1)
	assert_true(String(found[0]).contains("banned"))


func test_offences_say_how_many_copies_are_in_the_sideboard() -> void:
	var found := DeckFormat.offences(_deck([[3, "Black Lotus"]]),
		_deck([[2, "Black Lotus"]]))
	assert_eq(found.size(), 1)
	assert_true(String(found[0]).contains("5 copies"), "both piles counted")
	assert_true(String(found[0]).contains("2 in the sideboard"),
		"and the player is told where to look")


func test_offences_from_counts_and_from_cards_agree() -> void:
	# The dictionary form is the one the Deck Builder's legality line uses
	# on every card click; it must answer identically to the array form.
	var cards := _deck([[5, "Lightning Bolt"], [2, "Black Lotus"],
		[30, "Mountain"]])
	var side := _deck([[1, "Black Lotus"]])
	assert_eq(DeckFormat.offences_of(
		DeckFormat.nonbasic_counts(DeckFormat.both_piles(cards, side)),
		DeckFormat.nonbasic_counts(side)),
		DeckFormat.offences(cards, side))
