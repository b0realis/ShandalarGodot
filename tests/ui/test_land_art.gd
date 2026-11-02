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


## Issue #4: the table must explain why a Forest wears Island/Plains art.
## CR 305.7 changes land types, not the card's actual name (CR 201).
func _terrain_on_forest(type_index: int) -> Array[CardInstance]:
	var land := put_battlefield(1, "Forest")
	var aura := give_hand(0, "Phantasmal Terrain")
	g.agents[0] = HumanAgent.new()
	g.interactive_choices = true
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(land)]))
	var guard := 0
	while (not g.stack.is_empty() or g.awaiting_choice != null) and guard < 40:
		if g.awaiting_choice != null:
			assert_ok(g.answer_choice(type_index))
		else:
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_lt(guard, 40)
	assert_eq(aura.zone, Mtg.Zone.BATTLEFIELD)
	return [land, aura]

func _mini(land: CardInstance) -> MiniCard:
	var mini := MiniCard.new(land, g)
	add_child_autofree(mini)
	return mini

func test_terrain_names_the_current_type_and_keeps_the_real_card_identity() -> void:
	var pair := _terrain_on_forest(1)
	var land := pair[0]
	var mini := _mini(land)
	assert_eq(mini._name_label.text, "Island")
	assert_true(mini.tooltip_text.begins_with("Forest\n"))
	assert_string_contains(mini.tooltip_text, "Current land type: Island")
	assert_string_contains(mini.tooltip_text, "Printed rules:")
	assert_eq(land.data.card_name, "Forest", "name-based rules still see Forest")
	assert_eq(MiniCard.art_name(land), "Island")
	assert_ok(g.tap_for_mana(1, land))
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.U), 1)
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.G), 0)

func test_removing_terrain_restores_the_name_band_and_tooltip() -> void:
	var pair := _terrain_on_forest(0)
	var mini := _mini(pair[0])
	assert_eq(mini._name_label.text, "Plains")
	g.destroy(pair[1])
	mini.refresh()
	assert_eq(mini._name_label.text, "Forest")
	assert_false(mini.tooltip_text.contains("Current land type:"))
	assert_false(mini.tooltip_text.contains("Printed rules:"))
	assert_eq(MiniCard.art_name(pair[0]), "Forest")


func test_all_five_terrain_choices_use_matching_titles_without_renaming_cards() -> void:
	var types := ["Plains", "Island", "Swamp", "Mountain", "Forest"]
	for index in types.size():
		var pair := _terrain_on_forest(index)
		var mini := _mini(pair[0])
		var title: String = types[index]
		assert_eq(mini._name_label.text, title)
		assert_eq(MiniCard.art_name(pair[0]), types[index])
		assert_eq(pair[0].data.card_name, "Forest")
		var width := mini._name_label.get_theme_font("font").get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, MiniCard.NAME_FONT_SIZE).x
		var room := MiniCard.SIZE.x + mini._name_label.offset_right - mini._name_label.offset_left
		assert_lte(width, room, "the report's basic-land labels fit beside the mana stripes")

func test_nonbasic_land_retyping_keeps_its_identity_in_the_tooltip() -> void:
	var strip := put_battlefield(0, "Strip Mine")
	var tundra := put_battlefield(0, "Tundra")
	var moon := put_battlefield(1, "Blood Moon")
	var strip_mini := _mini(strip)
	assert_eq(strip_mini._name_label.text, "Mountain")
	assert_true(strip_mini.tooltip_text.begins_with("Strip Mine\n"))
	var mini := _mini(tundra)
	assert_eq(mini._name_label.text, "Mountain")
	assert_true(mini.tooltip_text.begins_with("Tundra\n"))
	assert_eq(tundra.data.card_name, "Tundra")
	g.destroy(moon)
	mini.refresh()
	assert_eq(mini._name_label.text, "Tundra")
	assert_false(mini.tooltip_text.contains("Current land type:"))

func test_an_added_land_type_lists_both_types() -> void:
	var forest := put_battlefield(0, "Forest")
	var blanket: CardData = load("res://cards/sets/vis/blanket_of_night.gd").new().build()
	put_synthetic(1, blanket)
	var mini := _mini(forest)
	assert_eq(mini._name_label.text, "Forest/Swamp")
	assert_string_contains(mini.tooltip_text, "Current land types: Forest/Swamp")
	assert_eq(forest.data.card_name, "Forest")
	assert_true(forest.has_subtype("forest"))
	assert_true(forest.has_subtype("swamp"))

func test_tapped_and_piled_lands_share_the_same_current_type_title() -> void:
	var pair := _terrain_on_forest(1)
	var untouched := put_battlefield(1, "Forest")
	assert_ok(g.tap_for_mana(1, pair[0]))
	var pile := CardPile.new()
	pile.game = g
	add_child_autofree(pile)
	pile.populate([pair[0], untouched], false, func(_card): pass,
		func(_card): return MiniCard.Highlight.NONE)
	var found := 0
	for child in pile.find_children("*", "", true, false):
		if not child is MiniCard: continue
		found += 1
		assert_eq(child._name_label.text, "Island" if child.instance == pair[0] else "Forest")
	assert_eq(found, 2)

func test_returning_the_land_to_hand_drops_the_type_annotation() -> void:
	var pair := _terrain_on_forest(1)
	var mini := _mini(pair[0])
	g.return_to_hand(pair[0])
	mini.refresh()
	assert_eq(mini._name_label.text, "Forest")
	assert_false(mini.tooltip_text.contains("Current land type:"))
	assert_eq(MiniCard.art_name(pair[0]), "Forest")

func test_face_down_cards_never_display_the_changed_type_or_original_name() -> void:
	var pair := _terrain_on_forest(1)
	var mini := _mini(pair[0])
	mini.face_down = true
	mini.refresh()
	assert_false(mini._name_label.visible)
	assert_eq(mini.tooltip_text, "")

func test_showcase_and_original_type_keep_the_printed_card() -> void:
	var pair := _terrain_on_forest(1)
	var preview := CardPreview.new()
	add_child_autofree(preview)
	for original in [false, true]:
		preview.show_card(pair[0], "", original)
		assert_eq(preview._name_label.text, "Forest")
		assert_string_contains(preview._type_label.text, "Forest")
		assert_eq(preview._oracle.text, pair[0].data.oracle_text)
