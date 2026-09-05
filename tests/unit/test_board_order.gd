extends GameTest
## ARRANGE CARDS — the order the board and the hand fall into when the
## player asks (`docs/duel-todo.md` §2.3, `game/duel/board_order.gd`).
##
## [BoardOrder] is a pure [RefCounted] of static comparators, so it is
## pinned here in `unit/` rather than through a scene. The golden orders
## are s30's own fixtures (`duel_card_sort_test.go`), card-for-card where
## our pool has the card and substituted where it does not: Shock →
## Chain Lightning (also `{R}`, mana value 1) and Vindicate → Tetsuo
## Umezawa (also multicoloured).


func _names(cards: Array) -> Array:
	var out: Array = []
	for c in cards:
		out.append(c.data.card_name)
	return out


func test_hand_puts_lands_first_then_colour_then_cost() -> void:
	# s30's own hand fixture (duel_card_sort_test.go:70-104), shuffled the
	# way it shuffles it.
	var hand: Array = []
	for card_name in ["Lightning Bolt", "Plains", "Counterspell", "Bayou",
			"Chain Lightning", "Healing Salve", "Forest", "Fireball",
			"Tetsuo Umezawa", "Sol Ring"]:
		hand.append(give_hand(0, card_name))
	assert_eq(_names(BoardOrder.hand(hand)), [
		# Lands lead, by name and nothing else.
		"Bayou", "Forest", "Plains",
		# Then WUBRG, mana value, name. Fireball's {X} counts 0 (CR 203.3b),
		# so it arranges as a red one-drop between the other two.
		"Healing Salve",                                   # W
		"Counterspell",                                    # U
		"Chain Lightning", "Fireball", "Lightning Bolt",   # R, all mv 1
		"Tetsuo Umezawa",                                  # gold
		"Sol Ring",                                        # colourless
	])


func test_two_lands_sort_by_name_only() -> void:
	# The early-stop branch: a land never consults colour rank or mana
	# value, so Bayou (gold, mv 0) still leads Plains on the name alone.
	var hand: Array = [give_hand(0, "Plains"), give_hand(0, "Bayou")]
	assert_eq(_names(BoardOrder.hand(hand)), ["Bayou", "Plains"])


func test_colour_rank_is_wubrg_then_gold_then_colourless() -> void:
	var rank := func(card_name: String) -> int:
		return BoardOrder.color_rank(CardRegistry.get_card(card_name))
	assert_eq(rank.call("Healing Salve"), 1, "White")
	assert_eq(rank.call("Counterspell"), 2, "Blue")
	assert_eq(rank.call("Dark Ritual"), 3, "Black")
	assert_eq(rank.call("Lightning Bolt"), 4, "Red")
	assert_eq(rank.call("Giant Growth"), 5, "Green")
	assert_eq(rank.call("Tetsuo Umezawa"), BoardOrder.RANK_GOLD)
	assert_eq(rank.call("Sol Ring"), BoardOrder.RANK_COLORLESS)


func test_sorting_does_not_mutate_the_input() -> void:
	# Load-bearing twice over: s30 pins it contractually, and the arrays we
	# are handed are the ENGINE's own zone arrays — sorting one in place
	# would reorder the battlefield itself.
	var hand: Array = [give_hand(0, "Lightning Bolt"), give_hand(0, "Forest")]
	BoardOrder.hand(hand)
	assert_eq(_names(hand), ["Lightning Bolt", "Forest"])
	var field: Array = [put_battlefield(0, "Grizzly Bears"),
		put_battlefield(0, "Shivan Dragon")]
	BoardOrder.creatures(field)
	assert_eq(_names(field), ["Grizzly Bears", "Shivan Dragon"])


func test_creatures_sort_by_power_then_toughness_descending() -> void:
	# s30's creature fixture, including the 0/8 wall that goes LAST despite
	# the biggest toughness on the board.
	var field: Array = []
	for card_name in ["Grizzly Bears", "Shivan Dragon", "Wall of Stone",
			"Hill Giant", "Air Elemental", "Sea Serpent"]:
		field.append(put_battlefield(0, card_name))
	g.recalculate()
	assert_eq(_names(BoardOrder.creatures(field)), [
		"Sea Serpent",    # 5/5, tie broken by name
		"Shivan Dragon",  # 5/5
		"Air Elemental",  # 4/4
		"Hill Giant",     # 3/3
		"Grizzly Bears",  # 2/2
		"Wall of Stone",  # 0/8
	])


func test_creature_order_reads_live_power() -> void:
	# THE ONE s30 GETS WRONG (it reads its snapshot's BASE numbers, which is
	# its bug rather than the order's definition): under Crusade the white
	# 2/2 becomes a 3/3 and must overtake the red 2/3 it used to sit behind.
	# Printed numbers would put the Minotaur first on toughness — CONTRIBUTING.md
	# rule 5 is what makes this assertion the other way round.
	var knight := put_battlefield(0, "White Knight")       # 2/2 white
	var minotaur := put_battlefield(0, "Hurloon Minotaur") # 2/3 red
	put_battlefield(0, "Crusade")                          # +1/+1 to white
	g.recalculate()
	assert_eq(knight.cur_power, 3, "Crusade is in play")
	assert_eq(_names(BoardOrder.creatures([minotaur, knight])),
		["White Knight", "Hurloon Minotaur"])


func test_lands_sort_by_name_then_untapped_first() -> void:
	var tapped_mountain := put_battlefield(0, "Mountain")
	var tapped_forest := put_battlefield(0, "Forest")
	var mountain := put_battlefield(0, "Mountain")
	var forest := put_battlefield(0, "Forest")
	tapped_mountain.tapped = true
	tapped_forest.tapped = true
	var order := BoardOrder.lands(
		[tapped_mountain, tapped_forest, mountain, forest])
	assert_eq(_names(order), ["Forest", "Forest", "Mountain", "Mountain"])
	assert_eq([order[0].tapped, order[1].tapped, order[2].tapped,
		order[3].tapped], [false, true, false, true],
		"untapped before tapped inside a name, so tapping walks the group")


func test_the_order_is_stable_across_repeated_arranges() -> void:
	# Array.sort_custom is not a stable sort, so identical cards would
	# otherwise trade places on every refresh — sixty times a second.
	var field: Array = []
	for _i in 6:
		field.append(put_battlefield(0, "Forest"))
	var first := BoardOrder.lands(field)
	for _i in 5:
		assert_eq(BoardOrder.lands(field), first)
