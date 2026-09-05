extends GameTest
## Wave-39 tests: CONTROL LEASHES — "gain control for as long as…"
## (Aladdin, Old Man of the Sea, Rubinia Soulsinger, Willow Satyr, The
## Wretched, Preacher, Scarwood Bandits), the aura version (Steal
## Artifact) and two "for as long as this remains tapped" riders
## (Phyrexian Gremlins, Ashnod's Battle Gear, Tawnos's Weaponry).


func test_aladdin_borrows_an_artifact_until_he_dies() -> void:
	var aladdin := put_battlefield(0, "Aladdin")
	var ring := put_battlefield(1, "Sol Ring")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, aladdin, 0, [TargetRef.card(ring)]))
	resolve_stack()
	assert_eq(ring.controller_id, 0)
	g.destroy(aladdin, false)
	g.check_state_based_actions()
	assert_eq(ring.controller_id, 1, "the leash broke")


func test_old_man_of_the_sea_holds_only_while_tapped() -> void:
	var old_man := put_battlefield(0, "Old Man of the Sea")   # 2/3
	var bear := put_battlefield(1, "Grizzly Bears")           # power 2
	var giant := put_battlefield(1, "Craw Giant")             # power 6
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, old_man, 0, [TargetRef.card(giant)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, old_man, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.controller_id, 0)
	assert_true(old_man.tapped)
	g.untap_permanent(old_man)
	g.check_state_based_actions()
	assert_eq(bear.controller_id, 1, "untapping lets it go")


func test_old_man_stays_tapped_through_his_untap_step() -> void:
	var old_man := put_battlefield(0, "Old Man of the Sea")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, old_man, 0, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_next_turn()
	advance_to_next_turn()   # back through player 0's untap step
	assert_true(old_man.tapped, "he chooses not to untap while holding")
	assert_eq(bear.controller_id, 0)


func test_rubinia_soulsinger_steals_anything() -> void:
	var rubinia := put_battlefield(0, "Rubinia Soulsinger")
	var angel := put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, rubinia, 0, [TargetRef.card(angel)]))
	resolve_stack()
	assert_eq(angel.controller_id, 0)
	g.destroy(rubinia, false)
	g.check_state_based_actions()
	assert_eq(angel.controller_id, 1)


func test_willow_satyr_only_takes_legends() -> void:
	var satyr := put_battlefield(0, "Willow Satyr")
	var bear := put_battlefield(1, "Grizzly Bears")
	var legend := put_battlefield(1, "Jedit Ojanen")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, satyr, 0, [TargetRef.card(bear)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, satyr, 0, [TargetRef.card(legend)]))
	resolve_stack()
	assert_eq(legend.controller_id, 0)


func test_the_wretched_keeps_what_blocked_it() -> void:
	var wretched := put_battlefield(0, "The Wretched")   # 2/5
	var wall := put_battlefield(1, "Wall of Wood")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wretched.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: wretched.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(wall.controller_id, 0, "the blocker changes sides")
	g.destroy(wretched, false)
	g.check_state_based_actions()
	assert_eq(wall.controller_id, 1)


func test_preacher_borrows_a_creature_while_tapped() -> void:
	var preacher := put_battlefield(0, "Preacher")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	# The creature is the target, and the opponent names it (2026-09-02):
	# the activator supplies no ref.
	assert_ok(g.activate_ability(0, preacher, 0, []))
	resolve_stack()
	assert_eq(bear.controller_id, 0)
	g.untap_permanent(preacher)
	g.check_state_based_actions()
	assert_eq(bear.controller_id, 1)


func test_scarwood_bandits_can_be_bought_off() -> void:
	var bandits := put_battlefield(0, "Scarwood Bandits")
	assert_true(bandits.cur_landwalk.has("forest"))
	var ring := put_battlefield(1, "Sol Ring")
	put_battlefield(1, "Forest")
	put_battlefield(1, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, bandits, 0, [TargetRef.card(ring)]))
	resolve_stack()
	assert_eq(ring.controller_id, 1, "they paid the {2}")


func test_scarwood_bandits_take_it_when_nobody_pays() -> void:
	var bandits := put_battlefield(0, "Scarwood Bandits")
	var ring := put_battlefield(1, "Sol Ring")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, bandits, 0, [TargetRef.card(ring)]))
	resolve_stack()
	assert_eq(ring.controller_id, 0)
	g.destroy(bandits, false)
	g.check_state_based_actions()
	assert_eq(ring.controller_id, 1)


func test_steal_artifact_takes_it_while_attached() -> void:
	var ring := put_battlefield(1, "Sol Ring")
	var steal := give_hand(0, "Steal Artifact")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, steal, [TargetRef.card(ring)]))
	resolve_stack()
	assert_eq(ring.controller_id, 0)
	g.destroy(steal, false)
	assert_eq(ring.controller_id, 1, "the aura's departure hands it back")


func test_phyrexian_gremlins_lock_an_artifact_down() -> void:
	var gremlins := put_battlefield(0, "Phyrexian Gremlins")
	var ring := put_battlefield(1, "Sol Ring")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, gremlins, 0, [TargetRef.card(ring)]))
	resolve_stack()
	assert_true(ring.tapped)
	advance_to_next_turn()
	assert_true(ring.tapped, "it can't untap while the Gremlins are tapped")
	assert_true(gremlins.tapped, "and they choose not to untap")


func test_ashnods_battle_gear_and_tawnoss_weaponry() -> void:
	var gear := put_battlefield(0, "Ashnod's Battle Gear")
	var weaponry := put_battlefield(0, "Tawnos's Weaponry")
	var angel := put_battlefield(0, "Serra Angel")   # 4/4
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, gear, 0, [TargetRef.card(angel)]))
	resolve_stack()
	assert_eq(angel.cur_power, 6, "+2/-2 while the Gear stays tapped")
	assert_eq(angel.cur_toughness, 2)
	assert_ok(g.activate_ability(0, weaponry, 0, [TargetRef.card(angel)]))
	resolve_stack()
	assert_eq(angel.cur_power, 7, "and +1/+1 from the Weaponry")
	assert_eq(angel.cur_toughness, 3)
	g.untap_permanent(weaponry)
	g.recalculate()
	assert_eq(angel.cur_power, 6, "the bonus ends when the artifact untaps")


func test_ashnods_battle_gear_can_kill_what_it_equips() -> void:
	var gear := put_battlefield(0, "Ashnod's Battle Gear")
	var bear := put_battlefield(0, "Grizzly Bears")   # 2/2
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, gear, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "+2/-2 is lethal to a 2/2")
