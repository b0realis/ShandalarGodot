extends GameTest
## Wave-44 tests: the LIVE COLOUR cluster. The five Laces repaint a spell
## or permanent indefinitely, the Legends cycle repaints creatures until
## end of turn, Aisling Leprechaun paints whatever it meets in combat,
## and Alchor's Tomb and Dream Coat let their controller choose. The point
## of every test is that the rest of the engine now READS the new colour:
## Terror, protection, Bad Moon and Crusade all consult cur_colors.


func test_registry_loaded_wave44() -> void:
	for name in ["Chaoslace", "Deathlace", "Purelace", "Thoughtlace", "Lifelace",
			"Dwarven Song", "Heaven's Gate", "Sea Kings' Blessing",
			"Sylvan Paradise", "Touch of Darkness", "Aisling Leprechaun",
			"Alchor's Tomb", "Dream Coat"]:
		assert_not_null(CardRegistry.get_card(name), name)


# ------------------------------------------------------------- the Laces --

func test_deathlace_makes_a_creature_black() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")     # printed green
	assert_true(bear.has_color(Mtg.ManaColor.G))
	var lace := give_hand(0, "Deathlace")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, lace, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.has_color(Mtg.ManaColor.B), "it is black now")
	assert_false(bear.has_color(Mtg.ManaColor.G), "'becomes' REPLACES the colour")


func test_a_laced_creature_dodges_terror() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var lace := give_hand(0, "Deathlace")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, lace, [TargetRef.card(bear)]))
	resolve_stack()
	var terror := give_hand(0, "Terror")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(0, terror, [TargetRef.card(bear)]), "Illegal target")


func test_purelace_turns_a_creature_into_a_crusade_target() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Crusade")                       # white creatures get +1/+1
	assert_eq(bear.cur_power, 2, "green bears are not white")
	var lace := give_hand(0, "Purelace")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, lace, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 3, "the Crusade sees a white bear")
	assert_eq(bear.cur_toughness, 3)


func test_a_lace_survives_the_cleanup_step() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var lace := give_hand(0, "Chaoslace")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, lace, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(bear.has_color(Mtg.ManaColor.R), "indefinite means indefinite")


func test_thoughtlace_repaints_a_spell_on_the_stack() -> void:
	var giant := give_hand(1, "Hill Giant")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.R)
	add_mana(1, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(1, giant, []))
	assert_ok(g.pass_priority(1))    # the Giant is on the stack; we respond
	var lace := give_hand(0, "Thoughtlace")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, lace, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(giant.has_color(Mtg.ManaColor.U),
		"the colour rides along into the permanent it became")


func test_a_lace_cant_hit_a_card_in_hand() -> void:
	var bear := give_hand(1, "Grizzly Bears")
	var lace := give_hand(0, "Lifelace")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.cast_spell(0, lace, [TargetRef.card(bear)]), "Illegal target")


# -------------------------------------------------- the Legends colour cycle --

func test_dwarven_song_paints_two_creatures_until_end_of_turn() -> void:
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(0, "Hill Giant")
	var song := give_hand(0, "Dwarven Song")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, song, [TargetRef.card(a), TargetRef.card(b)]))
	resolve_stack()
	assert_true(a.has_color(Mtg.ManaColor.R))
	assert_true(b.has_color(Mtg.ManaColor.R))
	advance_to_next_turn()
	assert_false(a.has_color(Mtg.ManaColor.R), "until END OF TURN")
	assert_true(a.has_color(Mtg.ManaColor.G), "back to printed green")


func test_heavens_gate_beats_a_black_ward() -> void:
	# A creature painted white can be blocked by a pro-black creature that
	# could not block it before; the simpler proof is the colour itself.
	var bear := put_battlefield(0, "Grizzly Bears")
	var gate := give_hand(0, "Heaven's Gate")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, gate, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.has_color(Mtg.ManaColor.W))
	assert_false(bear.has_color(Mtg.ManaColor.G))


func test_touch_of_darkness_feeds_bad_moon() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Bad Moon")               # black creatures get +1/+1
	assert_eq(bear.cur_power, 2)
	var touch := give_hand(0, "Touch of Darkness")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, touch, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 3, "Bad Moon sees a black bear")


func test_sylvan_paradise_and_sea_kings_blessing_exist_and_repaint() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var blessing := give_hand(0, "Sea Kings' Blessing")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, blessing, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.has_color(Mtg.ManaColor.U))
	var paradise := give_hand(0, "Sylvan Paradise")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, paradise, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.has_color(Mtg.ManaColor.G), "the later change wins")
	assert_false(bear.has_color(Mtg.ManaColor.U))


# -------------------------------------------------------- Aisling Leprechaun --

func test_aisling_leprechaun_paints_its_blocker() -> void:
	var leprechaun := put_battlefield(0, "Aisling Leprechaun")
	var wall := put_battlefield(1, "Wall of Stone")
	run_combat([leprechaun.id], {wall.id: leprechaun.id})
	resolve_stack()
	assert_true(wall.has_color(Mtg.ManaColor.G), "the blocker turned green")
	advance_to_next_turn()
	assert_true(wall.has_color(Mtg.ManaColor.G), "indefinitely")


# ---------------------------------------------------------- Alchor's Tomb --

func test_alchors_tomb_repaints_your_own_permanent() -> void:
	var tomb := put_battlefield(0, "Alchor's Tomb")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, tomb, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_false(bear.has_color(Mtg.ManaColor.G), "no longer green")
	assert_ne(bear.cur_colors, 0, "it became SOME colour")


func test_alchors_tomb_cant_repaint_theirs() -> void:
	var tomb := put_battlefield(0, "Alchor's Tomb")
	var theirs := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, tomb, 0, [TargetRef.card(theirs)]),
		"Illegal target")


# ------------------------------------------------------------- Dream Coat --

func test_dream_coat_recolors_its_host_once_a_turn() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var coat := give_hand(0, "Dream Coat")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, coat, [TargetRef.card(bear)]))
	resolve_stack()
	assert_ok(g.activate_ability(0, coat, 0, []))
	resolve_stack()
	assert_false(bear.has_color(Mtg.ManaColor.G))
	assert_refused(g.activate_ability(0, coat, 0, []), "once each turn")


# ------------------------------------------------------------ Kormus Bell --

func test_kormus_bell_swamps_really_are_black() -> void:
	var swamp := put_battlefield(0, "Swamp")
	put_battlefield(0, "Kormus Bell")
	put_battlefield(0, "Bad Moon")
	assert_true(swamp.is_creature())
	assert_true(swamp.has_color(Mtg.ManaColor.B))
	assert_eq(swamp.cur_power, 2, "Bad Moon pumps the black Swamp creature")
