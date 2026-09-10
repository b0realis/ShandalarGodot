extends GameTest
## CR 613: TIMESTAMPS WITHIN A LAYER, AND THE BOUNDED DEPENDENCY STEP —
## 2026-09-10. Two ledger rows, one pipeline, one file.
##
## PART ONE — LAYER 6 IN TIMESTAMP ORDER (CR 613.7).
##
## Within a layer, continuous effects apply in timestamp order. Ours applied
## every GRANT and then every LOSS, so "loses flying" beat a Jump cast after
## it — the ledger row read "An until-end-of-turn LOSS beats a later grant
## (`ContinuousEffects._losses`)".
##
## Radjan Spirit ("{T}: Target creature loses flying until end of turn") and
## Jump ("Target creature gains flying until end of turn") are the pool's own
## pair, and they are both commons in the starting sets. The order they
## resolve in is now the whole answer, and it decides whether a Serra Angel
## can be blocked by the ground.
##
## ContinuousEffects._timestamp stamps every layer-6 entry — a pump's
## keywords, a bare keyword grant, a landwalk grant, a loss — and
## _layer_six applies them in that order.


func _angel_and_spirit() -> Array[CardInstance]:
	var angel := put_battlefield(1, "Serra Angel")
	var spirit := put_battlefield(0, "Radjan Spirit")
	advance_to_step(Mtg.Step.MAIN1)
	return [angel, spirit]


## THE REPRODUCTION: ground it, then Jump it. The later effect wins.
func test_a_grant_after_a_loss_wins() -> void:
	var board := _angel_and_spirit()
	var angel := board[0]
	var spirit := board[1]
	assert_ok(g.activate_ability(0, spirit, 0, [TargetRef.card(angel)]))
	resolve_stack()
	assert_false(angel.has_keyword(Mtg.Keyword.FLYING), "grounded first")
	var jump := give_hand(1, "Jump")
	assert_ok(g.pass_priority(0))      # the Jump is P1's, so P1 needs priority
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(1, jump, [TargetRef.card(angel)]))
	resolve_stack()
	assert_true(angel.has_keyword(Mtg.Keyword.FLYING),
		"the later timestamp wins (CR 613.7)")


## And the other way round, which never moved: Jump first, then the Spirit.
func test_a_loss_after_a_grant_still_wins() -> void:
	var board := _angel_and_spirit()
	var angel := board[0]
	var spirit := board[1]
	var jump := give_hand(1, "Jump")
	assert_ok(g.pass_priority(0))      # the Jump is P1's, so P1 needs priority
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(1, jump, [TargetRef.card(angel)]))
	resolve_stack()
	assert_ok(g.activate_ability(0, spirit, 0, [TargetRef.card(angel)]))
	resolve_stack()
	assert_false(angel.has_keyword(Mtg.Keyword.FLYING),
		"the loss is the later effect this time")


## The rule is about the CLOCK, not about the kind of effect: two Jumps
## either side of one grounding leave the Angel flying, and the second
## grounding takes it away again.
func test_the_clock_runs_both_ways_all_turn() -> void:
	var board := _angel_and_spirit()
	var angel := board[0]
	var spirit := board[1]
	var jump_one := give_hand(1, "Jump")
	assert_ok(g.pass_priority(0))      # the Jump is P1's, so P1 needs priority
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(1, jump_one, [TargetRef.card(angel)]))
	resolve_stack()
	assert_ok(g.activate_ability(0, spirit, 0, [TargetRef.card(angel)]))
	resolve_stack()
	assert_false(angel.has_keyword(Mtg.Keyword.FLYING))
	var jump_two := give_hand(1, "Jump")
	assert_ok(g.pass_priority(0))      # the Jump is P1's, so P1 needs priority
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(1, jump_two, [TargetRef.card(angel)]))
	resolve_stack()
	assert_true(angel.has_keyword(Mtg.Keyword.FLYING),
		"the third effect is the latest one")


## The LANDWALK half of the same rule. Hammerheim strips all landwalk;
## Scarwood Hag hands forestwalk out. Grant, strip, grant again.
func test_landwalk_follows_the_same_clock() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var hag := put_battlefield(0, "Scarwood Hag")
	var hammerheim := put_battlefield(0, "Hammerheim")
	var hag_two := put_battlefield(0, "Scarwood Hag")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 8)
	assert_ok(g.activate_ability(0, hag, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.cur_landwalk.has("forest"), "the Hag gave it forestwalk")
	assert_ok(g.activate_ability(0, hammerheim, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_false(bear.cur_landwalk.has("forest"), "Hammerheim stripped it")
	assert_ok(g.activate_ability(0, hag_two, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.cur_landwalk.has("forest"),
		"a grant after the strip wins (CR 613.7)")


## THE NULL. With no loss on the table a grant behaves exactly as it did,
## and a loss with no grant behaves exactly as it did.
func test_a_lone_grant_and_a_lone_loss_are_unchanged() -> void:
	var board := _angel_and_spirit()
	var angel := board[0]
	var spirit := board[1]
	var bear := put_battlefield(1, "Grizzly Bears")
	var jump := give_hand(1, "Jump")
	assert_ok(g.pass_priority(0))      # the Jump is P1's, so P1 needs priority
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(1, jump, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))
	assert_ok(g.activate_ability(0, spirit, 0, [TargetRef.card(angel)]))
	resolve_stack()
	assert_false(angel.has_keyword(Mtg.Keyword.FLYING))
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING),
		"the two never met, so neither moved")


## Every layer-6 entry carries a UNIQUE stamp, which is what lets the sort
## need no tie-break.
func test_every_layer_six_entry_is_stamped_once() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.continuous.add_until_eot_pump(bear.id, 1, 1, [Mtg.Keyword.FLYING])
	g.continuous.add_until_eot_keywords(bear.id, [Mtg.Keyword.TRAMPLE])
	g.continuous.add_until_eot_landwalk(bear.id, ["forest"])
	g.continuous.add_until_eot_loss(bear.id, [Mtg.Keyword.FLYING])
	var stamps := []
	for entry in g.continuous._floating:
		stamps.append(int(entry["ts"]))
	for entry in g.continuous._keyword_grants:
		stamps.append(int(entry["ts"]))
	for entry in g.continuous._landwalk_grants:
		stamps.append(int(entry["ts"]))
	for entry in g.continuous._losses:
		stamps.append(int(entry["ts"]))
	assert_eq(stamps.size(), 4)
	var seen := {}
	for ts in stamps:
		seen[ts] = true
	assert_eq(seen.size(), 4, "no two entries share a timestamp")
	g.recalculate()
	assert_false(bear.has_keyword(Mtg.Keyword.FLYING), "the loss came last")
	assert_true(bear.has_keyword(Mtg.Keyword.TRAMPLE))
	assert_eq(bear.cur_power, 3, "and the pump's P/T half is untouched")


# ============ CR 613.8: THE BOUNDED LAYER-4 DEPENDENCY STEP ============
#
# Layer 4 has always run its retypers ("nonbasic lands are Mountains")
# before its animators ("all Swamps are 1/1 creatures"), which is CR 613.8
# resolved by construction. What it did NOT resolve is a retyper that reads
# a land type another retyper writes: Conversion ("All Mountains are
# Plains") is dependent on Blood Moon ("Nonbasic lands are Mountains"), so
# it must be applied after it whatever the two timestamps say.
#
# Until 2026-09-10 the two ran in battlefield order, so a Mishra's Factory
# under both was a Mountain when the Conversion had entered first and a
# Plains when the Blood Moon had. Now it is a Plains either way.


func _factory_under(first: String, second: String) -> CardInstance:
	put_battlefield(0, first)
	put_battlefield(0, second)
	var factory := put_battlefield(0, "Mishra's Factory")
	g.recalculate()
	return factory


func test_conversion_is_applied_after_blood_moon_whichever_entered_first() -> void:
	var late := _factory_under("Conversion", "Blood Moon")
	assert_eq(late.cur_subtypes, ["plains"] as Array[String],
		"Conversion depends on Blood Moon (CR 613.8), so it goes second")
	before_each()
	var early := _factory_under("Blood Moon", "Conversion")
	assert_eq(early.cur_subtypes, ["plains"] as Array[String],
		"and the other order was already right")


## A basic Mountain is a Mountain to begin with, so Conversion alone still
## paints it — the dependency step must not have moved the ordinary case.
func test_conversion_alone_is_unchanged() -> void:
	put_battlefield(0, "Conversion")
	var mountain := put_battlefield(0, "Mountain")
	g.recalculate()
	assert_eq(mountain.cur_subtypes, ["plains"] as Array[String])


## And Blood Moon alone still flattens a utility land, dependency step or
## not.
func test_blood_moon_alone_is_unchanged() -> void:
	put_battlefield(0, "Blood Moon")
	var factory := put_battlefield(0, "Mishra's Factory")
	g.recalculate()
	assert_eq(factory.cur_subtypes, ["mountain"] as Array[String])


## Conversion is the only card in the pool that reads a land type in layer
## 4 — which is what makes two waves the whole analysis, with no graph and
## no cycle to break (CR 613.8b). A second reader would need this test
## updated and the claim above re-checked.
func test_only_one_card_in_the_pool_reads_a_land_type() -> void:
	var readers: Array[String] = []
	for card_name in CardRegistry.all_names():
		for ability in CardRegistry.get_card(card_name).static_abilities:
			if ability.reads_land_types:
				readers.append(card_name)
	assert_eq(readers, ["Conversion"],
		"a new layer-4 land-type reader needs the dependency step re-checked")
