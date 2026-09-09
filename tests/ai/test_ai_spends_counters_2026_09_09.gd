extends GameTest
## THE COUNTER THAT WAS NEVER SPENT (2026-09-09, [member
## AiProfile.spends_counters]).
##
## [method AiPlayer._ability_available] refused EVERY ability whose cost is
## "remove N <kind> counters from this permanent" — the line sat beside the
## exile and discard riders the mana planner cannot model — so in the whole
## history of this AI no counter had ever been removed as a cost. The
## report that surfaced it was Osai Vultures: *"Remove two carrion counters
## from this creature: it gets +1/+1 until end of turn"*, a bird that eats
## at every end step a creature died, blocks at 1/1 with the counters on
## it, and dies for nothing. A Scavenging Ghoul never regenerated off a
## corpse counter either, and a creature carrying Life Matrix's grant never
## regenerated at all.
##
## "ALLOW ALL COUNTER COSTS" IS THE WRONG RULE, and this file pins the
## right one on both arms. Every reader downstream prices the EFFECT and
## not the cost — the same blindness [member AiProfile.pays_sacrifices] is
## gated for — and a counter is not free the way tapping a land is. So:
## NOTHING BUT THE COST MAY READ THE COUNTER, and the two readers that can
## be asked from outside the card refuse it:
##
##  * the NAME, read by the characteristics pipeline ([method
##    ContinuousEffects.parse_pt_counter]): a Triskelion's +1/+1 counters
##    ARE the 4/4 body;
##  * the LIVE FIELD, read by the damage replacement ([member
##    CardInstance.damage_eats_counters]): a Rock Hydra's heads are its
##    life, point for point.
##
## What is left is FUEL — carrion, corpse, husk, matrix, dream — and fuel
## needs no price of its own, because to the evaluator, the combat maths
## and the damage replacement it is worth zero until it is spent.
##
## The whole set the ruling covers is pinned below (`grep -rn
## with_counter_cost cards/`), so a seventh card added to the pool either
## fits the rule or fails this file.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.spends_counters = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.spends_counters = false
	return profile


## The first ability of [param inst] whose cost is a counter, as its index
## — -1 when it has none.
func _counter_ability_of(inst: CardInstance) -> int:
	for index in inst.cur_activated_abilities.size():
		var ability: ActivatedAbility = inst.cur_activated_abilities[index]
		if ability.counter_cost_kind != "":
			return index
	return -1


## [param card_name] on our battlefield with [param count] counters of its
## own cost's kind already on it.
func _fed(card_name: String, count: int) -> CardInstance:
	var inst := put_battlefield(0, card_name)
	var index := _counter_ability_of(inst)
	assert_gt(index, -1, "%s has a counter-cost ability" % card_name)
	var ability: ActivatedAbility = inst.cur_activated_abilities[index]
	if count > 0:
		g.add_counters(inst, ability.counter_cost_kind, count)
	g.recalculate()
	return inst


# ------------------------------------------------------- the report itself --

func test_the_vultures_sit_on_their_carrion_with_the_knob_off() -> void:
	var ai := _ai(_off())
	var birds := _fed("Osai Vultures", 2)
	assert_eq(int(birds.counters.get("carrion", 0)), 2, "two carrion counters")
	assert_false(ai._ability_available(g, birds, _counter_ability_of(birds)),
		"the bird cannot see its own pump")


func test_the_vultures_spend_their_carrion_with_the_knob_on() -> void:
	var ai := _ai(_on())
	var birds := _fed("Osai Vultures", 2)
	assert_true(ai._ability_available(g, birds, _counter_ability_of(birds)),
		"two counters buy the +1/+1")


func test_the_bird_that_dies_for_nothing_trades_instead() -> void:
	# The whole report in one combat: a 1/1 flier with two carrion counters
	# in front of a Grizzly Bears. +1/+1 makes it a 2/2 that takes the
	# Bears with it; without the counters it dies alone.
	for knob in [false, true]:
		before_each()
		var ai := _ai(_on() if knob else _off())
		var birds := _fed("Osai Vultures", 2)
		var bears := put_battlefield(1, "Grizzly Bears")
		g.active_player = 1
		advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
		assert_ok(g.declare_attackers(1, [bears.id]))
		advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
		assert_ok(g.declare_blockers(0, {birds.id: bears.id}))
		if g.priority_player != 0:
			g.pass_priority(g.priority_player)
		var did := ai.act(g)
		if knob:
			assert_eq(did, "pumps Osai Vultures", "it spends the two counters")
			assert_eq(int(birds.counters.get("carrion", 0)), 0, "both spent")
			resolve_stack()
			assert_eq(birds.cur_power, 2, "a 2/2 for the trade")
		else:
			assert_eq(did, "pass", "the null has nothing to offer")
		while g.current_step() == Mtg.Step.DECLARE_BLOCKERS:
			g.pass_priority(g.priority_player)
		assert_eq(birds.zone, Mtg.Zone.GRAVEYARD, "the bird dies either way")
		assert_eq(bears.zone,
			Mtg.Zone.GRAVEYARD if knob else Mtg.Zone.BATTLEFIELD,
			"but with the counters spent it does not die alone (knob %s)" % knob)


func test_the_ghoul_regenerates_off_a_corpse_counter() -> void:
	for knob in [false, true]:
		before_each()
		var ai := _ai(_on() if knob else _off())
		var ghoul := _fed("Scavenging Ghoul", 1)
		var shielded := ai._shield(g, ghoul)
		if knob:
			assert_eq(shielded, "shields Scavenging Ghoul",
				"the corpse counter buys the regeneration")
			resolve_stack()
			assert_eq(ghoul.regeneration_shields, 1, "the shield is up")
			assert_eq(int(ghoul.counters.get("corpse", 0)), 0, "the counter paid for it")
		else:
			assert_eq(shielded, "", "the null has no shield to offer")
			assert_eq(int(ghoul.counters.get("corpse", 0)), 1, "the counter is untouched")


# -------------------------------------------------------------- the traps --

func test_a_triskelions_counters_are_its_body_and_are_refused() -> void:
	# Six mana for a 4/4 that can shoot three times — and each shot sells
	# two points of creature for one point of damage. Every reader
	# downstream prices the damage and none of them price the body, so the
	# ping stays invisible on BOTH arms.
	for knob in [false, true]:
		before_each()
		var ai := _ai(_on() if knob else _off())
		var tris := put_battlefield(0, "Triskelion")
		assert_eq(int(tris.counters.get("+1/+1", 0)), 3, "it enters with three")
		assert_eq(tris.cur_power, 4, "a 4/4 while it holds them")
		assert_false(ai._ability_available(g, tris, _counter_ability_of(tris)),
			"the counter IS the body — refused with the knob %s" % knob)


func test_the_name_is_what_says_a_counter_is_the_body() -> void:
	# Nothing card-named: the pipeline's own parser is the reader, so any
	# P/T counter a card invents is refused by the same line.
	assert_eq(ContinuousEffects.parse_pt_counter("+1/+1"), Vector2i(1, 1))
	assert_eq(ContinuousEffects.parse_pt_counter("-0/-2"), Vector2i(0, -2))
	assert_eq(ContinuousEffects.parse_pt_counter("+1/+0"), Vector2i(1, 0))
	for fuel in ["carrion", "corpse", "husk", "matrix", "dream", "charge"]:
		assert_eq(ContinuousEffects.parse_pt_counter(fuel), Vector2i.ZERO,
			"%s is not part of anybody's size" % fuel)


## A permanent that sheds a counter instead of taking damage — Rock Hydra's
## line, with a kind whose NAME says nothing, so the refusal has to come
## from the live field and cannot come from the parser.
static func _armour_static(_game: MtgGame, source: CardInstance) -> void:
	source.damage_eats_counters = "husk"


func _counter_armour() -> CardData:
	return CardData.new("Test Counter Armour", "{2}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.static_ability(StaticAbility.new(_armour_static,
			"For each 1 damage that would be dealt to this creature, if it has a husk counter on it, remove a husk counter from it and prevent that 1 damage.")) \
		.activated(ActivatedAbility.new("", false, [RegenerateEffect.new()],
			"Remove a husk counter from this creature: Regenerate this creature.") \
			.with_counter_cost("husk", 1)) \
		.oracle("")


func test_a_counter_that_is_the_armour_is_refused_by_the_live_field() -> void:
	# A ROCK HYDRA'S HEADS ARE ITS LIFE. The kind is called "husk" here on
	# purpose: the parser has nothing to say about it, and the refusal is
	# [member CardInstance.damage_eats_counters] alone.
	for knob in [false, true]:
		before_each()
		var ai := _ai(_on() if knob else _off())
		var armour := put_synthetic(0, _counter_armour())
		g.add_counters(armour, "husk", 3)
		g.recalculate()
		assert_eq(armour.damage_eats_counters, "husk", "the static named the kind")
		assert_false(ai._ability_available(g, armour, _counter_ability_of(armour)),
			"the counter IS the armour — refused with the knob %s" % knob)


func test_the_hydra_itself_owns_no_counter_cost_and_keeps_its_heads() -> void:
	# The shipped Rock Hydra prices both of its abilities in MANA, so this
	# ruling never reaches it; the reading above is what would refuse the
	# grant if anything ever handed it one on its own heads.
	var hydra := put_battlefield(0, "Rock Hydra")
	g.add_counters(hydra, "+1/+1", 3)
	g.recalculate()
	assert_eq(_counter_ability_of(hydra), -1, "no ability of its own costs a counter")
	assert_eq(hydra.damage_eats_counters, "+1/+1", "and the field says why it would be refused")


func test_a_matrix_counter_on_a_hydra_is_fuel_and_is_spent() -> void:
	# The other half of the same board: Life Matrix's grant costs a MATRIX
	# counter, which is nobody's body and nobody's armour, so the Hydra may
	# regenerate off it with every head still on.
	var ai := _ai(_on())
	var hydra := put_battlefield(0, "Rock Hydra")
	g.add_counters(hydra, "+1/+1", 3)
	var matrix := put_battlefield(0, "Life Matrix")
	g.active_player = 0
	advance_to_step(Mtg.Step.UPKEEP)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, matrix, 0, [TargetRef.card(hydra)]))
	resolve_stack()
	assert_eq(int(hydra.counters.get("matrix", 0)), 1, "the Matrix planted one")
	var index := _counter_ability_of(hydra)
	assert_gt(index, -1, "the grant is on the Hydra")
	assert_true(ai._ability_available(g, hydra, index),
		"a matrix counter is fuel even on a body whose OTHER counters are its life")
	assert_eq(hydra.cur_power, 3, "and its heads are untouched")


func test_a_counter_cost_it_cannot_pay_is_refused_on_both_arms() -> void:
	for knob in [false, true]:
		before_each()
		var ai := _ai(_on() if knob else _off())
		var starving := _fed("Osai Vultures", 1)     # the pump wants TWO
		assert_false(ai._ability_available(g, starving, _counter_ability_of(starving)),
			"one carrion counter does not buy a two-counter pump (knob %s)" % knob)
		var empty := _fed("Scavenging Ghoul", 0)
		assert_false(ai._ability_available(g, empty, _counter_ability_of(empty)),
			"an unfed Ghoul has nothing to spend (knob %s)" % knob)


func test_the_count_is_checked_before_the_mana_is_spent() -> void:
	# The engine would refuse an empty Necropolis AFTER the {5} was tapped.
	# The gate reads the counters first, so the refusal costs no land.
	var ai := _ai(_on())
	var empty := _fed("Necropolis of Azar", 0)
	for _i in 5:
		put_battlefield(0, "Swamp")
	assert_false(ai._ability_available(g, empty, _counter_ability_of(empty)))
	var fed := _fed("Necropolis of Azar", 1)
	assert_true(ai._ability_available(g, fed, _counter_ability_of(fed)),
		"one husk counter and five lands buy a Spawn")


func test_the_counters_are_the_cap_on_a_free_breath() -> void:
	# Osai Vultures' pump asks for NO mana, so a reach counted in mana
	# alone would read it as +20/+20. The budget is the bound, and the
	# budget is what is on the bird now.
	var ai := _ai(_on())
	var birds := _fed("Osai Vultures", 5)
	for _i in 6:
		put_battlefield(0, "Plains")
	var index := _counter_ability_of(birds)
	var ability: ActivatedAbility = birds.cur_activated_abilities[index]
	var sources := ai._mana_sources(g)
	assert_eq(ai._pumps_in_reach(g, birds, ability, sources, null, -1), 2,
		"five carrion counters buy two pumps, not six and not twenty")
	g.add_counters(birds, "carrion", 1)
	g.recalculate()
	assert_eq(ai._pumps_in_reach(g, birds, ability, sources, null, -1), 3,
		"a sixth counter buys the third")


func test_a_free_breath_never_touches_the_reserve() -> void:
	# The counters are the whole cost, so the Counterspell's mana is not
	# even in the question — the reserve cannot bind a breath that spends
	# no mana at all.
	var ai := _ai(_on())
	var birds := _fed("Osai Vultures", 4)
	for _i in 2:
		put_battlefield(0, "Island")
	give_hand(0, "Counterspell")
	var index := _counter_ability_of(birds)
	var ability: ActivatedAbility = birds.cur_activated_abilities[index]
	var sources := ai._mana_sources(g)
	var kept := ai._pump_reserve(g, sources)
	assert_eq(ai._pumps_in_reach(g, birds, ability, sources, kept, -1), 2,
		"two pumps, and the two Islands are still the Counterspell's")


func test_a_counter_is_a_thing_the_turn_runs_out_of() -> void:
	# The gate that refuses an ability costing NOTHING the turn can run out
	# of — no tap, no mana, no life, no per-turn cap — used to catch Osai
	# Vultures on its way past the counter line. A counter is exactly such
	# a thing, and the line says so.
	var ai := _ai(_on())
	var birds := _fed("Osai Vultures", 2)
	var index := _counter_ability_of(birds)
	var ability: ActivatedAbility = birds.cur_activated_abilities[index]
	assert_false(ability.tap_cost, "no tap")
	assert_eq(ability.cost.mana_value(), 0, "no mana")
	assert_eq(ability.life_cost, 0, "no life")
	assert_eq(ability.max_per_turn, 0, "no per-turn cap of its own")
	assert_true(ai._ability_available(g, birds, index),
		"and it is still available, because the counters run out")


# --------------------------------------- the whole set the ruling covers --

func test_every_counter_cost_in_the_pool_is_ruled_on() -> void:
	# `grep -rn with_counter_cost cards/` is six cards and seven abilities;
	# one of the seven is a MANA ability, which [method
	# ManaPlanner.sources] has always left out by name of the same rider.
	# The other six are these, and each one's verdict is the rule's, not a
	# list's.
	var ai := _ai(_on())
	var expected := {
		"Osai Vultures": true,          # carrion — fuel, a trigger refills it
		"Scavenging Ghoul": true,       # corpse  — fuel, a trigger refills it
		"Necropolis of Azar": true,     # husk    — fuel, a trigger refills it
		"Rasputin Dreamweaver": true,   # dream   — fuel, the upkeep refills it
		"Triskelion": false,            # +1/+1   — the body
	}
	for card_name in expected:
		var inst := put_battlefield(0, card_name)
		var index := _counter_ability_of(inst)
		assert_gt(index, -1, "%s has a counter-cost ability" % card_name)
		var ability: ActivatedAbility = inst.cur_activated_abilities[index]
		if int(inst.counters.get(ability.counter_cost_kind, 0)) < ability.counter_cost_count:
			g.add_counters(inst, ability.counter_cost_kind, ability.counter_cost_count)
		g.recalculate()
		assert_eq(ai._ability_available(g, inst, index), bool(expected[card_name]),
			"%s: remove %d %s" % [card_name, ability.counter_cost_count,
				ability.counter_cost_kind])


func test_rasputins_mana_ability_stays_the_planners_business() -> void:
	# The seventh ability is [ManaAbility], and it is refused a layer
	# lower and for a different reason: [method ManaPlanner.sources] leaves
	# out every rider it cannot pay mid-plan. This ruling does not reach it
	# and does not want to.
	var ai := _ai(_on())
	var rasputin := put_battlefield(0, "Rasputin Dreamweaver")
	assert_eq(int(rasputin.counters.get("dream", 0)), 7, "seven dream counters")
	var sources := ai._mana_sources(g)
	for src in sources:
		assert_ne(src[0], rasputin, "the planner never taps a dream counter")


func test_a_clock_is_out_of_this_rulings_reach_and_says_so() -> void:
	# The two cards the report named as the danger are not reached at all,
	# and it is worth pinning WHY rather than trusting the rule to have
	# been lucky. Armageddon Clock removes its doom counter as an EFFECT,
	# not as a cost; the Oracle Time Vault this engine implements carries
	# no counters at any point.
	var clock := put_battlefield(0, "Armageddon Clock")
	g.add_counters(clock, "doom", 3)
	g.recalculate()
	assert_eq(_counter_ability_of(clock), -1,
		"the Clock's rewind is an effect, so no cost of it is a counter")
	var vault := put_battlefield(0, "Time Vault")
	assert_eq(_counter_ability_of(vault), -1, "and the Vault has no counters at all")
	assert_true(vault.counters.is_empty())


func test_the_batteries_are_the_planners_business_too() -> void:
	# "Remove ANY NUMBER of charge counters" is a mana ability with its own
	# question (`@MANABATTERY`), and it is not this ruling's shape: the
	# count is the controller's call at tap time, not a fixed cost.
	var battery := put_battlefield(0, "Black Mana Battery")
	assert_eq(_counter_ability_of(battery), -1,
		"the discharge is a ManaAbility, and its counters are any number")


# ------------------------------------------------------------- the ladder --

func test_the_knob_is_monotone_up_the_ladder() -> void:
	assert_false(AiProfile.apprentice().spends_counters)
	assert_false(AiProfile.magician().spends_counters)
	assert_true(AiProfile.sorcerer().spends_counters)
	assert_true(AiProfile.wizard().spends_counters)


func test_the_lab_can_override_the_knob() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("spends_counters=off"), "")
	assert_false(profile.spends_counters)
	assert_eq(profile.apply_overrides("spends_counters=on"), "")
	assert_true(profile.spends_counters)
