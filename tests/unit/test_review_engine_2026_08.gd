extends GameTest
## Engine pins from the 2026-08 code review (docs/code-review-2026-08.md).
## Each test failed before the fix in the same row of that document's table.


# --------------------------------------------- auto-payment vs LIVE abilities --

func test_auto_payment_reads_live_mana_abilities() -> void:
	# "Unless you pay" rents (Force of Nature, the lucky charms) auto-tap
	# lands through MtgGame.try_pay. The tap plan used to be built from the
	# PRINTED mana abilities while tap_for_mana activates the LIVE ones, so
	# under Blood Moon (every nonbasic land is a Mountain) a Tropical Island
	# still looked like a source of {G}: the rent read as affordable, and
	# "paying" it tapped the land for {R} and paid nothing.
	put_battlefield(1, "Blood Moon")
	var a := put_battlefield(0, "Tropical Island")
	var b := put_battlefield(0, "Tropical Island")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(a.cur_mana_abilities.size(), 1, "Blood Moon reduced it to one ability")
	var green := ManaCost.parse("{G}{G}")
	assert_false(g.can_afford_cost(0, green),
		"lands that only make {R} cannot cover {G}{G}")
	assert_false(g.try_pay(0, green), "and the payment must fail")
	assert_false(a.tapped, "a refused payment taps nothing")
	assert_false(b.tapped, "a refused payment taps nothing")
	# The same lands DO cover the red the Moon actually gives them.
	var red := ManaCost.parse("{R}{R}")
	assert_true(g.can_afford_cost(0, red), "two Mountains cover {R}{R}")
	assert_true(g.try_pay(0, red), "and paying it succeeds")
	assert_true(a.tapped and b.tapped, "both lands paid")


# ----------------------------------------------- auras leaving the battlefield --

func test_bouncing_a_control_aura_hands_the_host_back() -> void:
	# Control Magic's host went home when the aura was DESTROYED, but not
	# when it was bounced: return_to_hand skipped the departing-aura
	# settlement, so Boomerang on your own Control Magic kept the stolen
	# creature forever and left a dangling id in the host's attachments.
	var bear := put_battlefield(1, "Grizzly Bears")
	var magic := give_hand(0, "Control Magic")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, magic, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.controller_id, 0, "Control Magic stole the bear")
	assert_true(bear.attachments.has(magic.id))
	var boomerang := give_hand(0, "Boomerang")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, boomerang, [TargetRef.card(magic)]))
	resolve_stack()
	assert_eq(magic.zone, Mtg.Zone.HAND, "the aura bounced")
	assert_eq(bear.controller_id, 1, "the bear returns to its owner")
	assert_false(bear.attachments.has(magic.id),
		"and the host's attachment list has no dangling aura")
	assert_true(g.players[1].battlefield.has(bear))
	assert_false(g.players[0].battlefield.has(bear))


# ------------------------------------------------------- land drops & priority --

func test_land_drop_requires_priority() -> void:
	# CR 305.1: a land is played only when its controller has priority and
	# the stack is empty. The active player could play a land after passing
	# priority — while the OPPONENT held it — which also desynchronised the
	# pass counter.
	var forest := give_hand(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(g.priority_player, 0)
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1, "the opponent holds priority now")
	assert_refused(g.play_land(0, forest), "priority")
	assert_eq(forest.zone, Mtg.Zone.HAND)


func test_land_drop_keeps_priority_and_resets_the_pass_count() -> void:
	# Playing a land is a special action: the player keeps priority
	# afterwards (CR 117.3c/116.2c), so a prior pass by the opponent must
	# not carry over into "both players passed".
	var forest := give_hand(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))   # both passed: on to beginning of combat
	advance_to_step(Mtg.Step.MAIN2)
	assert_ok(g.pass_priority(0))   # active player passes...
	assert_eq(g.priority_player, 1)
	assert_ok(g.pass_priority(1))   # ...both passed, step advances
	advance_to_step(Mtg.Step.MAIN1)  # next turn belongs to player 1
	assert_eq(g.active_player, 1)
	# Player 1's own main phase: their land drop must leave them holding
	# priority with a clean pass count.
	var swamp := give_hand(1, "Swamp")
	assert_ok(g.play_land(1, swamp))
	assert_eq(g.priority_player, 1, "the lander keeps priority")
	assert_eq(g._passes, 0, "and the pass count restarts")
	assert_eq(swamp.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(forest.zone, Mtg.Zone.HAND)


# ------------------------------------------------ CR 613 sublayers 7b vs 7c --

func test_pt_setting_statics_run_before_additive_ones() -> void:
	# Nightmare's characteristic-defining ability SETS P/T (layer 7b);
	# Bad Moon's anthem ADDS to it (layer 7c). The pipeline ran every
	# static in one timestamp-ordered pass, so an anthem that entered
	# FIRST was silently overwritten — the answer depended on play order.
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Bad Moon")          # anthem first...
	var mare := put_battlefield(0, "Nightmare")   # ...setter second
	assert_eq(mare.cur_power, 4, "3 swamps (7b) then Bad Moon's +1/+1 (7c)")
	assert_eq(mare.cur_toughness, 4)


func test_pt_setting_statics_are_order_independent() -> void:
	# The mirror image: setter first, anthem second must give the same
	# answer. Order-dependence was the proof the layering was wrong.
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	var mare := put_battlefield(0, "Nightmare")
	put_battlefield(0, "Bad Moon")
	assert_eq(mare.cur_power, 4)
	assert_eq(mare.cur_toughness, 4)


# ------------------------------------------------- last known information --

func test_a_dead_permanent_remembers_its_live_toughness() -> void:
	# CR 608.2h: effects that read a permanent's characteristics after it
	# left the battlefield use LAST KNOWN INFORMATION. Zone-change wipes
	# cur_* back to printed values, so the departing values are snapshotted.
	var bear := put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Bad Moon")   # bears are green: no help
	var growth := give_hand(0, "Giant Growth")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_toughness, 5, "2 + Giant Growth's +3/+3")
	g.destroy(bear, false)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.last_toughness, 5, "the toughness it had as it died")
	assert_eq(bear.last_power, 5)
	assert_eq(bear.cur_toughness, 2, "and cur_* is back to printed")


# --------------------------------------------------- the AI's mana planner --

func test_ai_mana_plan_reads_live_mana_abilities() -> void:
	# The AI planned taps from the PRINTED mana abilities, so under Blood
	# Moon it "paid" {1}{G} with Mountains: the engine refused the cast and
	# the turn was thrown away with three lands tapped for nothing.
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	put_battlefield(1, "Blood Moon")
	for _i in 3:
		put_battlefield(0, "Tropical Island")   # {G}/{U} printed, {R} live
	give_hand(0, "Grizzly Bears")               # {1}{G} — uncastable now
	give_hand(0, "Mons's Goblin Raiders")       # {R}   — castable
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	resolve_stack()
	assert_null(g.find_on_battlefield(0, "Grizzly Bears"),
		"no green mana exists under Blood Moon")
	assert_not_null(g.find_on_battlefield(0, "Mons's Goblin Raiders"),
		"the AI spends the red it actually has")


func test_ai_mana_plan_ignores_costed_mana_abilities() -> void:
	# Standing Stones is "{1}, {T}, Pay 1 life: Add one mana of any color".
	# The planner counted it as a free source, tapped it mid-cast, and the
	# engine refused ("not enough floating mana") — cast lost, land wasted.
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	var mountain := put_battlefield(0, "Mountain")
	var mountain2 := put_battlefield(0, "Mountain")
	var stones := put_battlefield(0, "Standing Stones")
	give_hand(0, "Gray Ogre")   # {2}{R}: two Mountains are not enough
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	resolve_stack()
	assert_null(g.find_on_battlefield(0, "Gray Ogre"))
	assert_false(mountain.tapped, "nothing was spent on an impossible cast")
	assert_false(mountain2.tapped)
	assert_false(stones.tapped)
	assert_eq(g.players[0].life, 20, "and no life was paid")
