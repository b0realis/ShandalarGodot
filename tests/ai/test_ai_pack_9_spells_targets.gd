extends GameTest
## Pack 9 (the Tempest block), the fair AI's TARGETS (stage 4, casting;
## engine package E7, [member AiProfile.forecasts_tactics]).
##
## 1. A COUNT ANOTHER TARGET SETS. Reap returns "up to X target cards,
##    where X is the number of black permanents target opponent controls"
##    ([method EffectBase.target_range_at]). The planner read the static
##    "any number" range and named every card in the graveyard; the engine
##    refused the cast. The count is now asked with the earlier slot's
##    target, and the best cards are named first.
## 2. CANNIBALIZE names two creatures of ONE controller — theirs — and
##    exiles their best ([method AiPlayer._choose_targets]).
## 3. MOGG ASSASSIN'S COIN. On a lost flip the opponent's pick is
##    destroyed, and the opponent picks our best creature: the activation
##    is worth half their creature less half our best one
##    ([method TempestSpells.coin_destroy_value]).
## With the gate off the pilot reads the old ranges and the plain removal
## value. The opponent's hidden hand never moves a decision.


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-9", true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(on := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _in_graveyard(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(inst)
	return inst


# ----------------------------------------------------------------------- Reap --

func test_reap_returns_as_many_cards_as_they_have_black_permanents() -> void:
	var ai := _ai()
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	put_battlefield(1, "Drudge Skeletons")
	put_battlefield(1, "Drudge Skeletons")
	var dragon := _in_graveyard(0, "Shivan Dragon")
	_in_graveyard(0, "Forest")
	var wurm := _in_graveyard(0, "Craw Wurm")
	_in_graveyard(0, "Llanowar Elves")
	var reap := give_hand(0, "Reap")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Reap")
	resolve_stack()
	assert_eq(reap.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(dragon.zone, Mtg.Zone.HAND, "two black permanents: the two best cards")
	assert_eq(wurm.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].hand.size(), 2)


func test_reap_with_nothing_black_across_the_table_is_kept() -> void:
	var ai := _ai()
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	put_battlefield(1, "Grizzly Bears")
	_in_graveyard(0, "Shivan Dragon")
	var reap := give_hand(0, "Reap")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(reap.zone, Mtg.Zone.HAND, "X is 0: up to no cards")
	var tapped := 0
	for land in g.players[0].battlefield:
		if land.tapped: tapped += 1
	assert_eq(tapped, 0, "and no land tapped for a refused cast")


func test_reap_ignores_their_hidden_hand() -> void:
	var sizes: Array = []
	for hand in [["Dark Ritual", "Terror"], ["Swamp"], []]:
		g = null
		before_each()
		var ai := _ai()
		put_battlefield(0, "Forest")
		put_battlefield(0, "Forest")
		put_battlefield(1, "Drudge Skeletons")
		_in_graveyard(0, "Shivan Dragon")
		_in_graveyard(0, "Craw Wurm")
		for card_name in hand: give_hand(1, card_name)
		give_hand(0, "Reap")
		advance_to_step(Mtg.Step.MAIN1)
		ai.act(g)
		resolve_stack()
		sizes.append(g.players[0].hand.size())
	assert_eq(sizes, [1, 1, 1])


# ---------------------------------------------------------------- Cannibalize --

func test_cannibalize_exiles_their_best_of_two() -> void:
	var ai := _ai()
	for _i in 2: put_battlefield(0, "Swamp")
	put_battlefield(0, "Grizzly Bears")
	var angel := put_battlefield(1, "Serra Angel")
	var elves := put_battlefield(1, "Llanowar Elves")
	give_hand(0, "Cannibalize")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Cannibalize")
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.EXILE)
	assert_eq(int(elves.counters.get("+1/+1", 0)), 2)


func test_cannibalize_never_eats_our_own_for_one_of_theirs() -> void:
	var ai := _ai()
	for _i in 2: put_battlefield(0, "Swamp")
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	put_battlefield(1, "Serra Angel")
	var cannibalize := give_hand(0, "Cannibalize")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(cannibalize.zone, Mtg.Zone.HAND, "one creature of theirs: no legal pair there")
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)


# --------------------------------------------------------------- Mogg Assassin --

func test_mogg_assassin_does_not_gamble_our_dragon_for_their_bears() -> void:
	var ai := _ai()
	var assassin := put_battlefield(0, "Mogg Assassin")
	var dragon := put_battlefield(0, "Shivan Dragon")
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_false(assassin.tapped, "half a Bears is not worth half a Dragon")
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD)


func test_mogg_assassin_gambles_itself_for_their_angel() -> void:
	var ai := _ai()
	var assassin := put_battlefield(0, "Mogg Assassin")
	put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "activated Mogg Assassin")
	assert_true(assassin.tapped)


func test_the_null_arm_reads_the_assassin_as_plain_removal() -> void:
	var ai := _ai(false)
	var assassin := put_battlefield(0, "Mogg Assassin")
	put_battlefield(0, "Shivan Dragon")
	put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_true(assassin.tapped, "gate off: a removal ability, the coin unread")
