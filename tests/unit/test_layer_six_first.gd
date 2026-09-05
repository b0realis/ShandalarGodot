extends GameTest
## CR 613.1: layer 6 (ability-adding and -removing effects) is applied
## before every P/T layer, whatever the timestamps say. The pipeline runs
## its silencers in a first pass for exactly that reason — but the pass
## read the list of TYPE-changing sources, so a silencer that changed no
## types (there is none in the pool yet; Titania's Song does both) was
## never on it and ran last, in the general pass, after the base-P/T
## setters it should have silenced (2026-09-02).


## A permanent that removes the abilities of every OTHER creature and
## changes nothing else. Not a card in the pool: this is the pipeline's
## contract, not a card's behaviour.
static func _hush() -> CardData:
	return CardData.new("Test Hush", "{1}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_silence_others,
			"Each other creature loses all abilities.").silencing_abilities())


static func _silence_others(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst != source and inst.is_creature():
			inst.cur_abilities_silenced = true


## A creature whose own static sets its base power (layer 7b) — the kind
## of source a silencer must reach BEFORE it runs.
static func _boaster() -> CardData:
	return CardData.new("Test Boaster", "{1}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.static_ability(StaticAbility.new(_boast,
			"Test Boaster has base power 5.").setting_base_pt())


static func _boast(_game: MtgGame, source: CardInstance) -> void:
	source.cur_power = 5


func test_a_silencer_that_changes_no_types_still_runs_first() -> void:
	var boaster := put_synthetic(0, _boaster())
	assert_eq(boaster.cur_power, 5, "its own static applies")
	put_synthetic(1, _hush())
	g.recalculate()
	assert_true(boaster.cur_abilities_silenced, "the silencer ran at all")
	assert_eq(boaster.cur_power, 1,
		"and ran BEFORE the base-P/T setter, which then contributed nothing")


func test_the_silencer_is_on_the_early_pass_list() -> void:
	var hush := put_synthetic(1, _hush())
	assert_true(g.battlefield_with_type_statics().has(hush),
		"indexed beside the retypers, where the layer-6 pass looks")
