extends GutTest
## THE SECOND BUG HUNT (2026-10-21), the screens: AutoDeck with a lean or
## a speed it does not know.
##
## WAS: `AutoDeckWindow` restores its wishes from `settings.cfg` checking
## only each value's kind, and `AutoDeck.build` checked the size, the
## rarity and the land kind but not the lean or the speed — so a hand-
## edited `"lean": "fast"` (or a word from another build) reached the
## tables keyed by them, and `Build me a deck` stopped on a script error
## with its window already gone. NOW `build` reads an unknown lean as
## balanced and an unknown speed as medium, as it already read an unknown
## rarity as any.


func before_all() -> void:
	CardRegistry.ensure_loaded()


func _auto() -> AutoDeck:
	var auto := AutoDeck.new()
	auto.pool = AutoDeck.pool_from_names(["Grizzly Bears", "Llanowar Elves", "Giant Growth",
		"Craw Wurm", "Hill Giant", "Lightning Bolt"])
	auto.seed = 4242
	return auto


func test_an_unknown_lean_builds_a_balanced_deck() -> void:
	var auto := _auto()
	auto.lean = "fast"
	var deck := auto.build()
	assert_not_null(deck)
	if deck != null:
		assert_eq(deck.total(), 60)
	assert_eq(auto.lean, AutoDeck.LEAN_BALANCED)


func test_an_unknown_speed_builds_a_medium_deck() -> void:
	var auto := _auto()
	auto.speed = ""
	var deck := auto.build()
	assert_not_null(deck)
	if deck != null:
		assert_eq(deck.total(), 60)
	assert_eq(auto.speed, AutoDeck.SPEED_MEDIUM)


func test_the_known_words_are_kept() -> void:
	var auto := _auto()
	auto.lean = AutoDeck.LEAN_CREATURES
	auto.speed = AutoDeck.SPEED_FAST
	auto.build()
	assert_eq(auto.lean, AutoDeck.LEAN_CREATURES)
	assert_eq(auto.speed, AutoDeck.SPEED_FAST)
