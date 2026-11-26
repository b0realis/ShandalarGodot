extends GameTest
## PLAYER REPORT 2026-11-26: "AI will lose the game playing lands while
## Ankh of Mishra is out. Even if it's at 1 life remaining." The price of a
## routine action — a land arriving, a land tapped for mana — charged by a
## permanent on the table (own_goal.gd, "THE TOLL ON A ROUTINE ACTION"):
##  1. no land drop into a toll that is our last life, either side's Ankh,
##     every standard rung; the gate's null arm is the pilot as it was;
##  2. tolls add up, and a toll that is a quarter of our life or more is
##     paid only for a land that unlocks a cast this turn;
##  3. a healthy life total plays its land as it always did, and so does a
##     table with no toll on it;
##  4. the second land under "whenever you play a land, if it wasn't the
##     first … deals 1 damage to you" is not played at 1 life;
##  5. a spell that puts a land onto the battlefield is not cast into a
##     lethal toll, and a fetch asked anyway is declined;
##  6. a cast is not paid for with land taps a "taps a land for mana" toll
##     makes lethal.

const OWN_GOAL := preload("res://engine/ai/own_goal.gd")


func after_each() -> void:
	g = null


func _ai(profile: AiProfile = null) -> AiPlayer:
	var p := profile if profile != null else AiProfile.wizard()
	p.develops_late = false
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _null() -> AiProfile:
	var p := AiProfile.wizard()
	p.forecasts_tactics = false
	return p


func _rungs() -> Array:
	return [AiProfile.apprentice(), AiProfile.magician(), AiProfile.sorcerer(), AiProfile.wizard()]


func _drive(ai: AiPlayer, n := 6) -> void:
	for _i in n:
		var line := ai.act(g)
		if not g.stack.is_empty(): resolve_stack()
		if line == "" or line == "pass" or g.game_over: break


func _library(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.LIBRARY
	g.players[pid].library.append(inst)
	return inst


# ------------------------------------------------------ 1 the last life --

func test_no_land_drop_into_a_lethal_ankh() -> void:
	for profile in _rungs():
		for side in 2:
			for life in [1, 2]:
				before_each()
				var ai := _ai(profile)
				advance_to_step(Mtg.Step.MAIN1)
				put_battlefield(side, "Ankh of Mishra")
				g.players[0].life = life
				var land := give_hand(0, "Forest")
				var tag := "%s, Ankh of seat %d, %d life" % [profile.profile_name, side, life]
				_drive(ai)
				assert_eq(land.zone, Mtg.Zone.HAND, tag)
				assert_eq(g.players[0].life, life, tag)
				assert_false(g.game_over, tag)


func test_null_arm_plays_it_as_before() -> void:
	var ai := _ai(_null())
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(1, "Ankh of Mishra")
	g.players[0].life = 2
	var land := give_hand(0, "Forest")
	_drive(ai)
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD, "the gate off is the pilot as it was")


# ------------------------------------------------- 2 the sum, the share --

func test_two_tolls_add_up() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Ankh of Mishra")
	put_battlefield(1, "Ankh of Mishra")
	g.players[0].life = 6
	var land := give_hand(0, "Forest")
	assert_eq(OWN_GOAL.land_drop_cost(g, ai, land), 4)
	assert_eq(g.players[0].life, 6, "the forecast puts everything back")
	g.players[0].life = 4
	assert_eq(OWN_GOAL.land_drop_cost(g, ai, land), OWN_GOAL.TOLL_LETHAL)
	assert_eq(g.players[0].life, 4)
	assert_false(g.game_over)
	assert_eq(land.zone, Mtg.Zone.HAND)
	assert_true(g.stack.is_empty())
	_drive(ai)
	assert_eq(land.zone, Mtg.Zone.HAND, "two Ankhs are four")
	assert_false(g.game_over)


func test_a_heavy_toll_is_paid_only_for_a_cast() -> void:
	# 2 of 5 life is more than a quarter: the land waits …
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Forest")   # before the Ankh: it hears every arrival
	put_battlefield(1, "Ankh of Mishra")
	g.players[0].life = 5
	var land := give_hand(0, "Forest")
	_drive(ai)
	assert_eq(land.zone, Mtg.Zone.HAND, "nothing to cast with it")
	assert_eq(g.players[0].life, 5)
	# … until it is the second mana of a Grizzly Bears.
	before_each()
	ai = _ai()
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Forest")
	put_battlefield(1, "Ankh of Mishra")
	g.players[0].life = 5
	land = give_hand(0, "Forest")
	var bears := give_hand(0, "Grizzly Bears")
	_drive(ai)
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD, "the land unlocks the Bears")
	assert_eq(g.players[0].life, 3)
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------- 3 the controls --

func test_a_healthy_life_plays_its_land() -> void:
	for profile in _rungs():
		before_each()
		var ai := _ai(profile)
		advance_to_step(Mtg.Step.MAIN1)
		put_battlefield(1, "Ankh of Mishra")
		var land := give_hand(0, "Forest")
		_drive(ai)
		assert_eq(land.zone, Mtg.Zone.BATTLEFIELD, profile.profile_name)
		assert_eq(g.players[0].life, 18, profile.profile_name)


func test_no_toll_no_change() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(1, "Howling Mine")
	put_battlefield(0, "Grizzly Bears")
	g.players[0].life = 1
	var land := give_hand(0, "Forest")
	assert_eq(OWN_GOAL.land_drop_cost(g, ai, land), 0)
	_drive(ai)
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].life, 1)


func test_the_line_reader() -> void:
	assert_eq(OWN_GOAL.life_toll_of_line(
		"Whenever a land enters the battlefield, Ankh of Mishra deals 2 damage to that land's controller."),
		{"amount": 2, "whom": "actor"})
	assert_eq(OWN_GOAL.life_toll_of_line(
		"Whenever you play a land, if it wasn't the first land you played this turn, Fastbond deals 1 damage to you."),
		{"amount": 1, "whom": "you"})
	assert_eq(OWN_GOAL.life_toll_of_line("Whenever a land enters, its controller loses 3 life."),
		{"amount": 3, "whom": "actor"})
	assert_eq(OWN_GOAL.life_toll_of_line("Whenever a land enters, each opponent loses 1 life."),
		{"amount": 1, "whom": "opponents"})
	assert_true(OWN_GOAL.life_toll_of_line(
		"Whenever a player plays a land, that player draws a card.").is_empty())
	assert_true(OWN_GOAL.life_toll_of_line(
		"When this creature enters, it deals 2 damage to any target.").is_empty())


# ----------------------------------------------------- 4 the second land --

func test_fastbond_second_land_at_one_life() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Fastbond")
	g.players[0].life = 1
	var first := give_hand(0, "Forest")
	var second := give_hand(0, "Forest")
	_drive(ai)
	var down := 0
	for land in [first, second]:
		if land.zone == Mtg.Zone.BATTLEFIELD: down += 1
	assert_eq(down, 1, "the first land is free, the second is our last life")
	assert_eq(g.players[0].life, 1)
	assert_false(g.game_over)


# ----------------------------------------------------------- 5 the fetch --

func test_land_fetch_is_not_cast_into_a_lethal_toll() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	for _i in 3: put_battlefield(0, "Forest")
	put_battlefield(1, "Ankh of Mishra")
	_library(0, "Forest")
	var wilds := give_hand(0, "Untamed Wilds")
	assert_eq(ai._cast_gate(g, wilds), "", "20 life: two is a price")
	g.players[0].life = 2
	assert_ne(ai._cast_gate(g, wilds), "", "2 life: the land is our last")
	_drive(ai)
	assert_eq(wilds.zone, Mtg.Zone.HAND)
	assert_eq(_ai(_null())._cast_gate(g, wilds), "", "the gate off is the pilot as it was")


func test_a_fetch_asked_anyway_is_declined() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	for _i in 3: put_battlefield(0, "Forest")
	put_battlefield(1, "Ankh of Mishra")
	var basic := _library(0, "Forest")
	var wilds := give_hand(0, "Untamed Wilds")
	g.players[0].life = 2
	add_mana(0, Mtg.ManaColor.G, 3)
	assert_ok(g.cast_spell(0, wilds, []))
	resolve_stack()
	assert_eq(basic.zone, Mtg.Zone.LIBRARY, "the search fails to find")
	assert_eq(g.players[0].life, 2)
	assert_false(g.game_over)
	# The control: at a healthy life the land is fetched and paid for.
	g.players[0].life = 20
	var again := give_hand(0, "Untamed Wilds")
	add_mana(0, Mtg.ManaColor.G, 3)
	assert_ok(g.cast_spell(0, again, []))
	resolve_stack()
	var lands := 0
	for inst in g.players[0].battlefield:
		if inst.is_land(): lands += 1
	assert_eq(lands, 4, "a basic land is fetched")
	assert_eq(g.players[0].life, 18)
	assert_not_null(ai)


# ------------------------------------------------------------ 6 the taps --

func test_no_cast_through_lethal_land_taps() -> void:
	for life in [1, 2]:
		before_each()
		var ai := _ai()
		advance_to_step(Mtg.Step.MAIN1)
		put_battlefield(1, "Manabarbs")
		for _i in 2: put_battlefield(0, "Forest")
		g.players[0].life = life
		var bears := give_hand(0, "Grizzly Bears")
		_drive(ai)
		assert_eq(bears.zone, Mtg.Zone.HAND, "%d life, two taps" % life)
		assert_eq(g.players[0].life, life)
		assert_false(g.game_over)


func test_land_taps_at_a_healthy_life() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(1, "Manabarbs")
	for _i in 2: put_battlefield(0, "Forest")
	g.players[0].life = 3
	var bears := give_hand(0, "Grizzly Bears")
	_drive(ai)
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "two of three life is a price")
	assert_eq(g.players[0].life, 1)


func test_the_land_put_reader() -> void:
	assert_eq(OWN_GOAL.lands_put_by(
		"Search your library for a basic land card, put that card onto the battlefield, then shuffle."), 1)
	assert_eq(OWN_GOAL.lands_put_by(
		"As an additional cost to cast this spell, sacrifice a land.\nSearch your library for up to two basic land cards, put them onto the battlefield, then shuffle."), 2)
	assert_eq(OWN_GOAL.lands_put_by(
		"Search your library for a basic land card, reveal it, put it into your hand, then shuffle."), 0)
	assert_eq(OWN_GOAL.lands_put_by("Destroy target land."), 0)
