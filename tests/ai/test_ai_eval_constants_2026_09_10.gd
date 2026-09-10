extends GameTest
## THE DEFENDER'S DISCOUNT AND THE ABILITY BONUS, EXPOSED FOR A SWEEP
## (2026-09-10, the Forge study's combat note P6).
##
## [method Evaluator.permanent_value] prices a Wall of Stone at 7.0 —
## above a Hypnotic Specter (5.5) and a White Knight (6.0) — where Forge's
## own evaluator puts it below both, and prices a Llanowar Elves and a
## Prodigal Sorcerer at exactly a vanilla 1/1 where Forge pays ten points
## for an activated ability and ten more for a mana one
## (`docs/forge/combat.md` §2.1, P6). Every consumer that has to PICK
## inherits that ranking, and the two the probe caught are not arguable:
##
##     Swords to Plowshares, a Wall of Stone and a Hypnotic Specter
##       _best_victim -> Wall of Stone          (7.00 against 5.50)
##     Control Magic, the same two
##       stolen: the Wall of Stone
##
## WHETHER THE FORGE TABLE IS RIGHT IS A MEASUREMENT, NOT AN ARGUMENT, and
## a constant cannot be measured — so the two numbers are carried by the
## profile ([member AiProfile.defender_scale], [member
## AiProfile.ability_bonus]) exactly as [member AiProfile.w_hand] is, and
## the Deck Lab puts them on a seat: `--sweep defender_scale=0,0.4`,
## `--sweep ability_bonus=0,0.5`. THEY ARE NOT KNOBS. Every preset ships
## the evaluator's own constants, no rung moves them, and nothing in the
## game sets them.
##
## What this file pins is the whole of that sentence: that the shipped
## default is inert (the pilot scores byte for byte as it did), that a
## profile carrying another value is really read everywhere the price is
## spent, and what the candidate numbers actually do to the cards that
## move.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


## The candidate constants of combat note P6.
func _p6() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.defender_scale = 0.4
	profile.ability_bonus = 0.5
	return profile


# ====================================================== the incumbent --

func test_every_preset_ships_the_evaluators_own_constants() -> void:
	# The fields' defaults ARE the evaluator's constants; this is the pin
	# that keeps the two from drifting apart, since they cannot name each
	# other (the evaluator reads the profile, so the profile may not read
	# the evaluator).
	assert_eq(Evaluator.DEFENDER_SCALE, 0.0)
	assert_eq(Evaluator.ABILITY_BONUS, 0.0)
	for profile in [AiProfile.apprentice(), AiProfile.magician(),
			AiProfile.sorcerer(), AiProfile.wizard()]:
		assert_eq(profile.defender_scale, Evaluator.DEFENDER_SCALE,
			profile.profile_name)
		assert_eq(profile.ability_bonus, Evaluator.ABILITY_BONUS,
			profile.profile_name)


func test_the_default_profile_prices_exactly_as_no_profile() -> void:
	var wall := put_battlefield(0, "Wall of Stone")
	var tim := put_battlefield(0, "Prodigal Sorcerer")
	var elves := put_battlefield(0, "Llanowar Elves")
	var shipped := AiProfile.wizard()
	for inst in [wall, tim, elves]:
		assert_eq(Evaluator.permanent_value(inst),
			Evaluator.permanent_value(inst, shipped),
			"%s: the shipped pilot prices as the constant does" % inst.data.card_name)


func test_the_incumbent_prices_a_wall_of_stone_above_a_specter() -> void:
	# The malfunction as the note met it, kept here as the null so the
	# next reader can see what was changed and what was not.
	var wall := put_battlefield(1, "Wall of Stone")
	var specter := put_battlefield(1, "Hypnotic Specter")
	assert_almost_eq(Evaluator.permanent_value(wall), 7.0, 0.001)
	assert_almost_eq(Evaluator.permanent_value(specter), 5.5, 0.001)
	assert_gt(Evaluator.permanent_value(wall), Evaluator.permanent_value(specter),
		"a 0/8 that cannot attack outranks a 2/2 flier that eats a card a turn")


# ======================================================= the discount --

func test_the_discount_scales_with_the_toughness_it_discounts() -> void:
	# A defender's worth is its blocking, and blocking saturates: the
	# eighth point of toughness stops nothing the sixth did not, while a
	# 4/4's four power is a clock. So the discount is a share of the
	# toughness on top of the flat -1.0 the keyword already carried.
	var profile := _p6()
	var stone := put_battlefield(0, "Wall of Stone")      # 0/8
	var ice := put_battlefield(0, "Wall of Ice")          # 0/7
	var wood := put_battlefield(0, "Wall of Wood")        # 0/3
	assert_almost_eq(Evaluator.permanent_value(stone, profile), 3.8, 0.001)
	assert_almost_eq(Evaluator.permanent_value(ice, profile), 3.2, 0.001)
	assert_almost_eq(Evaluator.permanent_value(wood, profile), 0.8, 0.001)
	# and it stays MONOTONE in toughness — a bigger wall is still a better
	# wall, which a flat discount steep enough to matter would break.
	assert_gt(Evaluator.permanent_value(stone, profile),
		Evaluator.permanent_value(ice, profile))
	assert_gt(Evaluator.permanent_value(ice, profile),
		Evaluator.permanent_value(wood, profile))


func test_the_discount_puts_the_wall_under_the_bear_as_forge_does() -> void:
	# Forge's own table (`docs/forge/combat.md` §2.1): a Wall of Stone is
	# 155 points and a vanilla 2/2 is 160 — the wall JUST below the bear.
	var profile := _p6()
	var wall := put_battlefield(1, "Wall of Stone")
	var bears := put_battlefield(1, "Grizzly Bears")
	var specter := put_battlefield(1, "Hypnotic Specter")
	assert_lt(Evaluator.permanent_value(wall, profile),
		Evaluator.permanent_value(bears, profile), "just below the bear")
	assert_lt(Evaluator.permanent_value(wall, profile),
		Evaluator.permanent_value(specter, profile), "and well below the Specter")


func test_a_creature_that_is_no_defender_is_untouched_by_the_discount() -> void:
	var profile := _p6()
	for name in ["Grizzly Bears", "Hypnotic Specter", "White Knight", "Serra Angel"]:
		var inst := put_battlefield(0, name)
		assert_eq(Evaluator.permanent_value(inst, profile),
			Evaluator.permanent_value(inst), name)


# ========================================================== the bonus --

func test_the_bonus_lifts_a_tapper_and_a_mana_dork_off_the_vanilla_1_1() -> void:
	var profile := _p6()
	var tim := put_battlefield(0, "Prodigal Sorcerer")     # {T}: 1 damage
	var elves := put_battlefield(0, "Llanowar Elves")      # {T}: add {G}
	var sprites := put_battlefield(0, "Scryb Sprites")     # a 1/1 flier
	assert_almost_eq(Evaluator.permanent_value(tim), 2.0, 0.001, "today")
	assert_almost_eq(Evaluator.permanent_value(elves), 2.0, 0.001, "today")
	assert_almost_eq(Evaluator.permanent_value(tim, profile), 2.5, 0.001)
	assert_almost_eq(Evaluator.permanent_value(elves, profile), 2.5, 0.001)
	assert_eq(Evaluator.permanent_value(sprites, profile),
		Evaluator.permanent_value(sprites), "a vanilla body does not move")


func test_a_mana_ability_is_paid_once_however_many_colours_it_makes() -> void:
	# Forge pays a flat +10 for "manadork" and +10 per activated ability
	# (`CreatureEvaluator.java:226-233`); a Birds of Paradise makes five
	# colours off one ability and is one mana creature, not five.
	var profile := _p6()
	var birds := put_battlefield(0, "Birds of Paradise")
	assert_almost_eq(Evaluator.permanent_value(birds), 2.5, 0.001, "today")
	assert_almost_eq(Evaluator.permanent_value(birds, profile), 3.0, 0.001)


func test_the_bonus_reads_the_LIVE_abilities() -> void:
	# CONTRIBUTING rule 5: the price is a live reading, so a body whose
	# abilities have been stripped is a vanilla body again.
	var profile := _p6()
	var tim := put_battlefield(0, "Prodigal Sorcerer")
	assert_almost_eq(Evaluator.permanent_value(tim, profile), 2.5, 0.001)
	tim.cur_activated_abilities.clear()
	assert_almost_eq(Evaluator.permanent_value(tim, profile), 2.0, 0.001)


# ================================================ what actually moves --

func test_the_removal_pick_changes_hands() -> void:
	# The reproduction, both arms. Swords to Plowshares because it is the
	# pool's one white "destroy target creature" with no colour rider:
	# TERROR, which combat note P6 names, can legally target NEITHER of
	# the two cards it contrasts the Wall with — the Hypnotic Specter is
	# black and the White Knight has protection from black.
	for on in [true, false]:
		before_each()
		var ai := _ai(_p6() if on else AiProfile.wizard())
		put_battlefield(1, "Wall of Stone")
		put_battlefield(1, "Hypnotic Specter")
		var swords := give_hand(0, "Swords to Plowshares")
		put_battlefield(0, "Plains")
		var intent := EffectIntent.read(swords.data.spell_effects,
			swords.data.card_name)
		var victim: CardInstance = ai._best_victim(g, swords, intent, 0)
		assert_not_null(victim)
		assert_eq(victim.data.card_name,
			"Hypnotic Specter" if on else "Wall of Stone",
			"the threat" if on else "the wall, which is the malfunction")


func test_the_board_score_carries_the_profile_through() -> void:
	# [method Evaluator.position_score] is the one caller of
	# [method Evaluator.permanent_value] outside the pilot, and it has to
	# hand the profile on or a swept seat would score its own board by one
	# table and price it by another.
	var profile := _p6()
	put_battlefield(0, "Wall of Stone")
	assert_almost_eq(Evaluator.position_score(g, 0), 14.0, 0.001,
		"7.0 of board at W_BOARD 2.0")
	assert_almost_eq(Evaluator.position_score(g, 0, profile), 7.6, 0.001,
		"3.8 of board at W_BOARD 2.0")


# =========================================================== the sweep --

func test_the_lab_can_put_both_numbers_on_the_seat() -> void:
	var profile := AiProfile.wizard()
	assert_eq(typeof(profile.get("defender_scale")), TYPE_FLOAT,
		"the sweep reads a knob's type off a probe profile")
	assert_eq(typeof(profile.get("ability_bonus")), TYPE_FLOAT)
	assert_eq(profile.apply_overrides("defender_scale=0.4,ability_bonus=0.5"), "")
	assert_eq(profile.defender_scale, 0.4)
	assert_eq(profile.ability_bonus, 0.5)
	assert_eq(profile.apply_overrides("defender_scale=0,ability_bonus=0"), "")
	assert_eq(profile.defender_scale, 0.0)
	assert_eq(profile.ability_bonus, 0.0)
