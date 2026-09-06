extends GutTest
## The `@ABILITY` profile ([DeckAbilities]) — which of the 1997 filter's
## thirteen abilities a card HAS and which it GIVES, read off the same
## structured fields the duel engine plays from and, for the rest, off the
## card's own text. Each case below was checked against the printed card
## by hand when the profile was built (2026-09-06); a change that moves
## one of them is a change in the reading, not in the pool.


func before_all() -> void:
	CardRegistry.ensure_loaded()


func _native(card_name: String) -> int:
	return DeckAbilities.native(CardRegistry.get_card(card_name))


func _gives(card_name: String) -> int:
	return DeckAbilities.gives(CardRegistry.get_card(card_name))


func _bit(ability: int) -> int:
	return 1 << ability


# ----------------------------------------------------- the structure --

func test_the_thirteen_are_the_string_tables_own_in_its_own_order() -> void:
	# `@ABILITY` (Menus.txt:366): Flying, First strike, Trample,
	# Regeneration, Banding, Ward, Walk, Poison, Rampage, Web, Stoning,
	# Free Action, Quick draw — the 1997 names, six of which modern
	# players know by other words.
	assert_eq(DeckAbilities.LABELS.size(), 13)
	assert_eq(DeckAbilities.LABELS[DeckAbilities.Ability.FLYING], "Flying")
	assert_eq(DeckAbilities.LABELS[DeckAbilities.Ability.QUICK_DRAW], "Quick draw")
	assert_eq(DeckAbilities.MODERN[DeckAbilities.Ability.WARD], "protection")
	assert_eq(DeckAbilities.MODERN[DeckAbilities.Ability.WALK], "landwalk")
	assert_eq(DeckAbilities.MODERN[DeckAbilities.Ability.WEB], "reach")
	assert_eq(DeckAbilities.MODERN[DeckAbilities.Ability.STONING], "deathtouch")
	assert_eq(DeckAbilities.MODERN[DeckAbilities.Ability.FREE_ACTION], "vigilance")
	assert_eq(DeckAbilities.MODERN[DeckAbilities.Ability.QUICK_DRAW], "haste")
	assert_eq(DeckAbilities.ALL_MASK, (1 << 13) - 1)


# ------------------------------------------------ the structured reads --

func test_a_keyword_creature_is_read_from_its_keywords() -> void:
	assert_eq(_native("Serra Angel"),
		_bit(DeckAbilities.Ability.FLYING) | _bit(DeckAbilities.Ability.FREE_ACTION),
		"flying, and vigilance is the 1997 Free Action")
	assert_eq(_gives("Serra Angel"), 0, "she grants nothing")
	assert_eq(_native("Grizzly Bears"), 0)
	assert_eq(_gives("Grizzly Bears"), 0)


func test_protection_and_landwalk_are_ward_and_walk() -> void:
	assert_eq(_native("Rainbow Knights"),
		_bit(DeckAbilities.Ability.FIRST_STRIKE) | _bit(DeckAbilities.Ability.WARD),
		"protection from a colour of its owner's choice is Ward")
	assert_true((_native("Will-o'-the-Wisp") & _bit(DeckAbilities.Ability.REGENERATION)) != 0,
		"a regeneration cost on the card is native Regeneration")
	assert_true((_native("Will-o'-the-Wisp") & _bit(DeckAbilities.Ability.FLYING)) != 0)


func test_rampage_is_read_from_the_rampage_field() -> void:
	# Gabriel Angelfire also picks its ability each turn — see below.
	assert_true((_native("Gabriel Angelfire") & _bit(DeckAbilities.Ability.RAMPAGE)) != 0)


# ------------------------------------------------------ the text reads --

func test_a_creature_that_gains_an_ability_itself_has_it_natively() -> void:
	# "Giant Shark ... has trample as long as it's been dealt damage":
	# conditional, but the card's own.
	assert_eq(_native("Giant Shark"), _bit(DeckAbilities.Ability.TRAMPLE))
	assert_eq(_gives("Giant Shark"), 0, "it does not lend it")


func test_a_creature_that_gains_and_lends_is_both() -> void:
	# Spitting Slug: "{1}{G}: this creature gains first strike ... otherwise
	# it loses" AND Kobold Overlord: "Kobolds you control have first
	# strike" — both native and gives, for different reasons.
	assert_eq(_native("Spitting Slug"), _bit(DeckAbilities.Ability.FIRST_STRIKE))
	assert_eq(_gives("Spitting Slug"), _bit(DeckAbilities.Ability.FIRST_STRIKE))
	assert_eq(_native("Kobold Overlord"), _bit(DeckAbilities.Ability.FIRST_STRIKE))
	assert_eq(_gives("Kobold Overlord"), _bit(DeckAbilities.Ability.FIRST_STRIKE))


func test_a_lord_gives_and_does_not_have() -> void:
	# Zombie Master: "Other Zombie creatures have swampwalk" and
	# "{B}: Regenerate target Zombie" — it lends two abilities and has
	# neither itself.
	assert_eq(_native("Zombie Master"), 0)
	assert_eq(_gives("Zombie Master"),
		_bit(DeckAbilities.Ability.REGENERATION) | _bit(DeckAbilities.Ability.WALK))


func test_an_aura_gives_its_ability_to_the_enchanted_creature() -> void:
	assert_eq(_gives("Regeneration"), _bit(DeckAbilities.Ability.REGENERATION))
	assert_eq(_native("Regeneration"), 0, "an enchantment has no abilities of its own")
	assert_eq(_gives("Instill Energy"), _bit(DeckAbilities.Ability.QUICK_DRAW),
		"'can attack the turn it comes under your control' is Quick draw")
	assert_eq(_gives("Jump"), _bit(DeckAbilities.Ability.FLYING),
		"an instant that grants flying gives it too")


func test_attacking_without_tapping_is_free_action() -> void:
	# Johan: "attacking doesn't cause creatures you control to tap" —
	# given, not had.
	assert_eq(_gives("Johan"), _bit(DeckAbilities.Ability.FREE_ACTION))
	assert_eq(_native("Johan"), 0)


func test_losing_an_ability_is_not_giving_it() -> void:
	# Earthbind: "enchanted creature loses flying" — the profile's first
	# draft read the quoted word and said Earthbind gives Flying.
	assert_eq(_gives("Earthbind"), 0)
	assert_eq(_native("Earthbind"), 0)


func test_a_choice_of_abilities_is_all_of_them() -> void:
	# Gabriel Angelfire: "choose flying, first strike, trample or rampage 3;
	# it gains that ability until your next upkeep".
	var want := _bit(DeckAbilities.Ability.FLYING) | _bit(DeckAbilities.Ability.FIRST_STRIKE) \
		| _bit(DeckAbilities.Ability.TRAMPLE) | _bit(DeckAbilities.Ability.RAMPAGE)
	assert_eq(_native("Gabriel Angelfire"), want)


func test_a_shapeshifter_that_becomes_a_flier_flies() -> void:
	# Primal Clay: "it becomes ... a 2/2 artifact creature with flying".
	assert_true((_native("Primal Clay") & _bit(DeckAbilities.Ability.FLYING)) != 0)


func test_poison_is_read_where_the_card_deals_it() -> void:
	assert_true((_gives("Serpent Generator") & _bit(DeckAbilities.Ability.POISON)) != 0,
		"the Generator's snakes poison; the Generator itself does not")


func test_nothing_is_read_off_a_spell_with_no_abilities() -> void:
	for card_name in ["Lightning Bolt", "Craw Wurm", "Erg Raiders", "Llanowar Elves"]:
		assert_eq(_native(card_name), 0, card_name)
		assert_eq(_gives(card_name), 0, card_name)


# ---------------------------------------------------------- the cache --

func test_the_profile_is_computed_once_per_card() -> void:
	DeckAbilities.clear_cache()
	var d := CardRegistry.get_card("Serra Angel")
	var first := DeckAbilities.native(d)
	assert_eq(DeckAbilities.native(d), first, "the same answer from the cache")
	DeckAbilities.clear_cache()
	assert_eq(DeckAbilities.native(d), first, "and the same answer read again")


func test_the_whole_pool_profiles_without_a_push_error() -> void:
	var with_any := 0
	for card_name in CardRegistry.all_names():
		var d := CardRegistry.get_card(card_name)
		if DeckAbilities.native(d) != 0 or DeckAbilities.gives(d) != 0:
			with_any += 1
	assert_gt(with_any, 150, "a good share of the pool carries one of the thirteen")
	assert_lt(with_any, 400, "and most of it does not")
