extends GameTest
## Sanity + integration tests for the AUTO-GENERATED card pool
## (tools/gen_cards.py output under cards/sets/<set>/).
##
## Two layers of protection:
## 1. Registry-wide invariants — every registered card, whatever its origin,
##    must satisfy basic sanity (parseable cost, sane creature stats). This
##    catches a bad generator run or a typo'd hand-written card at test time
##    instead of mid-duel.
## 2. Spot integration — generated cards are not just data: a few of them
##    are cast and fought through the real engine to prove generated files
##    behave identically to hand-written ones.


func test_every_registered_card_is_sane() -> void:
	for card_name in CardRegistry.all_names():
		var data := CardRegistry.get_card(card_name)
		assert_not_null(data, card_name)
		assert_eq(data.card_name, card_name, "registry key matches card name")
		if data.is_creature():
			# Characteristic-defining statics (Nightmare's */*) legitimately
			# print 0/0 and derive stats at recalculation time, and so do the
			# copy creatures (Clone, Vesuvan Doppelganger) — they adopt a real
			# body as they enter, before any state-based action sees the 0/0.
			if data.static_abilities.is_empty() and data.enters_as_copy.is_empty():
				assert_gt(data.toughness, 0,
					"%s: creatures need toughness >= 1" % card_name)
			assert_gte(data.power, 0, card_name)
		if not data.is_land():
			# mana_value can legitimately be 0 (Ornithopter, the Kobolds),
			# but the cost STRING must exist — an empty one is a parse bug.
			assert_ne(data.cost.text, "",
				"%s: non-land with no cost text is a parse/generation bug" % card_name)
		assert_ne(data.set_code, "", card_name)


func test_generated_keywords_registered() -> void:
	# One generated card per keyword the generator can emit.
	assert_true(CardRegistry.get_card("Mahamoti Djinn").has_keyword(Mtg.Keyword.FLYING))
	assert_true(CardRegistry.get_card("Giant Spider").has_keyword(Mtg.Keyword.REACH))
	assert_true(CardRegistry.get_card("Wall of Stone").has_keyword(Mtg.Keyword.DEFENDER))


func test_generated_vanilla_fights_like_hand_written() -> void:
	# Hill Giant (generated 3/3) trades with Gray Ogre (generated 2/2)?
	# No — it survives: 2 damage vs 3 toughness. Full combat through the
	# real engine using only generated cards.
	var giant := put_battlefield(0, "Hill Giant")
	var ogre := put_battlefield(1, "Gray Ogre")
	run_combat([giant.id], {ogre.id: giant.id})
	assert_eq(ogre.zone, Mtg.Zone.GRAVEYARD, "3 power kills the 2/2")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "2 damage vs 3 toughness")
	assert_eq(giant.damage, 2)


func test_generated_reach_blocks_flyer() -> void:
	# Giant Spider's reach (generated) blocking Mahamoti Djinn (generated).
	var djinn := put_battlefield(0, "Mahamoti Djinn")   # 5/6 flying
	var spider := put_battlefield(1, "Giant Spider")     # 2/4 reach
	run_combat([djinn.id], {spider.id: djinn.id})
	assert_eq(spider.zone, Mtg.Zone.GRAVEYARD, "5 damage kills the 2/4")
	assert_eq(djinn.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[1].life, 20, "blocked: no player damage")


func test_generated_card_castable() -> void:
	var wurm := give_hand(0, "Craw Wurm")   # {4}{G}{G} 6/4, generated
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, wurm, []))
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(wurm.cur_power, 6)
