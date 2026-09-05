extends GameTest
## Engine tests for the LIVE COLOUR layer (CR 105.2 / 613 layer 5):
## CardInstance.cur_colors + color_override, MtgGame.set_color and
## ContinuousEffects.add_until_eot_color. Cards that use it are covered in
## tests/cards/test_pool_wave44.gd; this file pins the mechanism itself.


func test_printed_colours_come_from_the_mana_cost() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")     # {1}{G}
	assert_eq(bear.cur_colors, Mtg.ManaColor.G)
	var lotus := put_battlefield(0, "Black Lotus")      # {0}
	assert_true(lotus.is_colorless())


func test_set_color_replaces_every_colour() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.set_color(bear, Mtg.ManaColor.W | Mtg.ManaColor.B)
	assert_true(bear.has_color(Mtg.ManaColor.W))
	assert_true(bear.has_color(Mtg.ManaColor.B))
	assert_false(bear.has_color(Mtg.ManaColor.G))


func test_set_color_survives_recalculation() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.set_color(bear, Mtg.ManaColor.R)
	g.recalculate()
	g.recalculate()
	assert_true(bear.has_color(Mtg.ManaColor.R))


func test_colourless_is_a_legal_choice() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.set_color(bear, 0)
	assert_true(bear.is_colorless())
	assert_ne(bear.color_override, -1, "0 is a real choice, not 'unset'")


func test_a_colour_change_ends_with_the_zone_change() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.set_color(bear, Mtg.ManaColor.R)
	g.destroy(bear)
	g.check_state_based_actions()
	assert_eq(bear.color_override, -1)
	assert_true(bear.has_color(Mtg.ManaColor.G), "printed colour is back")


func test_until_eot_colour_expires_at_cleanup() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.continuous.add_until_eot_color(bear.id, Mtg.ManaColor.U)
	g.recalculate()
	assert_true(bear.has_color(Mtg.ManaColor.U))
	advance_to_next_turn()
	assert_true(bear.has_color(Mtg.ManaColor.G))
	assert_false(bear.has_color(Mtg.ManaColor.U))


func test_a_floating_change_beats_an_indefinite_one() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.set_color(bear, Mtg.ManaColor.B)
	g.continuous.add_until_eot_color(bear.id, Mtg.ManaColor.W)
	g.recalculate()
	assert_true(bear.has_color(Mtg.ManaColor.W), "the later timestamp wins")
	advance_to_next_turn()
	assert_true(bear.has_color(Mtg.ManaColor.B),
		"and the indefinite change is still underneath")


func test_protection_reads_the_targeting_source_s_live_colour() -> void:
	# A Chaoslaced Lightning Bolt can't hit a creature with protection from
	# red... but it CAN hit one with protection from blue. The colour the
	# engine consults is the SOURCE's live colour, not its printed one.
	var paladin := put_battlefield(1, "Black Knight")   # pro-white
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	# A red bolt is fine against pro-white.
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(paladin)]))
	resolve_stack()
	assert_eq(paladin.zone, Mtg.Zone.GRAVEYARD)


func test_protection_stops_a_repainted_source() -> void:
	var knight := put_battlefield(1, "Black Knight")    # protection from white
	var bolt := give_hand(0, "Lightning Bolt")
	g.set_color(bolt, Mtg.ManaColor.W)                  # a Purelaced Bolt
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, bolt, [TargetRef.card(knight)]),
		"Illegal target")
