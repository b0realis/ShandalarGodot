extends GameTest
## A RETUNED LAND WEARS THE NEW LAND'S ART — `docs/duel-todo.md` §2.12.
##
## s30's `permanentArtName` (`duel.go:337-371`, pinned by
## `duel_land_art_test.go`) redraws a land whose live basic subtype has
## stopped matching its printed one. The ORIGINAL supports it from the
## other end: `Duel.hlp`, topic **Territory**, gives a card's mini-menu an
## **Original Type** entry — *"shows you what this card was when it was
## cast, before any spells and effects changed it"* — which only earns its
## place on a table where the card in play already shows what it BECAME.
##
## CR 305.7 is the rule behind it: a land retuned to a basic land type
## loses the abilities from its rules text and gains that type's mana
## ability, so under Blood Moon a Strip Mine really is nothing but a
## Mountain.



func test_an_untouched_land_draws_its_own_art() -> void:
	var forest := put_battlefield(0, "Forest")
	assert_eq(MiniCard.art_name(forest), "Forest")
	var tundra := put_battlefield(0, "Tundra")
	assert_eq(MiniCard.art_name(tundra), "Tundra",
		"a dual's printed types are its own; nothing has changed")


func test_a_non_land_is_never_redrawn() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_eq(MiniCard.art_name(bear), "Grizzly Bears")


func test_blood_moon_turns_every_nonbasic_into_a_Mountain() -> void:
	var strip := put_battlefield(0, "Strip Mine")
	put_battlefield(1, "Blood Moon")
	g.recalculate()
	assert_eq(MiniCard.art_name(strip), "Mountain",
		"CR 305.7 — in play it IS a Mountain, so it looks like one")


func test_blood_moon_leaves_the_basics_alone() -> void:
	var forest := put_battlefield(0, "Forest")
	put_battlefield(1, "Blood Moon")
	g.recalculate()
	assert_eq(MiniCard.art_name(forest), "Forest",
		"Blood Moon only reads NONBASIC lands")


func test_evil_presence_redraws_the_land_it_enchants() -> void:
	var tundra := put_battlefield(0, "Tundra")
	var curse := put_battlefield(1, "Evil Presence")
	curse.attached_to = tundra.id
	g.recalculate()
	assert_eq(MiniCard.art_name(tundra), "Swamp")


func test_removing_the_effect_restores_the_printed_art() -> void:
	var strip := put_battlefield(0, "Strip Mine")
	var moon := put_battlefield(1, "Blood Moon")
	g.recalculate()
	assert_eq(MiniCard.art_name(strip), "Mountain")
	g.destroy(moon)
	g.recalculate()
	assert_eq(MiniCard.art_name(strip), "Strip Mine",
		"the art comes back with the land")
