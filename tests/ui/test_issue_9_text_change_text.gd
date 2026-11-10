extends GameTest
## GitHub issue #9: a TEXT CHANGE shows in the card's own words. Magical
## Hack turned a Savannah's Forest into an Island — the name band said
## "Island/Plains" and a tap offered White or Blue, but the Showcase and
## the small card's tooltip still read the printed "({T}: Add {G} or {W}.)".
## Both now read the text as the change wrote it ([method
## CardPreview.changed_text]), the Showcase with the written words leaning
## ([member ManaText.emphasis]); only what the engine changed is rewritten,
## and a card with no text change is untouched.


func _preview() -> CardPreview:
	var preview := CardPreview.new()
	add_child_autofree(preview)
	return preview


func _mini(inst: CardInstance) -> MiniCard:
	var mini := MiniCard.new(inst, g)
	add_child_autofree(mini)
	return mini


## The text the [param marks] ranges cover in [param text].
func _marked(text: String, marks: Array) -> Array[String]:
	var out: Array[String] = []
	for mark in marks:
		out.append(text.substr(int(mark[0]), int(mark[1]) - int(mark[0])))
	return out


func test_a_hacked_savannah_s_showcase_reads_the_mana_it_makes() -> void:
	var land := put_battlefield(0, "Savannah")
	g.change_text(land, "land_type", "forest", "island")
	g.recalculate()
	assert_eq(land.data.oracle_text, "({T}: Add {G} or {W}.)", "control: the printed text")
	var preview := _preview()
	preview.show_card(land)
	assert_eq(preview._oracle.text, "({T}: Add {U} or {W}.)")
	assert_eq(_marked(preview._oracle.text, preview._oracle.emphasis), ["{U}"] as Array[String],
		"the written symbol leans")
	assert_true(preview._type_changed.visible, "the changed type line shows")
	assert_false(preview._type_label.visible)
	assert_eq(preview._type_changed.text, "Land — Island Plains")
	assert_eq(_marked(preview._type_changed.text, preview._type_changed.emphasis),
		["Island"] as Array[String])
	assert_eq(preview._type_changed.get_visible_line_count(), 1,
		"its one line stands whole in the strip, so it is drawn")
	var strip := preview._type_label.get_global_rect()
	assert_almost_eq(preview._type_changed.get_global_rect().get_center().y, strip.get_center().y, 1.0,
		"centred on the type strip")
	assert_eq(preview._name_label.text, "Savannah", "the name is no text a hack reaches")
	# `Original type` is the card before any spell changed it.
	preview.show_card(land, "", true)
	assert_eq(preview._oracle.text, "({T}: Add {G} or {W}.)")
	assert_eq(preview._oracle.emphasis, [])
	assert_false(preview._type_changed.visible)
	assert_eq(preview._type_label.text, "Land — Forest Plains")


func test_the_tooltip_puts_the_changed_rules_over_the_printed_ones() -> void:
	var land := put_battlefield(0, "Savannah")
	g.change_text(land, "land_type", "forest", "island")
	g.recalculate()
	var mini := _mini(land)
	assert_eq(mini.tooltip_text.get_slice("\n", 0), "Savannah")
	assert_string_contains(mini.tooltip_text, "Current land types: Island/Plains\n"
		+ MiniCard.CHANGED_RULES + "\n({T}: Add {U} or {W}.)\nPrinted rules:\n({T}: Add {G} or {W}.)")
	# And what the words say is what a tap makes.
	var made: Array[int] = []
	for ability in land.cur_mana_abilities:
		made.append(int(ability.produces[0][0]))
	made.sort()
	assert_eq(made, [Mtg.ManaColor.W, Mtg.ManaColor.U] as Array[int])


func test_a_hacked_basic_and_a_drained_plains() -> void:
	var forest := put_battlefield(0, "Forest")
	g.change_text(forest, "land_type", "forest", "swamp")
	var plains := put_battlefield(0, "Plains")
	g.change_text(plains, "mana_color", Mtg.ManaColor.W, Mtg.ManaColor.C)   # Quarum Trench Gnomes
	g.recalculate()
	var preview := _preview()
	preview.show_card(forest)
	assert_eq(preview._oracle.text, "({T}: Add {B}.)")
	assert_eq(preview._type_changed.text, "Basic Land — Swamp")
	preview.show_card(plains)
	assert_eq(preview._oracle.text, "({T}: Add {C}.)", "the Gnomes' colorless mana")
	assert_false(preview._type_changed.visible, "still a Plains")
	assert_string_contains(_mini(plains).tooltip_text,
		MiniCard.CHANGED_RULES + "\n({T}: Add {C}.)\nPrinted rules:\n({T}: Add {W}.)")


func test_landwalk_and_its_reminder_and_protection_are_rewritten() -> void:
	var wraith := put_battlefield(0, "Bog Wraith")
	g.change_text(wraith, "land_type", "swamp", "island")
	var soul := put_battlefield(0, "Lost Soul")
	g.change_text(soul, "land_type", "swamp", "mountain")
	var knight := put_battlefield(0, "White Knight")
	g.change_text(knight, "color_word", Mtg.ManaColor.B, Mtg.ManaColor.G)   # Sleight of Mind
	g.recalculate()
	var preview := _preview()
	preview.show_card(wraith)
	assert_eq(preview._oracle.text, "Islandwalk")
	assert_eq(_marked(preview._oracle.text, preview._oracle.emphasis), ["Islandwalk"] as Array[String])
	preview.show_card(soul)
	assert_eq(preview._oracle.text,
		"Mountainwalk (This creature can't be blocked as long as defending player controls a Mountain.)")
	preview.show_card(knight)
	assert_eq(preview._oracle.text, knight.data.oracle_text.replace("black", "green"))
	assert_eq(preview._name_label.text, "White Knight", "a colour word in the NAME is no colour word")
	assert_false(preview._type_changed.visible)
	assert_string_contains(_mini(knight).tooltip_text,
		MiniCard.CHANGED_RULES + "\n" + knight.data.oracle_text.replace("black", "green"))


## Never a guess: a word the engine did not change stays as printed.
func test_only_what_the_engine_changed_is_rewritten() -> void:
	# A land type in rules text the engine keeps as behaviour (Island Fish
	# Jasconius's attack restriction): no text change reaches it.
	var fish := put_battlefield(0, "Island Fish Jasconius")
	g.change_text(fish, "land_type", "island", "swamp")
	g.recalculate()
	assert_eq(CardPreview.changed_text(fish), {})
	var preview := _preview()
	preview.show_card(fish)
	assert_eq(preview._oracle.text, fish.data.oracle_text)
	assert_eq(preview._oracle.emphasis, [])
	# A creature's {B} is no basic land's mana: swampwalk changes, the {B}s stay.
	var engine := CardData.new("Test Engine", "{5}{B}", Mtg.CardType.CREATURE).pt(4, 4) \
		.with_landwalk(["swamp"]) \
		.mana(ManaAbility.new(Mtg.ManaColor.B, 4)) \
		.oracle("Swampwalk (This creature can't be blocked as long as defending player controls a Swamp.)\n{T}: Add {B}{B}{B}{B}.")
	var witch := put_synthetic(0, engine)
	g.change_text(witch, "land_type", "swamp", "island")
	g.recalculate()
	preview.show_card(witch)
	assert_eq(preview._oracle.text,
		"Islandwalk (This creature can't be blocked as long as defending player controls an Island.)\n{T}: Add {B}{B}{B}{B}.")
	assert_eq(_marked(preview._oracle.text, preview._oracle.emphasis),
		["Islandwalk", "an Island"] as Array[String])


func test_nothing_changes_for_a_card_with_no_text_change() -> void:
	var land := put_battlefield(0, "Savannah")
	assert_eq(CardPreview.changed_text(land), {})
	var preview := _preview()
	preview.show_card(land)
	assert_eq(preview._oracle.text, land.data.oracle_text)
	assert_eq(preview._oracle.emphasis, [])
	assert_false(preview._type_changed.visible)
	assert_true(preview._type_label.visible)
	assert_eq(_mini(land).tooltip_text.get_slice("\n", 1), land.data.oracle_text)
	# A text change ends with the battlefield: back in hand it is the card.
	g.change_text(land, "land_type", "forest", "island")
	g.return_to_hand(land)
	assert_eq(CardPreview.changed_text(land), {})


## The LAN guest's detached card carries the host's text changes as public
## facts ([SgCardPresentation]); the same words come out of them.
func test_a_lan_guest_s_card_reads_the_host_s_text_changes() -> void:
	var guest := CardInstance.new(CardRegistry.get_card("Savannah"), -1, 1)
	guest.zone = Mtg.Zone.BATTLEFIELD
	guest.set_meta("sg_text_effects", [{"kind": "land_type", "from": "forest", "to": "island"}])
	var changed := CardPreview.changed_text(guest)
	assert_eq(String(changed.get("rules", "")), "({T}: Add {U} or {W}.)")
	assert_eq(String(changed.get("type", "")), "Land — Island Plains")


## The Showcase's slant changes the face, never the wrap: the box fits the
## same text with or without it.
func test_the_slant_is_a_leaning_copy_of_the_face() -> void:
	var preview := _preview()
	var face: Font = preview._body_font
	var lean := ManaText.slanted(face)
	assert_true(lean is FontVariation)
	assert_ne((lean as FontVariation).variation_transform, Transform2D.IDENTITY)
	assert_eq(lean.get_height(18), face.get_height(18), "the same line box")
	var text := "Islandwalk (This creature can't be blocked as long as defending player controls an Island.)"
	var plain := ManaText.build(text, face, 18, 230.0, 1)
	var marked := ManaText.build(text, face, 18, 230.0, 1, [[0, 10], [80, 89]])
	assert_eq((marked["para"] as TextParagraph).get_line_count(),
		(plain["para"] as TextParagraph).get_line_count())
	assert_eq(marked["slanted"], {}, "no symbol in the text, none leaning")
