extends GameTest
## Pack 10 (the Urza block), batch B7: the questions the Aura batch's cards
## ask as they resolve hold a human seat open (MtgGame's resolution
## pre-flight, docs/duel-todo.md §1.3) — the Aura controller's "you may"
## (Sanctimony, the counter upkeeps), a NON-controller's choice (the land
## Destructive Urge's damaged player sacrifices, Pattern of Rebirth's
## search) — and the rules presets where the cards differ (Carnival of
## Souls' {B} burns under mana burn; Pariah's redirect is the same under
## both).
##
## Fertile Ground's colour is asked by MtgGame.tap_for_mana before the tap is
## paid (Pack 10 E8) — a COST question that holds the land's human controller,
## whose answer reaches the trigger as TAPPED_FOR_MANA's `bonus_colors`.

func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()

func after_each() -> void:
	if g != null: g.interactive_choices = false
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func _human(pid: int) -> HumanAgent:
	var seat := HumanAgent.new()
	g.agents[pid] = seat
	g.interactive_choices = true
	return seat

func _priority_to(pid: int) -> void:
	if g.priority_player != pid: assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.priority_player, pid)

## Pass priority until a resolution holds the duel open on a question.
func _pass_until_held() -> void:
	var guard := 0
	while g.awaiting_choice == null and not g.game_over and guard < 200:
		if g.awaiting_attackers: assert_ok(g.declare_attackers(g.active_player, []))
		elif g.awaiting_blockers: assert_ok(g.declare_blockers(g.opponent_of(g.active_player), {}))
		else: assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_not_null(g.awaiting_choice, "a question holds the duel open")

func _enchant(pid: int, aura_name: String, host: CardInstance, mana: Array) -> CardInstance:
	_priority_to(pid)
	var aura := give_hand(pid, aura_name)
	for m in mana: add_mana(pid, int(m))
	assert_ok(g.cast_spell(pid, aura, [TargetRef.card(host)]))
	resolve_stack()
	return aura


func test_sanctimony_holds_its_human_controller_on_the_may() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Sanctimony")
	var mountain := put_battlefield(1, "Mountain")
	_human(0)
	_priority_to(1)
	assert_ok(g.tap_for_mana(1, mountain))
	_pass_until_held()
	assert_eq(g.awaiting_choice.pid, 0)
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.YES_NO)
	assert_ok(g.answer_choice(false))
	assert_eq(g.players[0].life, 20, "declined")

func test_private_research_holds_its_human_controller_on_the_counter() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := _enchant(0, "Private Research", bear, [Mtg.ManaColor.U])
	_human(0)
	_pass_until_held()
	assert_eq(g.active_player, 0, "its controller's upkeep")
	assert_eq(g.current_step(), Mtg.Step.UPKEEP)
	assert_eq(g.awaiting_choice.pid, 0)
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.YES_NO)
	assert_ok(g.answer_choice(true))
	assert_eq(int(aura.counters.get("page", 0)), 1)

func test_destructive_urge_holds_the_damaged_human_on_the_land() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var forest := put_battlefield(1, "Forest")
	var island := put_battlefield(1, "Island")
	_enchant(0, "Destructive Urge", bear, [Mtg.ManaColor.R, Mtg.ManaColor.R, Mtg.ManaColor.C])
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	_human(1)
	_pass_until_held()
	assert_eq(g.awaiting_choice.pid, 1, "the damaged player chooses")
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.CARD)
	assert_ok(g.answer_choice("Island"))
	assert_eq(island.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)

func test_pattern_of_rebirth_holds_the_dead_creatures_human_controller() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	_enchant(0, "Pattern of Rebirth", bear, [Mtg.ManaColor.G, Mtg.ManaColor.C, Mtg.ManaColor.C, Mtg.ManaColor.C])
	var terror := give_hand(0, "Terror")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, terror, [TargetRef.card(bear)]))
	_human(1)
	_pass_until_held()
	assert_eq(g.awaiting_choice.pid, 1, "that creature's controller")
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.YES_NO)
	assert_ok(g.answer_choice(false))
	assert_true(g.stack.is_empty())


func test_fertile_ground_holds_the_lands_human_controller_on_the_color() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var forest := put_battlefield(0, "Forest")
	_enchant(0, "Fertile Ground", forest, [Mtg.ManaColor.G, Mtg.ManaColor.C])
	_human(0)
	assert_ok(g.tap_for_mana(0, forest))
	assert_not_null(g.awaiting_choice, "asked before the tap is paid")
	assert_eq(g.awaiting_choice.pid, 0)
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.COLOR)
	assert_false(forest.tapped, "nothing is paid while the question is open")
	assert_ok(g.answer_choice(Mtg.ManaColor.U))
	assert_true(forest.tapped)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 1)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 1, "the color the player chose")
	assert_eq(g.unanswered_choices.size(), 0, "nothing decided on the player's behalf")

func test_fertile_ground_on_an_opponents_land_holds_that_lands_human_controller() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var forest := put_battlefield(1, "Forest")
	_enchant(0, "Fertile Ground", forest, [Mtg.ManaColor.G, Mtg.ManaColor.C])
	_priority_to(1)
	_human(1)
	assert_ok(g.tap_for_mana(1, forest))
	assert_not_null(g.awaiting_choice)
	assert_eq(g.awaiting_choice.pid, 1, "its controller adds the mana and chooses")
	assert_ok(g.answer_choice(Mtg.ManaColor.R))
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.R), 1)


## Mana burn (the 1997 preset): the {B} Carnival of Souls adds empties with
## the step and burns; without mana burn it simply empties.
func test_carnival_of_souls_mana_burns_only_under_mana_burn() -> void:
	for preset in ["modern", "fifth"]:
		before_each()
		if preset == "fifth": g.rules.set_edition("fifth")
		else: g.rules.set_preset("modern")
		advance_to_step(Mtg.Step.MAIN1)
		put_battlefield(0, "Carnival of Souls")
		var bears := give_hand(0, "Grizzly Bears")
		add_mana(0, Mtg.ManaColor.G)
		add_mana(0, Mtg.ManaColor.C)
		assert_ok(g.cast_spell(0, bears, []))
		resolve_stack()
		assert_eq(g.players[0].life, 19, preset)
		advance_to_step(Mtg.Step.COMBAT_BEGIN)
		assert_eq(g.players[0].life, 19 - (1 if preset == "fifth" else 0), preset)

func test_pariah_redirects_under_both_presets() -> void:
	for preset in ["modern", "fifth"]:
		before_each()
		if preset == "fifth": g.rules.set_edition("fifth")
		else: g.rules.set_preset("modern")
		advance_to_step(Mtg.Step.MAIN1)
		var giant := put_battlefield(1, "Hill Giant")
		_enchant(0, "Pariah", giant, [Mtg.ManaColor.W, Mtg.ManaColor.C, Mtg.ManaColor.C])
		_priority_to(1)
		var bolt := give_hand(1, "Lightning Bolt")
		add_mana(1, Mtg.ManaColor.R)
		assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
		resolve_stack()
		assert_eq(g.players[0].life, 20, preset)
		assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, preset)
