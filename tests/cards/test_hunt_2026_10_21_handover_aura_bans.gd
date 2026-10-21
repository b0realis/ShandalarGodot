extends GameTest
## THE SECOND BUG HUNT (2026-10-21), the handover: "can't be enchanted by
## other Auras" (Consecrate Land, Anti-Magic Aura).
##
## WAS: the clause was only a TARGETING ban — an Aura spell could no longer
## be cast at the host — so an Aura already on the land or creature stayed
## (an Evil Presence went on making the Consecrated Forest a Swamp). The
## words make every OTHER Aura on it illegal, and an illegally attached
## Aura is put into its owner's graveyard (CR 303.4d, 704.5m).
## NOW the two Auras say which host they bar and `MtgGame.aura_can_enchant`
## reads it (`CardInstance.cur_other_auras_barred_by`), so the state-based
## check sheds the others. Guardian Beast's "can't be enchanted" keeps its
## own words — "This effect doesn't remove Auras already attached" — and
## stays a targeting ban.


func test_consecrate_land_sheds_an_aura_already_there() -> void:
	var forest := put_battlefield(0, "Forest")
	var presence := give_hand(1, "Evil Presence")
	var consecrate := give_hand(0, "Consecrate Land")
	advance_to_step(Mtg.Step.MAIN1)
	g.attach_aura_from_anywhere(presence, forest, 1)
	assert_true(forest.has_subtype("swamp"), "control: the Presence made it a Swamp")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, consecrate, [TargetRef.card(forest)]))
	resolve_stack()
	assert_eq(presence.zone, Mtg.Zone.GRAVEYARD, "can't be enchanted by other Auras")
	assert_eq(consecrate.zone, Mtg.Zone.BATTLEFIELD, "the Consecrate Land itself stays")
	assert_true(forest.has_subtype("forest"), "a Forest again")


func test_anti_magic_aura_sheds_an_aura_already_there() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var weakness := give_hand(1, "Weakness")
	var anti := give_hand(0, "Anti-Magic Aura")
	advance_to_step(Mtg.Step.MAIN1)
	g.attach_aura_from_anywhere(weakness, bear, 1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, anti, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(weakness.zone, Mtg.Zone.GRAVEYARD, "can't be enchanted by other Auras")
	assert_eq(anti.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq([bear.cur_power, bear.cur_toughness], [2, 2], "the Weakness is gone")


func test_anti_magic_aura_sheds_animate_dead() -> void:
	# Animate Dead is an Aura on the creature it raised (its modern
	# "enchant creature put onto the battlefield with Animate Dead"): barred
	# like any other, it goes, and the creature with it.
	var dragon := put_battlefield(1, "Shivan Dragon")
	g.destroy(dragon, false)
	var animate := give_hand(0, "Animate Dead")
	var anti := give_hand(0, "Anti-Magic Aura")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, animate, [TargetRef.card(dragon)]))
	resolve_stack()
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD, "control: raised")
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, anti, [TargetRef.card(dragon)]))
	resolve_stack()
	assert_eq(animate.zone, Mtg.Zone.GRAVEYARD, "Animate Dead can no longer enchant it")
	assert_eq(dragon.zone, Mtg.Zone.GRAVEYARD, "and the Dragon goes back")


func test_an_aura_cannot_be_moved_onto_a_consecrated_land() -> void:
	var forest := put_battlefield(0, "Forest")
	var mountain := put_battlefield(0, "Mountain")
	var consecrate := give_hand(0, "Consecrate Land")
	var presence := give_hand(1, "Evil Presence")
	advance_to_step(Mtg.Step.MAIN1)
	g.attach_aura_from_anywhere(consecrate, forest, 0)
	g.attach_aura_from_anywhere(presence, mountain, 1)
	g.move_aura(presence, forest)
	assert_eq(presence.attached_to, mountain.id, "the Forest can't be enchanted by it")


func test_guardian_beast_keeps_auras_already_attached() -> void:
	# Control: "This effect doesn't remove Auras already attached to those
	# artifacts."
	var mox := put_battlefield(0, "Mox Pearl")
	var leak := give_hand(1, "Steal Artifact")
	advance_to_step(Mtg.Step.MAIN1)
	g.attach_aura_from_anywhere(leak, mox, 1)
	put_battlefield(0, "Guardian Beast")
	g.check_state_based_actions()
	assert_eq(leak.zone, Mtg.Zone.BATTLEFIELD, "the Beast removes nothing")
