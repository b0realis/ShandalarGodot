extends GameTest
## THE LIFE A TAP COSTS (2026-09-06). To the planner every point of mana
## was equally free, and The Deck's loss profile (docs/ROADMAP.md, "the
## control sweep") found it dying on turn 28 with eight lands untapped:
## four City of Brass paying a life a tap for twenty-eight turns. Now a
## source that hurts ([member ManaAbility.pain]) taps after the ones that
## do not, never for the last life, and never for mana that was only
## going to be wasted ([method AiPlayer._pain_excluded]).


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


## Advance into the OPPONENT's turn and hand seat 0 priority in [param step].
func _their_turn_at(step: int) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400, "never reached the opponent's %s" % Mtg.step_name(step))
	assert_eq(g.priority_player, 1)
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


# ------------------------------------------------------------ the planner --

func test_a_painless_source_taps_before_a_city_of_brass() -> void:
	# The City is the only source of white in this seat's four lands, yet
	# for {2}{G} the planner must reach for the Forests and the Sea — all
	# free — before it.
	var city := put_battlefield(0, "City of Brass")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Underground Sea")
	var src := ManaPlanner.sources(g, 0)
	assert_eq(src.back()[0], city, "the City sorts last")
	assert_eq(ManaPlanner.source_pain(src.back()), 1)
	var plan := ManaPlanner.plan(g, 0, ManaCost.parse("{2}{G}"), 0)
	assert_eq(plan.size(), 3)
	for step in plan:
		assert_ne(step[0], city, "not the City")
	# ...and for {W} it is the only way, so it is taken.
	plan = ManaPlanner.plan(g, 0, ManaCost.parse("{W}"), 0)
	assert_eq(plan.size(), 1)
	assert_eq(plan[0][0], city)


func test_a_dual_taps_before_elves_of_deep_shadow() -> void:
	# One option that costs a life against two that cost nothing: the
	# free flexibility is spent first.
	var elves := put_battlefield(0, "Elves of Deep Shadow")
	var sea := put_battlefield(0, "Underground Sea")
	var plan := ManaPlanner.plan(g, 0, ManaCost.parse("{B}"), 0)
	assert_eq(plan.size(), 1)
	assert_eq(plan[0][0], sea, "the Sea, not the Elves")
	var src := ManaPlanner.sources(g, 0)
	assert_eq(src[0][0], sea, "the Sea's two colours...")
	assert_eq(src[1][0], sea)
	assert_eq(src[2][0], elves, "...and then the Elves")


func test_the_null_planner_does_not_mind() -> void:
	# `mind_pain = false` is the Deck Lab's null: the Elves (one option)
	# sort before the Sea (two) exactly as they did before this pass.
	var elves := put_battlefield(0, "Elves of Deep Shadow")
	put_battlefield(0, "Underground Sea")
	var src := ManaPlanner.sources(g, 0, {}, false)
	assert_eq(src[0][0], elves)
	assert_eq(ManaPlanner.source_pain(src[0]), 0, "pain is not even recorded")


# ---------------------------------------------------------------- the AI --

func test_the_ai_does_not_tap_a_city_for_its_last_life() -> void:
	# At 1 life the City's tap is the game. A Grizzly Bears is castable
	# only through it — so it is not castable.
	var ai := _ai(AiProfile.wizard())
	put_battlefield(0, "City of Brass")
	put_battlefield(0, "Forest")
	var bears := give_hand(0, "Grizzly Bears")   # {1}{G}
	g.players[0].life = 1
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass", "two lands, one of them lethal to tap")
	assert_eq(bears.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].life, 1)
	# At 2 life the same tap is a life for a body, and it is taken: the
	# City's sting goes on the stack mid-payment, the AI holds the cast
	# until it resolves (see AiPlayer._wait_out), then casts from the
	# floating mana.
	g.players[0].life = 2
	g.priority_player = 0
	assert_eq(ai.act(g), "holds Grizzly Bears until the stack clears")
	resolve_stack()
	assert_eq(g.players[0].life, 1, "the City stung")
	g.priority_player = 0
	assert_string_contains(ai.act(g), "cast Grizzly Bears")
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].life, 1, "one life, once")


func test_the_apprentice_minds_its_last_life_too() -> void:
	assert_true(AiProfile.apprentice().minds_pain, "every profile: a suicide is not a weakness, it is a bug")
	assert_true(AiProfile.magician().minds_pain)
	var ai := _ai(AiProfile.apprentice())
	put_battlefield(0, "City of Brass")
	put_battlefield(0, "Forest")
	var bears := give_hand(0, "Grizzly Bears")
	g.players[0].life = 1
	advance_to_step(Mtg.Step.MAIN1)
	for _i in 6:
		ai.act(g)
		g.priority_player = 0
	assert_eq(bears.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].life, 1)


func test_the_mana_sink_prices_the_life_a_city_costs() -> void:
	# Their end step: a Rod of Ruin ping at their face is worth firing
	# with mana that is about to be wasted — from Mountains. Through a
	# City of Brass the third mana is a life, and a point for a point is
	# no trade: it waits. (The first cut REFUSED the City at the sink
	# outright and measured the same; it is priced instead because a
	# Tome draw at their end step IS worth the life — the next test.)
	var ai := _ai(AiProfile.wizard())
	put_battlefield(0, "Rod of Ruin")
	put_battlefield(0, "City of Brass")
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	_their_turn_at(Mtg.Step.END)
	assert_eq(ai.act(g), "pass", "a life for a ping")
	assert_eq(g.players[0].life, 20)
	assert_eq(g.players[1].life, 20)


func test_the_mana_sink_pays_a_life_for_a_card() -> void:
	var ai := _ai(AiProfile.wizard())
	put_battlefield(0, "Jayemdae Tome")   # {4}, {T}: draw a card
	put_battlefield(0, "City of Brass")
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	var hand_before := g.players[0].hand.size()
	_their_turn_at(Mtg.Step.END)
	assert_eq(ai.act(g), "activated Jayemdae Tome", "a card is worth the life")
	resolve_stack()
	assert_eq(g.players[0].life, 19, "the City stung")
	assert_eq(g.players[0].hand.size(), hand_before + 1)


func test_the_mana_sink_fires_from_painless_mana() -> void:
	var ai := _ai(AiProfile.wizard())
	put_battlefield(0, "Rod of Ruin")
	put_battlefield(0, "City of Brass")
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	_their_turn_at(Mtg.Step.END)
	assert_eq(ai.act(g), "activated Rod of Ruin")
	resolve_stack()
	assert_eq(g.players[0].life, 20, "paid from the Mountains")
	assert_eq(g.players[1].life, 19)


func test_the_main_phase_still_pays_a_life_for_a_spell() -> void:
	# The City is for exactly this: the colour the deck lacks, at a life.
	var ai := _ai(AiProfile.wizard())
	put_battlefield(0, "City of Brass")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	give_hand(0, "Serra Angel")   # {3}{W}{W} — no
	var knight := give_hand(0, "White Knight")   # {W}{W} — no, one City
	var bears := give_hand(0, "Grizzly Bears")   # {1}{G}
	give_hand(0, "Healing Salve")
	advance_to_step(Mtg.Step.MAIN1)
	var did := ai.act(g)
	assert_string_contains(did, "cast ")
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "the Bears from two Forests")
	assert_eq(g.players[0].life, 20, "and no life for it")
	assert_eq(knight.zone, Mtg.Zone.HAND)


func test_the_null_profile_taps_the_city_for_the_sink() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("minds_pain=off"), "")
	var ai := _ai(profile)
	put_battlefield(0, "Rod of Ruin")
	put_battlefield(0, "City of Brass")
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	_their_turn_at(Mtg.Step.END)
	assert_eq(ai.act(g), "activated Rod of Ruin")
	resolve_stack()
	assert_eq(g.players[0].life, 19, "the old planner: a life for a ping")
