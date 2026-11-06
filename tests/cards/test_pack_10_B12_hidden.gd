extends GameTest
## Pack 10 (the Urza block), batch B12: the green Hidden and the black
## Lurking enchantments of cards/sets/usg/_opal.gd, cards/sets/ulg/_opal.gd
## and cards/sets/uds/_opal.gd — Hidden Ancients, Hidden Guerrillas, Hidden
## Herd, Hidden Predators, Hidden Spider, Hidden Stag, Hidden Gibbons,
## Lurking Evil, Lurking Skirge, Lurking Jackals.

const W := Mtg.ManaColor.W
const B := Mtg.ManaColor.B
const G := Mtg.ManaColor.G


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _pt(inst: CardInstance) -> Array:
	return [inst.cur_power, inst.cur_toughness]


func _cast(card_name: String, color: int, amount: int, targets: Array = []) -> CardInstance:
	var spell := give_hand(0, card_name)
	if amount > 0:
		add_mana(0, color, amount)
	assert_ok(g.cast_spell(0, spell, targets))
	resolve_stack()
	return spell


func _became(inst: CardInstance, subtype: String, size: Array) -> void:
	assert_true(inst.is_creature(), "%s is a creature" % inst.data.card_name)
	assert_false(inst.is_type(Mtg.CardType.ENCHANTMENT), "and no longer an enchantment")
	assert_true(inst.has_subtype(subtype))
	assert_eq(_pt(inst), size)


# --------------------------------------------------------- the spell kinds --

func test_ancients_answer_an_enchantment_spell_only() -> void:
	var ancients := put_battlefield(1, "Hidden Ancients")
	_cast("Grizzly Bears", G, 2)
	assert_false(ancients.is_creature(), "a creature spell is not an enchantment spell")
	_cast("Crusade", W, 2)
	_became(ancients, "treefolk", [5, 5])


func test_guerrillas_answer_an_artifact_spell_with_trample() -> void:
	var guerrillas := put_battlefield(1, "Hidden Guerrillas")
	_cast("Howling Mine", Mtg.ManaColor.C, 2)
	_became(guerrillas, "soldier", [5, 3])
	assert_true(guerrillas.has_keyword(Mtg.Keyword.TRAMPLE))


func test_spider_answers_a_creature_spell_with_flying() -> void:
	var spider := put_battlefield(1, "Hidden Spider")
	_cast("Grizzly Bears", G, 2)
	assert_false(spider.is_creature(), "no flying")
	_cast("Birds of Paradise", G, 1)
	_became(spider, "spider", [3, 5])
	assert_true(spider.has_keyword(Mtg.Keyword.REACH))


func test_gibbons_answer_an_instant() -> void:
	var gibbons := put_battlefield(1, "Hidden Gibbons")
	_cast("Crusade", W, 2)
	assert_false(gibbons.is_creature())
	_cast("Dark Ritual", B, 1)
	_became(gibbons, "ape", [4, 4])


# ------------------------------------------------------------- the lands --

func test_herd_answers_a_nonbasic_land_drop() -> void:
	var herd := put_battlefield(1, "Hidden Herd")
	var forest := give_hand(0, "Forest")
	assert_ok(g.play_land(0, forest))
	resolve_stack()
	assert_false(herd.is_creature(), "a basic land")
	advance_to_next_turn()
	advance_to_next_turn()
	var factory := give_hand(0, "Mishra's Factory")
	assert_ok(g.play_land(0, factory))
	resolve_stack()
	_became(herd, "beast", [3, 3])


func test_stag_turns_with_each_land_drop() -> void:
	var stag := put_battlefield(1, "Hidden Stag")
	var forest := give_hand(0, "Forest")
	assert_ok(g.play_land(0, forest))
	resolve_stack()
	_became(stag, "elk", [3, 2])
	assert_true(stag.has_subtype("beast"), "an Elk Beast")
	advance_to_next_turn()
	var island := give_hand(1, "Island")
	assert_ok(g.play_land(1, island))
	resolve_stack()
	assert_false(stag.is_creature(), "you play a land: an enchantment again")
	assert_true(stag.is_type(Mtg.CardType.ENCHANTMENT))
	assert_false(stag.has_subtype("elk"))
	advance_to_next_turn()
	var swamp := give_hand(0, "Swamp")
	assert_ok(g.play_land(0, swamp))
	resolve_stack()
	_became(stag, "elk", [3, 2])


func test_a_land_put_onto_the_battlefield_is_not_played() -> void:
	var stag := put_battlefield(1, "Hidden Stag")
	put_battlefield(0, "Forest")
	assert_false(stag.is_creature())


# ------------------------------------------------------- the state triggers --

func test_predators_answer_a_creature_with_power_four() -> void:
	var predators := put_battlefield(1, "Hidden Predators")
	put_battlefield(0, "Hill Giant")
	resolve_stack()
	assert_false(predators.is_creature(), "power 3")
	var bears := put_battlefield(0, "Grizzly Bears")
	_cast("Giant Growth", G, 1, [TargetRef.card(bears)])
	resolve_stack()
	_became(predators, "beast", [4, 4])


func test_predators_ignore_their_controllers_big_creature() -> void:
	var predators := put_battlefield(1, "Hidden Predators")
	put_battlefield(1, "Craw Wurm")
	g.check_state_based_actions()
	resolve_stack()
	assert_false(predators.is_creature())


func test_jackals_answer_an_opponent_at_ten_life() -> void:
	var jackals := put_battlefield(1, "Lurking Jackals")
	g.adjust_life(1, -12)
	resolve_stack()
	assert_false(jackals.is_creature(), "its own controller's life does not count")
	g.adjust_life(0, -10)
	resolve_stack()
	_became(jackals, "jackal", [3, 2])


# -------------------------------------------------------------- Lurking Skirge --

func test_skirge_answers_a_creature_dying_into_an_opponents_graveyard() -> void:
	var skirge := put_battlefield(1, "Lurking Skirge")
	var mine := put_battlefield(1, "Grizzly Bears")
	g.destroy(mine)
	resolve_stack()
	assert_false(skirge.is_creature(), "its controller's own creature")
	var theirs := put_battlefield(0, "Grizzly Bears")
	g.destroy(theirs)
	resolve_stack()
	_became(skirge, "imp", [3, 2])
	assert_true(skirge.has_subtype("phyrexian"))
	assert_true(skirge.has_keyword(Mtg.Keyword.FLYING))


func test_skirge_counts_an_animated_land_by_last_known_types() -> void:
	var skirge := put_battlefield(1, "Lurking Skirge")
	var factory := put_battlefield(0, "Mishra's Factory")
	g.continuous.add_until_eot_animation(factory.id,
		Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT, 2, 2, ["assembly-worker"])
	g.recalculate()
	g.destroy(factory)
	resolve_stack()
	assert_true(skirge.is_creature(), "it died a creature (CR 608.2h)")


func test_skirge_ignores_a_noncreature_permanent() -> void:
	var skirge := put_battlefield(1, "Lurking Skirge")
	var mine := put_battlefield(0, "Howling Mine")
	g.destroy(mine)
	resolve_stack()
	assert_false(skirge.is_creature())


# ----------------------------------------------------------------- Lurking Evil --

func test_lurking_evil_costs_half_the_life_rounded_up() -> void:
	var evil := put_battlefield(0, "Lurking Evil")
	g.players[0].life = 7
	assert_ok(g.activate_ability(0, evil, 0, []))
	assert_eq(g.players[0].life, 3, "paid 4 as the cost (CR 119.4)")
	resolve_stack()
	_became(evil, "horror", [4, 4])
	assert_true(evil.has_subtype("phyrexian"))
	assert_true(evil.has_keyword(Mtg.Keyword.FLYING))


func test_lurking_evil_can_be_paid_again_as_a_creature() -> void:
	var evil := put_battlefield(0, "Lurking Evil")
	assert_ok(g.activate_ability(0, evil, 0, []))
	resolve_stack()
	assert_eq(g.players[0].life, 10)
	assert_ok(g.activate_ability(0, evil, 0, []))
	resolve_stack()
	assert_eq(g.players[0].life, 5)
	assert_true(evil.is_creature())
	assert_eq(_pt(evil), [4, 4])


func test_lurking_evil_at_one_life_pays_the_last_one() -> void:
	var evil := put_battlefield(0, "Lurking Evil")
	g.players[0].life = 1
	assert_ok(g.activate_ability(0, evil, 0, []))
	assert_true(g.game_over or g.players[0].life == 0)
