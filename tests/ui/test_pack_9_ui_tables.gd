extends GameTest
## PACK 9 — THE KEYWORD TABLES THE SCREENS READ (the Tempest block's
## SHADOW, CR 702.28; its block requirements, CR 509.1c). Pinned on
## synthetic cards, so a card batch's churn cannot move them:
##
##  * the table's small card badges shadow with its own drawn disc (the
##    1997 ability sheet has no cell for it), live — a grant shows, a loss
##    takes it off — and its tooltip says shadow, "blocks creatures with
##    shadow as though it had shadow" and a block requirement in words;
##  * the Deck Builder's Statistics page counts a shade as evasion, by
##    name;
##  * the auto-builder prices shadow ONCE (the duel AI's table it already
##    reads) and gives back the duel AI's defensive discount;
##  * the 1997 ability filter keeps its thirteen (no shadow bit) and does
##    not read "as though it had shadow" as giving shadow.


func _mini(inst: CardInstance) -> MiniCard:
	var w := MiniCard.new(inst, g)
	add_child_autofree(w)
	return w


static func _shade() -> CardData:
	return CardData.new("Test Shade", "{1}{B}", Mtg.CardType.CREATURE).pt(2, 1) \
		.with_keywords([Mtg.Keyword.SHADOW]) \
		.oracle("Shadow")


static func _bear() -> CardData:
	return CardData.new("Test Bear", "{1}{G}", Mtg.CardType.CREATURE).pt(2, 2)


static func _dryad() -> CardData:
	return CardData.new("Test Dryad", "{1}{G}", Mtg.CardType.CREATURE).pt(1, 2) \
		.static_ability(CombatState.blocks_shadow()) \
		.oracle("This creature can block creatures with shadow as though it had shadow.")


static func _watchdog() -> CardData:
	return CardData.new("Test Watchdog", "{3}", Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(1, 2).static_ability(CombatState.blocks_each_combat()) \
		.oracle("This creature blocks each combat if able.")


func _has_shadow_badge(w: MiniCard) -> bool:
	for child in w._badges.get_children():
		if child is TextureRect and (child as TextureRect).texture == MiniCard.shadow_badge():
			return true
	return false


# ------------------------------------------------------------ the badge --

func test_the_shadow_badge_is_a_clean_disc_of_its_own() -> void:
	var tex := MiniCard.shadow_badge()
	assert_not_null(tex, "drawn without any imported skin")
	assert_eq(tex, MiniCard.shadow_badge(), "drawn once, cached")
	var img := tex.get_image()
	assert_eq(img.get_width(), 22, "a sheet cell's size")
	for corner in [Vector2i(0, 0), Vector2i(21, 0), Vector2i(0, 21), Vector2i(21, 21)]:
		assert_eq(img.get_pixel(corner.x, corner.y).a, 0.0, "corner %s is clear" % corner)
	assert_gt(img.get_pixel(11, 11).a, 0.5, "the disc is there")
	assert_false(MiniCard.BADGE_SLOT.has(Mtg.Keyword.SHADOW),
		"not a sheet slot: Help's icon pages explain the sheet's cells")


func test_a_shade_wears_the_badge_and_a_bear_does_not() -> void:
	var shade := put_synthetic(0, _shade())
	var bear := put_synthetic(0, _bear())
	assert_true(_has_shadow_badge(_mini(shade)))
	assert_false(_has_shadow_badge(_mini(bear)), "control")
	var held := give_synthetic(0, _shade())
	assert_false(_has_shadow_badge(_mini(held)), "the table's badges are for what is in play")


func test_the_badge_follows_a_grant_and_a_loss() -> void:
	var bear := put_synthetic(0, _bear())
	g.continuous.add_until_eot_keywords(bear.id, [Mtg.Keyword.SHADOW])
	g.recalculate()
	assert_true(_has_shadow_badge(_mini(bear)), "Shadow Rift's grant shows")
	var shade := put_synthetic(1, _shade())
	g.continuous.add_until_eot_loss(shade.id, [Mtg.Keyword.SHADOW])
	g.recalculate()
	assert_false(_has_shadow_badge(_mini(shade)), "Reality Anchor's loss takes it off")


func test_the_tooltip_says_the_combat_states_in_words() -> void:
	var shade := put_synthetic(0, _shade())
	var dryad := put_synthetic(0, _dryad())
	var dog := put_synthetic(0, _watchdog())
	var bear := put_synthetic(0, _bear())
	assert_string_contains(_mini(shade).tooltip_text, MiniCard.SHADOW_NOTE)
	assert_true(dryad.cur_blocks_shadow, "control: the static is live")
	assert_string_contains(_mini(dryad).tooltip_text, MiniCard.BLOCKS_SHADOW_NOTE)
	assert_false(_mini(dryad).tooltip_text.contains(MiniCard.SHADOW_NOTE),
		"as though it had shadow is not shadow")
	assert_string_contains(_mini(dog).tooltip_text, MiniCard.MUST_BLOCK_NOTE)
	g.require_block_this_turn(bear)
	assert_string_contains(_mini(bear).tooltip_text, MiniCard.MUST_BLOCK_TURN_NOTE)
	var other := put_synthetic(1, _bear())
	assert_eq(_mini(other).combat_notes(), [] as Array[String], "control: a plain bear says nothing")


# ----------------------------------------------------- the Deck Builder --

func test_the_statistics_page_names_shadow() -> void:
	var builder := DeckBuilderScreen.new()
	assert_eq(builder._evasion_name(Mtg.Keyword.SHADOW), "shadow")
	assert_eq(builder._evasion_name(Mtg.Keyword.FEAR), "fear", "control")
	builder.free()


func test_deck_stats_tallies_shadow_beside_flying() -> void:
	CardPacks.set_enabled("pack-9", true)
	CardRegistry.ensure_loaded()
	if not CardRegistry.has_card("Soltari Monk"):
		CardPacks.set_enabled("pack-9", false)
		pass_test("the Tempest block's shades are not in this pool")
		return
	var deck := DeckModel.new()
	deck.add("Soltari Monk")
	deck.add("Soltari Monk")
	deck.add("Serra Angel")
	var tally := DeckStats.evasion(deck)
	CardPacks.set_enabled("pack-9", false)
	assert_eq(int(tally.get(Mtg.Keyword.SHADOW, 0)), 2, "two shades")
	assert_eq(int(tally.get(Mtg.Keyword.FLYING, 0)), 1, "control: one flier")


# ------------------------------------------------------- the auto-builder --

func test_the_auto_builder_prices_shadow_once_with_the_defence_discount() -> void:
	var builder := AutoDeck.new()
	var shade := _shade()
	var plain := CardData.new("Test Plain 2/1", "{1}{B}", Mtg.CardType.CREATURE).pt(2, 1)
	var flier := CardData.new("Test Flier 2/1", "{1}{B}", Mtg.CardType.CREATURE).pt(2, 1) \
		.with_keywords([Mtg.Keyword.FLYING])
	assert_false(AutoDeck.MORE_KEYWORDS.has(Mtg.Keyword.SHADOW),
		"the duel AI's own table prices it; a second row would count it twice")
	var gap := builder._creature_score(shade) - builder._creature_score(plain)
	var flying_gap := builder._creature_score(flier) - builder._creature_score(plain)
	assert_gt(gap, 0.0, "a shade is worth more than the same body without")
	assert_lt(gap, flying_gap, "and less than a flier: it blocks only shades")


# ----------------------------------------------------- the 1997 filter --

func test_the_ability_filter_keeps_its_thirteen() -> void:
	assert_eq(DeckAbilities.LABELS.size(), 13, "@ABILITY's own list")
	DeckAbilities.clear_cache()
	assert_eq(DeckAbilities.native(_shade()), 0, "shadow is none of the thirteen")
	var dryad := _dryad()
	assert_eq(DeckAbilities.gives(dryad), 0,
		"as though it had shadow gives nobody anything")
	DeckAbilities.clear_cache()
