extends GameTest
## Fidelity lift of 2026-09-02: "loses SWAMPWALK" / "loses FORESTWALK"
## (Urborg, Scarwood Hag) strips that one landwalk type and no other —
## ContinuousEffects.add_until_eot_loss now carries a land-type list next
## to Hammerheim's all-landwalk flag.


func test_urborg_strips_swampwalk_and_nothing_else() -> void:
	var urborg := put_battlefield(0, "Urborg")
	var wraith := put_battlefield(1, "Bog Wraith")           # swampwalk
	var leviathan := put_battlefield(1, "Segovian Leviathan")   # islandwalk
	g.continuous.add_until_eot_landwalk(wraith.id, ["island"])
	g.recalculate()
	assert_eq(wraith.cur_landwalk, ["swamp", "island"])
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, urborg, 1, [TargetRef.card(wraith)]))
	resolve_stack()
	assert_false(wraith.cur_landwalk.has("swamp"), "swampwalk is gone")
	assert_true(wraith.cur_landwalk.has("island"), "its islandwalk is not")
	g.untap_permanent(urborg)
	assert_ok(g.activate_ability(0, urborg, 1, [TargetRef.card(leviathan)]))
	resolve_stack()
	assert_true(leviathan.cur_landwalk.has("island"),
		"a creature with no swampwalk loses nothing")


func test_scarwood_hag_takes_back_only_forestwalk() -> void:
	var hag := put_battlefield(0, "Scarwood Hag")
	var wraith := put_battlefield(1, "Bog Wraith")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 4)
	assert_ok(g.activate_ability(0, hag, 0, [TargetRef.card(wraith)]))
	resolve_stack()
	assert_true(wraith.cur_landwalk.has("forest"))
	g.untap_permanent(hag)
	assert_ok(g.activate_ability(0, hag, 1, [TargetRef.card(wraith)]))
	resolve_stack()
	assert_false(wraith.cur_landwalk.has("forest"), "the loss beats the grant")
	assert_true(wraith.cur_landwalk.has("swamp"), "swampwalk survives")


func test_hammerheim_still_strips_every_landwalk() -> void:
	var hammerheim := put_battlefield(0, "Hammerheim")
	var wraith := put_battlefield(1, "Bog Wraith")
	g.continuous.add_until_eot_landwalk(wraith.id, ["island"])
	g.recalculate()
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, hammerheim, 0, [TargetRef.card(wraith)]))
	resolve_stack()
	assert_eq(wraith.cur_landwalk, [], "all landwalk abilities")


func test_the_lost_landwalk_comes_back_at_cleanup() -> void:
	var urborg := put_battlefield(0, "Urborg")
	var wraith := put_battlefield(1, "Bog Wraith")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, urborg, 1, [TargetRef.card(wraith)]))
	resolve_stack()
	assert_false(wraith.cur_landwalk.has("swamp"))
	advance_to_next_turn()
	assert_true(wraith.cur_landwalk.has("swamp"))
