extends GameTest
## Pack 9 (the Tempest block), batch B12: the Exodus one-offs in
## cards/sets/exo/_misc.gd — Cataclysm, Limited Resources, Mind Over Matter,
## Peace of Mind, Recurring Nightmare, Seismic Assault, Song of Serenity,
## Survival of the Fittest, Treasure Trove and Volrath's Dungeon.

const CLAIMED := ["Cataclysm", "Limited Resources", "Mind Over Matter", "Peace of Mind",
	"Recurring Nightmare", "Seismic Assault", "Song of Serenity", "Survival of the Fittest",
	"Treasure Trove", "Volrath's Dungeon"]

## A card ask answered with the first candidate named in [member picks],
## else the default; option asks with [member option] when >= 0.
class Seat extends DecisionAgent:
	var picks: Array[String] = []
	var option := -1
	var asked: Array[String] = []
	func answer_card(g: MtgGame, pid: int, candidates: Array[CardInstance], prompt: String) -> CardInstance:
		asked.append(prompt)
		for wanted in picks:
			for c in candidates:
				if c.data.card_name == wanted: return c
		return super(g, pid, candidates, prompt)
	func answer_option(g: MtgGame, pid: int, prompt: String, options: Array[String], hint: int) -> int:
		asked.append(prompt)
		return option if option >= 0 else super(g, pid, prompt, options, hint)

func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)

func _seat(pid: int) -> Seat:
	var s := Seat.new()
	g.set_agent(pid, s)
	return s

func _count(pid: int, pred: Callable) -> int:
	var n := 0
	for i in g.players[pid].battlefield:
		if pred.call(i): n += 1
	return n

static func _is_land(i: CardInstance) -> bool: return i.is_land()
static func _is_creature(i: CardInstance) -> bool: return i.is_creature()


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# --------------------------------------------------------------- Cataclysm --

func test_cataclysm_leaves_each_player_one_of_each_type() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var thopter := put_battlefield(0, "Ornithopter")
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var crusade := put_battlefield(0, "Crusade")
	var forest := put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Plains")
	var wurm := put_battlefield(1, "Craw Wurm")
	var elf := put_battlefield(1, "Llanowar Elves")
	var their_land := put_battlefield(1, "Island")
	var cata := give_hand(0, "Cataclysm")
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, cata, []))
	resolve_stack()
	# The heuristic keeps the most valuable of each type not already kept.
	assert_eq(thopter.zone, Mtg.Zone.BATTLEFIELD, "the only artifact")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "the best creature not already kept")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(crusade.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD, "one land")
	assert_eq(_count(0, _is_land), 1)
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(elf.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(their_land.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(cata.zone, Mtg.Zone.GRAVEYARD)

func test_cataclysm_lets_a_multi_type_permanent_fill_two_choices() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var seat := _seat(0)
	seat.picks = ["Ornithopter"]
	var thopter := put_battlefield(0, "Ornithopter")
	var bear := put_battlefield(0, "Grizzly Bears")
	var cata := give_hand(0, "Cataclysm")
	add_mana(0, Mtg.ManaColor.W, 4)
	assert_ok(g.cast_spell(0, cata, []))
	resolve_stack()
	assert_eq(seat.asked.size(), 2, "asked for an artifact and a creature; no enchantment or land to choose")
	assert_eq(thopter.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the artifact creature was kept as both")


# ------------------------------------------------------- Limited Resources --

func test_limited_resources_cuts_each_player_to_five_lands() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	for _k in 7: put_battlefield(0, "Plains")
	for _k in 3: put_battlefield(1, "Island")
	var lr := give_hand(0, "Limited Resources")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, lr, []))
	resolve_stack()
	assert_eq(lr.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(_count(0, _is_land), 5)
	assert_eq(_count(1, _is_land), 3, "five or fewer: nothing to sacrifice")

func test_limited_resources_bans_land_drops_at_ten_lands() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Limited Resources")
	resolve_stack()   # its entry trigger, with no land yet to cut
	for _k in 5: put_battlefield(0, "Plains")
	for _k in 4: put_battlefield(1, "Island")
	var land := give_hand(0, "Forest")
	assert_ok(g.play_land(0, land))
	assert_eq(_count(0, _is_land) + _count(1, _is_land), 10)
	advance_to_next_turn()
	var island := give_hand(1, "Island")
	assert_refused(g.play_land(1, island), "")
	assert_eq(island.zone, Mtg.Zone.HAND)


# --------------------------------------------------------- Mind Over Matter --

func test_mind_over_matter_taps_or_untaps_for_a_discard() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var mom := put_battlefield(0, "Mind Over Matter")
	var giant := put_battlefield(1, "Hill Giant")
	var land := put_battlefield(0, "Island")
	g.tap_permanent(land)
	assert_refused(g.activate_ability(0, mom, 0, [TargetRef.card(giant)]), "")
	give_hand(0, "Forest")
	assert_ok(g.activate_ability(0, mom, 0, [TargetRef.card(giant)]))
	resolve_stack()
	assert_true(giant.tapped, "their untapped creature: tapped")
	give_hand(0, "Forest")
	assert_ok(g.activate_ability(0, mom, 0, [TargetRef.card(land)]))
	resolve_stack()
	assert_false(land.tapped, "our tapped land: untapped")
	assert_refused(g.activate_ability(0, mom, 0, [TargetRef.card(mom)]), "")

func test_mind_over_matter_may_leave_the_target_alone() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var seat := _seat(0)
	seat.option = 2
	var mom := put_battlefield(0, "Mind Over Matter")
	var giant := put_battlefield(1, "Hill Giant")
	give_hand(0, "Forest")
	assert_ok(g.activate_ability(0, mom, 0, [TargetRef.card(giant)]))
	resolve_stack()
	assert_false(giant.tapped, "\"you may\": neither")


# ------------------------------------------------------------ Peace of Mind --

func test_peace_of_mind_trades_a_card_for_three_life() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var peace := put_battlefield(0, "Peace of Mind")
	add_mana(0, Mtg.ManaColor.W)
	assert_refused(g.activate_ability(0, peace, 0), "")
	give_hand(0, "Forest")
	assert_ok(g.activate_ability(0, peace, 0))
	resolve_stack()
	assert_eq(g.players[0].life, 23)
	assert_eq(g.players[0].hand.size(), 0)


# ------------------------------------------------------ Recurring Nightmare --

func test_recurring_nightmare_swaps_a_creature_for_one_in_the_graveyard() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var nightmare := put_battlefield(0, "Recurring Nightmare")
	var fodder := put_battlefield(0, "Llanowar Elves")
	var wurm := give_hand(0, "Craw Wurm")
	g.discard_cards(0, [wurm])
	var theirs := give_hand(1, "Hill Giant")
	g.discard_cards(1, [theirs])
	assert_refused(g.activate_ability(0, nightmare, 0, [TargetRef.card(theirs)]), "")
	assert_ok(g.activate_ability(0, nightmare, 0, [TargetRef.card(wurm)]))
	assert_eq(fodder.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the cost")
	assert_eq(nightmare.zone, Mtg.Zone.HAND, "returned to its owner's hand as the cost")
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(wurm.controller_id, 0)

func test_recurring_nightmare_needs_a_creature_and_sorcery_timing() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var nightmare := put_battlefield(0, "Recurring Nightmare")
	var wurm := give_hand(0, "Craw Wurm")
	g.discard_cards(0, [wurm])
	assert_refused(g.activate_ability(0, nightmare, 0, [TargetRef.card(wurm)]), "")
	put_battlefield(0, "Llanowar Elves")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, []))
	assert_refused(g.activate_ability(0, nightmare, 0, [TargetRef.card(wurm)]), "sorcery")
	assert_eq(nightmare.zone, Mtg.Zone.BATTLEFIELD)


# ---------------------------------------------------------- Seismic Assault --

func test_seismic_assault_throws_land_cards_for_two_damage() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var assault := put_battlefield(0, "Seismic Assault")
	var bear := put_battlefield(1, "Grizzly Bears")
	give_hand(0, "Lightning Bolt")
	assert_refused(g.activate_ability(0, assault, 0, [TargetRef.player(1)]), "land")
	var land := give_hand(0, "Mountain")
	assert_ok(g.activate_ability(0, assault, 0, [TargetRef.player(1)]))
	assert_eq(land.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[1].life, 18)
	give_hand(0, "Mountain")
	assert_ok(g.activate_ability(0, assault, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].hand.size(), 1, "the Bolt stayed")


# -------------------------------------------------------- Song of Serenity --

func test_song_of_serenity_grounds_only_enchanted_creatures() -> void:
	put_battlefield(1, "Song of Serenity")
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var blocker := put_battlefield(1, "Gray Ogre")
	advance_to_step(Mtg.Step.MAIN1)
	var strength := give_hand(0, "Holy Strength")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, strength, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.cur_cant_attack)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [bear.id]), "")
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_next_turn()
	var weakness := give_hand(1, "Holy Strength")
	add_mana(1, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(1, weakness, [TargetRef.card(blocker)]))
	resolve_stack()
	assert_eq(blocker.cur_cant_block_filter.is_valid(), true, "an enchanted creature can't block")
	g.destroy(strength)
	g.recalculate()
	assert_false(bear.cur_cant_attack, "no longer enchanted")


# -------------------------------------------------- Survival of the Fittest --

func test_survival_of_the_fittest_discards_a_creature_to_tutor_one() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var survival := put_battlefield(0, "Survival of the Fittest")
	var target := give_hand(0, "Craw Wurm")
	g.put_from_hand_on_top_of_library(target)
	add_mana(0, Mtg.ManaColor.G)
	give_hand(0, "Forest")
	assert_refused(g.activate_ability(0, survival, 0), "creature")
	var fodder := give_hand(0, "Llanowar Elves")
	assert_ok(g.activate_ability(0, survival, 0))
	assert_eq(fodder.zone, Mtg.Zone.GRAVEYARD, "the creature card is the cost")
	resolve_stack()
	assert_eq(target.zone, Mtg.Zone.HAND, "found and put into the hand")
	assert_eq(g.players[0].library.size(), 30, "shuffled; the Wurm left it")


# ----------------------------------------------------------- Treasure Trove --

func test_treasure_trove_draws_for_four() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var trove := put_battlefield(0, "Treasure Trove")
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_refused(g.activate_ability(0, trove, 0), "")
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.activate_ability(0, trove, 0))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 1)


# -------------------------------------------------------- Volrath's Dungeon --

func test_volraths_dungeon_puts_a_card_from_the_target_hand_on_top() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var dungeon := put_battlefield(0, "Volrath's Dungeon")
	var theirs := give_hand(1, "Lightning Bolt")
	give_hand(0, "Forest")
	assert_ok(g.activate_ability(0, dungeon, 1, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 0)
	assert_eq(g.players[1].library.back(), theirs, "on top of their library")
	assert_eq(theirs.zone, Mtg.Zone.LIBRARY)
	advance_to_next_turn()
	assert_ok(g.pass_priority(1))
	give_hand(0, "Forest")
	assert_refused(g.activate_ability(0, dungeon, 1, [TargetRef.player(1)]), "sorcery")

func test_volraths_dungeon_breaks_for_five_life_only_on_your_own_turn() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var dungeon := put_battlefield(0, "Volrath's Dungeon")
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)
	assert_refused(g.activate_ability(1, dungeon, 0), "your turn")
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	assert_ok(g.activate_ability(1, dungeon, 0))
	assert_eq(g.players[1].life, 15, "the 5 life is the cost")
	resolve_stack()
	assert_eq(dungeon.zone, Mtg.Zone.GRAVEYARD)
