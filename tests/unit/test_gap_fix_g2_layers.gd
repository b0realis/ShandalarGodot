extends GameTest
## THE LAYERS OF "LOSES ALL ABILITIES" (gap review 2026-11-10, R2; the owner's
## ruling of 2026-11-10: follow CR 613).
##
## - r2-1: an ability-removing effect is a LAYER-6 effect. The layer-4 and
##   layer-5 effects of the permanents it silences have applied by then
##   (CR 613.1, 613.6): Titania's Song no longer stops Kormus Bell's Swamps,
##   and Humility no longer stops Darkest Hour's "all creatures are black".
##   Lifts the 2026-09 audit's row 33.
## - r2-2: the Song's lingering effect keeps the Song's own timestamp (CR
##   613.7a) — it used to take a new one as the Song left.
## - r2-3: Kormus Bell's black is a layer-5 effect, so a later Chaoslace wins.
## - r2-4: Kormus Bell, Living Lands and Living Plane set 1/1 in layer 7b, in
##   timestamp order with the other setters; Living Plane reaches a land that
##   is a creature already.
## - r2-5: the Song's halves are one effect (part_of), so its size still
##   applies after a Humility humbled the Song itself.
## - Q2 (the lead's default): Animate Artifact and the Song depend on each
##   other in layer 4 (each changes whether the other applies), so the older
##   one wins (CR 613.8b).

const D := ContinuousEffects.Duration


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids():
		CardPacks.set_enabled(id, false)


static func _creature(_g: MtgGame, _s: CardInstance, inst: CardInstance) -> bool:
	return inst.is_creature()


## Humility's two statics, as test_pack_9_engine_F_silencing builds them.
static func _humility() -> CardData:
	return CardData.new("Test Humility", "{2}{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.removing_all_abilities(_creature,
			"All creatures lose all abilities.").part_of(&"humility")) \
		.static_ability(StaticAbility.base_pt_for(_creature, 1, 1,
			"All creatures have base power and toughness 1/1.").part_of(&"humility"))


static func _paint_creatures_black(game: MtgGame, _s: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_creature():
			inst.cur_colors = Mtg.ManaColor.B


## A creature whose own layer-5 static paints every creature black — the
## kind of source a Humility silences.
static func _black_painter() -> CardData:
	return CardData.new("Test Painter", "{1}{B}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.static_ability(StaticAbility.new(_paint_creatures_black,
			"All creatures are black.").changing_colors())


func _enchant(pid: int, card_name: String, host: CardInstance) -> CardInstance:
	var aura := _make_instance(pid, card_name)
	g._put_on_battlefield(aura, pid, host)
	return aura


# ============== r2-1: layer 4 and 5 apply before layer 6 ==============

func test_the_song_does_not_stop_kormus_bells_swamps() -> void:
	var swamp := put_battlefield(0, "Swamp")
	var bell := put_battlefield(0, "Kormus Bell")
	put_battlefield(1, "Titania's Song")
	g.recalculate()
	assert_true(bell.is_creature(), "the Bell is an artifact creature")
	assert_true(bell.cur_abilities_silenced, "and has lost its ability")
	assert_eq([bell.cur_power, bell.cur_toughness], [4, 4])
	assert_true(swamp.is_creature(),
		"CR 613.1/613.6: the Bell's layer-4 effect applied before the Song removed its ability")
	assert_eq([swamp.cur_power, swamp.cur_toughness], [1, 1])
	assert_eq(swamp.cur_colors, Mtg.ManaColor.B, "and its layer-5 black too")
	assert_false(swamp.cur_abilities_silenced, "the Swamp keeps its own mana ability")


func test_the_bell_newer_than_the_song_also_animates() -> void:
	var swamp := put_battlefield(0, "Swamp")
	put_battlefield(1, "Titania's Song")
	var bell := put_battlefield(0, "Kormus Bell")
	g.recalculate()
	assert_true(bell.cur_abilities_silenced)
	assert_true(swamp.is_creature())
	assert_eq([swamp.cur_power, swamp.cur_toughness], [1, 1])


func test_humility_does_not_stop_a_creatures_layer_five_effect() -> void:
	var painter := put_synthetic(0, _black_painter())
	var bears := put_battlefield(1, "Grizzly Bears")
	put_synthetic(1, _humility())
	g.recalculate()
	assert_true(painter.cur_abilities_silenced)
	assert_eq(bears.cur_colors, Mtg.ManaColor.B,
		"layer 5 applies before Humility removes the ability in layer 6")
	assert_eq([bears.cur_power, bears.cur_toughness], [1, 1])


func test_darkest_hour_under_opalescence_and_humility_still_paints() -> void:
	CardPacks.set_enabled("pack-10", true)
	super.before_each()
	put_battlefield(0, "Opalescence")
	put_synthetic(0, _humility())
	var hour := put_battlefield(0, "Darkest Hour")
	var bears := put_battlefield(1, "Grizzly Bears")
	g.recalculate()
	assert_true(hour.is_creature())
	assert_true(hour.cur_abilities_silenced)
	assert_eq(bears.cur_colors, Mtg.ManaColor.B,
		"All creatures are black (layer 5) applies before Humility's layer-6 removal")


func test_a_humbled_creature_still_loses_its_layer_six_and_seven_effects() -> void:
	# The control: what layer 6 removes still contributes nothing in 6 and 7.
	var lord := put_battlefield(0, "Lord of Atlantis")
	var merfolk := put_battlefield(0, "Merfolk of the Pearl Trident")
	put_synthetic(1, _humility())
	g.recalculate()
	assert_true(lord.cur_abilities_silenced)
	assert_eq([merfolk.cur_power, merfolk.cur_toughness], [1, 1], "no +1/+1")
	assert_false(merfolk.cur_landwalk.has("island"), "no islandwalk")


# ============== r2-2: the lingering Song keeps its timestamp ==============

func test_the_lingering_song_keeps_its_age_against_a_newer_humility() -> void:
	var tome := put_battlefield(0, "Jayemdae Tome")
	var song := put_battlefield(0, "Titania's Song")
	put_synthetic(1, _humility())   # newer than the Song
	g.recalculate()
	assert_eq([tome.cur_power, tome.cur_toughness], [1, 1], "before: Humility newer wins")
	g.destroy(song)
	g.recalculate()
	assert_true(tome.is_creature(), "the Song's effect continues")
	assert_eq([tome.cur_power, tome.cur_toughness], [1, 1],
		"CR 613.7a: the continuing effect keeps the Song's timestamp; Humility is still newer")


func test_the_lingering_song_does_not_strip_a_later_jump() -> void:
	var tome := put_battlefield(0, "Jayemdae Tome")
	var song := put_battlefield(0, "Titania's Song")
	g.recalculate()
	g.continuous.add_until_eot_keywords(tome.id, [Mtg.Keyword.FLYING])   # a Jump, after the Song
	g.recalculate()
	assert_true(tome.cur_keywords.has(Mtg.Keyword.FLYING), "before: the later Jump flies")
	g.destroy(song)
	g.recalculate()
	assert_true(tome.is_creature())
	assert_true(tome.cur_abilities_silenced, "the Tome still has no abilities of its own")
	assert_true(tome.cur_keywords.has(Mtg.Keyword.FLYING),
		"the Jump is newer than the Song's effect; the Song leaving must not ground the Tome")


func test_the_lingering_song_newer_than_humility_still_sizes() -> void:
	put_synthetic(1, _humility())
	var tome := put_battlefield(0, "Jayemdae Tome")
	var song := put_battlefield(0, "Titania's Song")
	g.destroy(song)
	g.recalculate()
	assert_eq([tome.cur_power, tome.cur_toughness], [4, 4], "the Song is the newer of the two")


# ============== r2-3: Kormus Bell's black is layer 5 ==============

func test_a_chaoslace_after_kormus_bell_makes_the_swamp_red() -> void:
	var swamp := put_battlefield(0, "Swamp")
	put_battlefield(0, "Kormus Bell")
	g.recalculate()
	assert_eq(swamp.cur_colors, Mtg.ManaColor.B)
	g.set_color(swamp, Mtg.ManaColor.R)   # Chaoslace, newer than the Bell
	g.recalculate()
	assert_eq(swamp.cur_colors, Mtg.ManaColor.R, "CR 613.7: the later layer-5 effect wins")


func test_a_chaoslace_before_kormus_bell_is_painted_black() -> void:
	var swamp := put_battlefield(0, "Swamp")
	g.set_color(swamp, Mtg.ManaColor.R)
	put_battlefield(0, "Kormus Bell")   # newer than the Lace
	g.recalculate()
	assert_eq(swamp.cur_colors, Mtg.ManaColor.B)


# ============== r2-4: the mass animations size in layer 7b ==============

func test_living_lands_newer_than_a_verdant_touch_makes_a_one_one() -> void:
	var forest := put_battlefield(0, "Forest")
	g.continuous.add_until_eot_animation(forest.id, Mtg.CardType.CREATURE, 2, 2, [],
		false, D.INDEFINITE)   # Verdant Touch / Quirion Druid
	g.recalculate()
	put_battlefield(0, "Living Lands")   # newer
	g.recalculate()
	assert_eq([forest.cur_power, forest.cur_toughness], [1, 1],
		"CR 613.4b/613.7: Living Lands' 1/1 is the later 7b set")


func test_living_lands_older_than_a_verdant_touch_leaves_the_two_two() -> void:
	var forest := put_battlefield(0, "Forest")
	put_battlefield(0, "Living Lands")
	g.continuous.add_until_eot_animation(forest.id, Mtg.CardType.CREATURE, 2, 2, [],
		false, D.INDEFINITE)
	g.recalculate()
	assert_eq([forest.cur_power, forest.cur_toughness], [2, 2])


func test_kormus_bell_newer_than_a_verdant_touch_makes_a_one_one() -> void:
	var swamp := put_battlefield(0, "Swamp")
	g.continuous.add_until_eot_animation(swamp.id, Mtg.CardType.CREATURE, 2, 2, [],
		false, D.INDEFINITE)
	g.recalculate()
	put_battlefield(0, "Kormus Bell")
	g.recalculate()
	assert_eq([swamp.cur_power, swamp.cur_toughness], [1, 1])


func test_living_plane_newer_than_a_verdant_touch_makes_a_one_one() -> void:
	var forest := put_battlefield(0, "Forest")
	g.continuous.add_until_eot_animation(forest.id, Mtg.CardType.CREATURE, 2, 2, [],
		false, D.INDEFINITE)
	g.recalculate()
	put_battlefield(0, "Living Plane")
	g.recalculate()
	assert_eq([forest.cur_power, forest.cur_toughness], [1, 1],
		"'All lands are 1/1 creatures' applies to a land that is a creature already")


func test_a_factory_animated_after_living_plane_is_two_two() -> void:
	var factory := put_battlefield(0, "Mishra's Factory")
	put_battlefield(0, "Living Plane")
	g.recalculate()
	assert_eq([factory.cur_power, factory.cur_toughness], [1, 1])
	g.continuous.add_until_eot_animation(factory.id, Mtg.CardType.CREATURE, 2, 2,
		["assembly-worker"])
	g.recalculate()
	assert_eq([factory.cur_power, factory.cur_toughness], [2, 2], "the later 7b set wins")


func test_the_mass_animations_print_one_static_per_layer() -> void:
	for card_name in ["Kormus Bell", "Living Lands", "Living Plane"]:
		var statics := CardRegistry.get_card(card_name).static_abilities
		var key: StringName = statics[0].part_key
		assert_ne(key, &"", "%s: one effect, keyed" % card_name)
		var types := 0
		var sizes := 0
		for st in statics:
			assert_eq(st.part_key, key, "%s: every half shares the key" % card_name)
			if st.changes_types: types += 1
			if st.sets_base_pt:
				sizes += 1
				assert_false(st.changes_types, "%s: the size is not layer 4" % card_name)
		assert_eq([types, sizes], [1, 1], "%s: a layer-4 type and a layer-7b size" % card_name)


# ============== r2-5: the Song's halves are one effect ==============

func test_the_song_newer_than_humility_still_sizes_when_humbled() -> void:
	CardPacks.set_enabled("pack-10", true)
	super.before_each()
	put_battlefield(0, "Opalescence")
	put_synthetic(0, _humility())
	var tome := put_battlefield(0, "Jayemdae Tome")
	var song := put_battlefield(0, "Titania's Song")   # newest
	g.recalculate()
	assert_true(song.cur_abilities_silenced, "Opalescence made the Song a creature; Humility humbled it")
	assert_true(tome.is_creature())
	assert_true(tome.cur_abilities_silenced)
	assert_eq([tome.cur_power, tome.cur_toughness], [4, 4],
		"CR 613.6: the Song's effect started in layer 4; its 7b size (newer than Humility) still applies")


func test_every_song_static_carries_the_key() -> void:
	var statics := CardRegistry.get_card("Titania's Song").static_abilities
	assert_eq(statics.size(), 3, "a layer-4 type, a layer-6 removal and a layer-7b size")
	for st in statics:
		assert_eq(st.part_key, &"song")


# ============== Q2: Animate Artifact against the Song (CR 613.8b) ==============

func test_animate_artifact_older_than_the_song_keeps_the_tomes_abilities() -> void:
	var tome := put_battlefield(0, "Jayemdae Tome")
	_enchant(0, "Animate Artifact", tome)
	g.recalculate()
	assert_true(tome.is_creature())
	assert_eq(tome.cur_activated_abilities.size(), 1, "the Tome draws")
	put_battlefield(1, "Titania's Song")   # newer
	g.recalculate()
	assert_true(tome.is_creature())
	assert_false(tome.cur_abilities_silenced,
		"CR 613.8b: a dependency loop; the older Animate Artifact applies first, so the Song never reaches the Tome")
	assert_eq(tome.cur_activated_abilities.size(), 1, "the Tome still draws")
	assert_eq([tome.cur_power, tome.cur_toughness], [4, 4])


func test_a_song_older_than_animate_artifact_silences_the_tome() -> void:
	var tome := put_battlefield(0, "Jayemdae Tome")
	put_battlefield(1, "Titania's Song")   # older
	_enchant(0, "Animate Artifact", tome)
	g.recalculate()
	assert_true(tome.is_creature())
	assert_true(tome.cur_abilities_silenced, "the older Song applies first")
	assert_eq(tome.cur_activated_abilities.size(), 0)
	assert_eq([tome.cur_power, tome.cur_toughness], [4, 4])


func test_a_jade_statue_animated_under_the_song_keeps_its_own_size() -> void:
	# The control: a one-shot animation is no dependency loop (CR 611.2c):
	# the Song depends on it and never reaches the Statue.
	var statue := put_battlefield(0, "Jade Statue")
	put_battlefield(1, "Titania's Song")
	g.recalculate()
	assert_true(statue.cur_abilities_silenced, "a noncreature artifact: the Song takes it")
	g.continuous.add_until_eot_animation(statue.id, Mtg.CardType.CREATURE, 3, 6, ["golem"])
	g.recalculate()
	assert_false(statue.cur_abilities_silenced, "a creature already: the Song skips it")
	assert_eq([statue.cur_power, statue.cur_toughness], [3, 6])


# ============== the search journal ==============

func test_undo_restores_the_layered_board() -> void:
	var swamp := put_battlefield(0, "Swamp")
	put_battlefield(0, "Kormus Bell")
	var song := put_battlefield(1, "Titania's Song")
	g.recalculate()
	var mark := g.make_mark()
	g.destroy(song)
	g.recalculate()
	assert_true(swamp.is_creature())
	g.unmake_to(mark)
	g.end_search()
	g.recalculate()
	assert_true(swamp.is_creature())
	assert_eq([swamp.cur_power, swamp.cur_toughness], [1, 1])
	assert_eq(swamp.cur_colors, Mtg.ManaColor.B)
