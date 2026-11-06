extends GameTest
## Pack 10 (the Urza block), batch B3: the black, red and green Urza's Saga
## creatures of cards/sets/usg/_creatures.gd — Carrion Beetles, the two
## Paladins, Looming Shade, Phyrexian Ghoul, Sanguine Guard, Unworthy Dead,
## Fire Ants, Shivan Hellkite, Viashino Runner, Viashino Sandswimmer,
## Elvish Herder, Elvish Lyrist, Hawkeater Moth, Treefolk Seedlings and
## Treetop Rangers. Each test pins the clause that makes the card that card,
## with its refused case.

const CLAIMED := ["Carrion Beetles", "Eastern Paladin", "Looming Shade", "Phyrexian Ghoul",
	"Sanguine Guard", "Unworthy Dead", "Western Paladin", "Fire Ants", "Shivan Hellkite",
	"Viashino Runner", "Viashino Sandswimmer", "Elvish Herder", "Elvish Lyrist",
	"Hawkeater Moth", "Treefolk Seedlings", "Treetop Rangers"]


## FIFO card picks; an empty queue takes the first candidate.
class Scripted extends DecisionAgent:
	var picks: Array = []

	func answer_card(_g: MtgGame, _p: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		if picks.is_empty():
			return null if candidates.is_empty() else candidates[0]
		var want: Variant = picks.pop_front()
		for c in candidates:
			if want is CardInstance and c == want:
				return c
			if want is String and c.data.card_name == want:
				return c
		return null


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func seat(pid: int) -> Scripted:
	var a := Scripted.new()
	g.set_agent(pid, a)
	return a

func fund(pid: int, card: CardInstance) -> void:
	var cost := card.data.cost
	for c in cost.colored:
		add_mana(pid, c, int(cost.colored[c]))
	if cost.generic > 0:
		add_mana(pid, Mtg.ManaColor.C, cost.generic)

func cast(card_name: String, targets: Array = [], pid := 0) -> CardInstance:
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	var card := give_hand(pid, card_name)
	fund(pid, card)
	assert_ok(g.cast_spell(pid, card, targets))
	resolve_stack()
	return card

func bury(pid: int, card_name: String) -> CardInstance:
	var inst := put_battlefield(pid, card_name)
	g.destroy(inst)
	assert_eq(inst.zone, Mtg.Zone.GRAVEYARD)
	return inst

## P0 attacks with [param attacker]; P1 is to declare blockers.
func _attack(attacker: CardInstance) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_true(g.awaiting_blockers)

## The next coin flip's outcome, read off a copy of the duel's generator
## (MtgGame.flip_coin: an even draw wins).
func _next_flip_wins() -> bool:
	var probe := RandomNumberGenerator.new()
	probe.seed = g.rng.seed
	probe.state = g.rng.state
	return probe.randi() % 2 == 0


func test_claimed_cards_are_no_longer_pending() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		assert_eq(c.set_code, "usg", card_name)
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending", card_name)


# --- Carrion Beetles --------------------------------------------------------

func test_carrion_beetles_exile_up_to_three_cards_from_one_graveyard() -> void:
	var beetles := put_battlefield(0, "Carrion Beetles")
	var a := bury(1, "Grizzly Bears")
	var b := bury(1, "Hill Giant")
	var c := bury(1, "Forest")
	var d := bury(1, "Mountain")
	var mine := bury(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, beetles, 0, [TargetRef.card(a), TargetRef.card(mine)]))
	assert_refused(g.activate_ability(0, beetles, 0,
		[TargetRef.card(a), TargetRef.card(b), TargetRef.card(c), TargetRef.card(d)]))
	assert_ok(g.activate_ability(0, beetles, 0, [TargetRef.card(a), TargetRef.card(b), TargetRef.card(c)]))
	assert_true(beetles.tapped)
	resolve_stack()
	for inst in [a, b, c]:
		assert_eq(inst.zone, Mtg.Zone.EXILE)
	assert_eq(d.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD)

func test_carrion_beetles_may_name_no_card_at_all() -> void:
	var beetles := put_battlefield(0, "Carrion Beetles")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, beetles, 0, []))
	resolve_stack()
	assert_true(beetles.tapped)


# --- Eastern Paladin / Western Paladin --------------------------------------

func test_the_paladins_destroy_green_and_white_creatures() -> void:
	var east := put_battlefield(0, "Eastern Paladin")
	var west := put_battlefield(0, "Western Paladin")
	var elves := put_battlefield(1, "Llanowar Elves")
	var lions := put_battlefield(1, "Savannah Lions")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_refused(g.activate_ability(0, east, 0, [TargetRef.card(lions)]))
	assert_ok(g.activate_ability(0, east, 0, [TargetRef.card(elves)]))
	resolve_stack()
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)
	add_mana(0, Mtg.ManaColor.B)
	assert_refused(g.activate_ability(0, west, 0, [TargetRef.card(lions)]), "mana")
	add_mana(0, Mtg.ManaColor.B)
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_refused(g.activate_ability(0, west, 0, [TargetRef.card(bear)]))
	assert_ok(g.activate_ability(0, west, 0, [TargetRef.card(lions)]))
	resolve_stack()
	assert_eq(lions.zone, Mtg.Zone.GRAVEYARD)


# --- Looming Shade / Phyrexian Ghoul ----------------------------------------

func test_looming_shade_pumps_for_each_black() -> void:
	var shade := put_battlefield(0, "Looming Shade")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.activate_ability(0, shade, 0))
	assert_ok(g.activate_ability(0, shade, 0))
	resolve_stack()
	assert_eq([shade.cur_power, shade.cur_toughness], [3, 3])
	assert_refused(g.activate_ability(0, shade, 0), "mana")
	advance_to_next_turn()
	assert_eq([shade.cur_power, shade.cur_toughness], [1, 1])

func test_phyrexian_ghoul_eats_a_creature_for_two_two() -> void:
	var p0 := seat(0)
	var ghoul := put_battlefield(0, "Phyrexian Ghoul")
	var bear := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	p0.picks = [bear]
	assert_ok(g.activate_ability(0, ghoul, 0))
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq([ghoul.cur_power, ghoul.cur_toughness], [4, 4])

func test_phyrexian_ghoul_may_eat_itself() -> void:
	var p0 := seat(0)
	var ghoul := put_battlefield(0, "Phyrexian Ghoul")
	p0.picks = [ghoul]
	assert_ok(g.activate_ability(0, ghoul, 0))
	resolve_stack()
	assert_eq(ghoul.zone, Mtg.Zone.GRAVEYARD)


# --- Regenerators -----------------------------------------------------------

func test_sanguine_guard_strikes_first_and_regenerates() -> void:
	var guard := put_battlefield(0, "Sanguine Guard")
	assert_true(guard.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	add_mana(0, Mtg.ManaColor.B)
	assert_refused(g.activate_ability(0, guard, 0), "mana")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, guard, 0))
	resolve_stack()
	g.destroy(guard)
	assert_eq(guard.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(guard.tapped)

func test_unworthy_dead_regenerates_for_b() -> void:
	var dead := put_battlefield(0, "Unworthy Dead")
	assert_refused(g.activate_ability(0, dead, 0), "mana")
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, dead, 0))
	resolve_stack()
	g.destroy(dead)
	assert_eq(dead.zone, Mtg.Zone.BATTLEFIELD)
	g.destroy(dead)
	assert_eq(dead.zone, Mtg.Zone.GRAVEYARD, "one shield, one destruction")


# --- Fire Ants --------------------------------------------------------------

func test_fire_ants_burn_each_other_creature_without_flying() -> void:
	var ants := put_battlefield(0, "Fire Ants")
	var bear := put_battlefield(0, "Grizzly Bears")
	var elves := put_battlefield(1, "Llanowar Elves")
	var angel := put_battlefield(1, "Serra Angel")
	var giant := put_battlefield(1, "Hill Giant")
	var sick := put_battlefield(0, "Fire Ants", true)
	assert_refused(g.activate_ability(0, sick, 0))
	assert_ok(g.activate_ability(0, ants, 0))
	assert_true(ants.tapped)
	resolve_stack()
	assert_eq(ants.damage, 0, "not itself")
	assert_eq(ants.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(sick.zone, Mtg.Zone.GRAVEYARD, "another Fire Ants is an other creature")
	assert_eq(bear.damage, 1, "ours too")
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(angel.damage, 0, "flying")
	assert_eq(giant.damage, 1)


# --- Shivan Hellkite --------------------------------------------------------

func test_shivan_hellkite_pings_for_one_r() -> void:
	var kite := put_battlefield(0, "Shivan Hellkite")
	var elves := put_battlefield(1, "Llanowar Elves")
	assert_true(kite.has_keyword(Mtg.Keyword.FLYING))
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.activate_ability(0, kite, 0, [TargetRef.player(1)]), "mana")
	add_mana(0, Mtg.ManaColor.C)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, kite, 0, [TargetRef.player(1)]))
	assert_ok(g.activate_ability(0, kite, 0, [TargetRef.card(elves)]))
	assert_false(kite.tapped)
	resolve_stack()
	assert_eq(g.players[1].life, 19)
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)


# --- Viashino Runner --------------------------------------------------------

func test_viashino_runner_needs_two_blockers() -> void:
	var runner := put_battlefield(0, "Viashino Runner")
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	assert_eq(runner.cur_min_blockers, 2)
	_attack(runner)
	assert_refused(g.declare_blockers(1, {bear.id: runner.id}))
	assert_ok(g.declare_blockers(1, {bear.id: runner.id, giant.id: runner.id}))


# --- Viashino Sandswimmer ---------------------------------------------------

## Both sides of the coin: the duel's own generator decides, so the test
## reads the next flip off a copy of it and walks seeds until each side
## has been seen.
func test_viashino_sandswimmer_returns_on_a_win_and_is_sacrificed_on_a_loss() -> void:
	var seen := {}
	for s in range(1, 40):
		before_each()
		g.rng.seed = s
		var swimmer := put_battlefield(0, "Viashino Sandswimmer")
		add_mana(0, Mtg.ManaColor.R)
		assert_ok(g.activate_ability(0, swimmer, 0))
		var wins := _next_flip_wins()
		resolve_stack()
		assert_eq(swimmer.zone, Mtg.Zone.HAND if wins else Mtg.Zone.GRAVEYARD, "seed %d" % s)
		seen[wins] = true
		if seen.size() == 2:
			break
	assert_eq(seen.size(), 2, "both outcomes seen")

## CR 400.7: the creature that left and came back is a new object — the
## old activation neither returns nor sacrifices it, whatever the flip.
func test_viashino_sandswimmer_flip_does_nothing_to_a_new_object() -> void:
	var swimmer := put_battlefield(0, "Viashino Sandswimmer")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, swimmer, 0))
	g.return_to_hand(swimmer)
	g.put_from_hand_into_play(swimmer, 0)
	resolve_stack()
	assert_eq(swimmer.zone, Mtg.Zone.BATTLEFIELD)


# --- Elvish Herder / Elvish Lyrist ------------------------------------------

func test_elvish_herder_lends_trample() -> void:
	var herder := put_battlefield(0, "Elvish Herder", true)
	var wurm := put_battlefield(0, "Craw Wurm")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, herder, 0, [TargetRef.card(wurm)]))
	resolve_stack()
	assert_true(wurm.has_keyword(Mtg.Keyword.TRAMPLE))
	advance_to_next_turn()
	assert_false(wurm.has_keyword(Mtg.Keyword.TRAMPLE))

func test_elvish_lyrist_sacrifices_itself_to_destroy_an_enchantment() -> void:
	var sick := put_battlefield(0, "Elvish Lyrist", true)
	var lyrist := put_battlefield(0, "Elvish Lyrist")
	var crusade := put_battlefield(1, "Crusade")
	var bear := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.activate_ability(0, sick, 0, [TargetRef.card(crusade)]))
	assert_refused(g.activate_ability(0, lyrist, 0, [TargetRef.card(bear)]))
	assert_ok(g.activate_ability(0, lyrist, 0, [TargetRef.card(crusade)]))
	assert_eq(lyrist.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(crusade.zone, Mtg.Zone.GRAVEYARD)


# --- Hawkeater Moth ---------------------------------------------------------

func test_hawkeater_moth_flies_and_has_shroud() -> void:
	var moth := put_battlefield(0, "Hawkeater Moth")
	assert_true(moth.has_keyword(Mtg.Keyword.FLYING))
	assert_true(moth.cur_shroud)
	var growth := give_hand(0, "Giant Growth")
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.cast_spell(0, growth, [TargetRef.card(moth)]))


# --- Treefolk Seedlings -----------------------------------------------------

func test_treefolk_seedlings_toughness_counts_your_forests_everywhere() -> void:
	var seedlings := give_hand(0, "Treefolk Seedlings")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	put_battlefield(1, "Forest")
	g.recalculate()
	assert_eq([seedlings.cur_power, seedlings.cur_toughness], [2, 2], "the CDA works in the hand (CR 604.3)")
	fund(0, seedlings)
	assert_ok(g.cast_spell(0, seedlings))
	resolve_stack()
	assert_eq(seedlings.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq([seedlings.cur_power, seedlings.cur_toughness], [2, 2])
	var third := put_battlefield(0, "Forest")
	assert_eq(seedlings.cur_toughness, 3)
	g.destroy(third)
	assert_eq(seedlings.cur_toughness, 2)

func test_treefolk_seedlings_without_forests_dies() -> void:
	var seedlings := give_hand(0, "Treefolk Seedlings")
	put_battlefield(1, "Forest")
	fund(0, seedlings)
	assert_ok(g.cast_spell(0, seedlings))
	resolve_stack()
	assert_eq(seedlings.zone, Mtg.Zone.GRAVEYARD, "a 2/0")


# --- Treetop Rangers --------------------------------------------------------

func test_treetop_rangers_are_blocked_only_by_flyers() -> void:
	var rangers := put_battlefield(0, "Treetop Rangers")
	var spider := put_battlefield(1, "Giant Spider")
	var bear := put_battlefield(1, "Grizzly Bears")
	var angel := put_battlefield(1, "Serra Angel")
	_attack(rangers)
	assert_refused(g.declare_blockers(1, {spider.id: rangers.id}), "flying")
	assert_refused(g.declare_blockers(1, {bear.id: rangers.id}))
	assert_ok(g.declare_blockers(1, {angel.id: rangers.id}))
