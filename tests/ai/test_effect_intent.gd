extends GameTest
## EffectIntent reads a card's effects into the numbers the AI reasons
## with. These pin the reading for the effect vocabulary AND for the
## card-local table, on real cards from the shipped decks.


func _intent(card_name: String) -> EffectIntent:
	var data := CardRegistry.get_card(card_name)
	assert_not_null(data, "unknown card: %s" % card_name)
	return EffectIntent.read(data.spell_effects, card_name)


func _ability_intent(card_name: String, index := 0) -> EffectIntent:
	var data := CardRegistry.get_card(card_name)
	assert_not_null(data, "unknown card: %s" % card_name)
	return EffectIntent.read(data.activated_abilities[index].effects, card_name)


func test_reads_fixed_damage() -> void:
	var bolt := _intent("Lightning Bolt")
	assert_eq(bolt.damage, 3)
	assert_false(bolt.damage_uses_x)
	assert_eq(bolt.self_damage, 0)
	assert_true(bolt.is_harmful())
	assert_true(bolt.answers_creatures())


func test_reads_x_damage_from_the_card_local_table() -> void:
	var fireball := _intent("Fireball")
	assert_true(fireball.damage_uses_x)
	assert_true(fireball.damage_divided)
	assert_eq(fireball.damage_at(5), 5)
	assert_false(fireball.unknown, "a table row is a known shape")


func test_reads_self_damage_riders() -> void:
	var blast := _intent("Psionic Blast")
	assert_eq(blast.damage, 4)
	assert_eq(blast.self_damage, 2)
	var artillery := _ability_intent("Orcish Artillery")
	assert_eq(artillery.damage, 2)
	assert_eq(artillery.self_damage, 3)


func test_reads_removal_and_whether_regeneration_answers_it() -> void:
	var terror := _intent("Terror")
	assert_true(terror.removes)
	assert_true(terror.removal_ignores_regeneration, "Terror: can't be regenerated")
	var swords := _intent("Swords to Plowshares")
	assert_true(swords.removes)
	assert_true(swords.removal_ignores_regeneration, "exile is not destruction")
	var disenchant := _intent("Disenchant")
	assert_true(disenchant.removes)
	assert_false(disenchant.removal_ignores_regeneration)


func test_reads_helpful_shapes_as_not_harmful() -> void:
	var growth := _intent("Giant Growth")
	assert_true(growth.pumps)
	assert_eq(growth.pump_power, 3)
	assert_eq(growth.pump_toughness, 3)
	assert_false(growth.pump_self)
	assert_false(growth.is_harmful())
	var recall := _intent("Ancestral Recall")
	assert_eq(recall.draws, 3)
	assert_false(recall.is_harmful())
	var ritual := _intent("Dark Ritual")
	assert_true(ritual.adds_mana)
	var firebreathing := _ability_intent("Shivan Dragon")
	assert_true(firebreathing.pump_self)
	var skeletons := _ability_intent("Drudge Skeletons")
	assert_true(skeletons.regenerates)


func test_reads_utility_abilities() -> void:
	var icy := _ability_intent("Icy Manipulator")
	assert_true(icy.taps)
	assert_true(icy.is_harmful())
	var rod := _ability_intent("Rod of Ruin")
	assert_eq(rod.damage, 1)
	var unsummon := _intent("Unsummon")
	assert_true(unsummon.bounces)
	assert_true(unsummon.answers_creatures())


func test_keeps_sweepers_whole() -> void:
	var wrath := _intent("Wrath of God")
	assert_true(wrath.sweeper is DestroyAllEffect)
	var quake := _intent("Earthquake")
	assert_true(quake.sweeper is DamageAllEffect)
	assert_false(quake.is_harmful(), "untargeted: nothing to aim")


func test_kills_reads_live_toughness_and_marked_damage() -> void:
	var bolt := _intent("Lightning Bolt")
	var serra := put_battlefield(1, "Serra Angel")   # 4/4
	assert_false(bolt.kills(serra, 0))
	serra.damage = 1
	assert_true(bolt.kills(serra, 0), "3 more finishes a 4/4 with 1 marked")
	var fireball := _intent("Fireball")
	serra.damage = 0
	assert_false(fireball.kills(serra, 3))
	assert_true(fireball.kills(serra, 4))
	var terror := _intent("Terror")
	assert_true(terror.kills(serra, 0), "removal kills regardless of size")


func test_unknown_card_local_effect_is_removal_shaped() -> void:
	# A card-local effect outside the table with a target: treated as
	# harmful (removal-shaped) rather than ignored.
	var custom := EffectBase.new()
	custom.target_spec = TargetSpec.creature()
	var intent := EffectIntent.read([custom], "Nothing In The Table")
	assert_true(intent.unknown)
	assert_true(intent.is_harmful())
