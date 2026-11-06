extends GameTest
## Pack 10 (the Urza block), batch B9: "untap up to N lands" — the shared
## UntapUpToEffect of cards/sets/usg/_untap.gd and every card built on it
## (Great Whale, Peregrine Drake, Rewind, Time Spiral, Frantic Search,
## Palinchron, Snap, Treachery). The lands are any player's; the chooser is
## asked how many and then which, own lands ranked first; a human seat is
## held on both questions; a spell whose only target is gone untaps nothing.

const CLAIMED := ["Great Whale", "Peregrine Drake", "Rewind", "Time Spiral",
	"Frantic Search", "Palinchron", "Snap", "Treachery"]
const U := preload("res://cards/sets/usg/_untap.gd")


## FIFO answers and a record of every question; an empty queue answers
## with the caller's hint (a card pick with the first candidate).
class Scripted extends DecisionAgent:
	var options: Array = []
	var picks: Array = []
	var asked: Array[String] = []

	func answer_option(_g: MtgGame, _p: int, prompt: String, _labels: Array[String], hint: int) -> int:
		asked.append(prompt)
		return int(options.pop_front()) if not options.is_empty() else hint

	func answer_card(_g: MtgGame, _p: int, candidates: Array[CardInstance], prompt: String) -> CardInstance:
		asked.append(prompt)
		if not picks.is_empty():
			var want: Variant = picks.pop_front()
			for c in candidates:
				if c == want:
					return c
		return null if candidates.is_empty() else candidates[0]


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

## [param n] Islands for [param pid], each tapped for its {U} (into the pool).
func tapped_islands(pid: int, n: int) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for i in n:
		var island := put_battlefield(pid, "Island")
		assert_ok(g.tap_for_mana(pid, island))
		out.append(island)
	return out

func untapped_count(lands: Array[CardInstance]) -> int:
	var n := 0
	for land in lands:
		if not land.tapped: n += 1
	return n


func test_claimed_cards_are_no_longer_pending() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending", card_name)


# --- the shared effect ------------------------------------------------------

func test_the_effect_is_untargeted_and_describes_itself() -> void:
	var e: EffectBase = U.UntapUpToEffect.new(3)
	assert_null(e.target_spec, "\"up to N lands\" targets nothing")
	assert_eq(e.describe(), "untap up to 3 lands")
	assert_true(e.ai_helpful)
	assert_eq(e.ai_role, &"untap_lands")
	assert_eq(int(e.ai_parameters.count), 3)

func test_own_lands_are_offered_first_and_the_richest_first() -> void:
	var island := put_battlefield(0, "Island")
	var academy := put_battlefield(0, "Tolarian Academy")
	put_battlefield(0, "Voltaic Key")
	put_battlefield(0, "Worn Powerstone")
	var theirs := put_battlefield(1, "Forest")
	var untapped := put_battlefield(0, "Island")
	for land in [island, academy, theirs]: land.tapped = true
	var offered: Array[CardInstance] = U.UntapUpToEffect.tapped_lands_for(g, 0)
	assert_eq(offered, [academy, island, theirs] as Array[CardInstance],
		"own lands before theirs, the two-mana Academy before the Island; untapped lands are not offered")
	assert_false(offered.has(untapped))
	assert_eq(U.UntapUpToEffect.tapped_lands_for(g, 1)[0], theirs, "ranked for the chooser")

func test_nothing_tapped_asks_nothing() -> void:
	var p0 := seat(0)
	put_battlefield(0, "Island")
	assert_eq(U.UntapUpToEffect.untap_lands(g, 0, 4, null), 0)
	assert_true(p0.asked.is_empty(), "no tapped land anywhere: no question")


# --- Great Whale -------------------------------------------------------------

func test_great_whale_untaps_the_seven_lands_that_paid_for_it() -> void:
	var islands := tapped_islands(0, 7)
	var whale := give_hand(0, "Great Whale")
	assert_ok(g.cast_spell(0, whale))
	resolve_stack()
	assert_eq(whale.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(untapped_count(islands), 7, "the heuristic untaps every land it may")

func test_great_whale_with_more_tapped_lands_untaps_seven() -> void:
	var islands := tapped_islands(0, 7)
	var spare := put_battlefield(0, "Island")
	spare.tapped = true
	islands.append(spare)
	var whale := give_hand(0, "Great Whale")
	assert_ok(g.cast_spell(0, whale))
	resolve_stack()
	assert_eq(untapped_count(islands), 7, "up to seven, not eight")


# --- Peregrine Drake ----------------------------------------------------------

func test_peregrine_drake_untaps_only_its_controllers_lands_by_default() -> void:
	var mine := tapped_islands(0, 5)
	var theirs := put_battlefield(1, "Island")
	theirs.tapped = true
	var drake := give_hand(0, "Peregrine Drake")
	assert_ok(g.cast_spell(0, drake))
	resolve_stack()
	assert_true(drake.has_keyword(Mtg.Keyword.FLYING))
	assert_eq(untapped_count(mine), 5)
	assert_true(theirs.tapped, "never an opponent's land unless chosen")

func test_peregrine_drake_may_untap_an_opponents_land_and_fewer_than_five() -> void:
	var mine := tapped_islands(0, 5)
	var theirs := put_battlefield(1, "Forest")
	theirs.tapped = true
	var p0 := seat(0)
	p0.options = [2]
	p0.picks = [theirs, mine[3]]
	var drake := give_hand(0, "Peregrine Drake")
	assert_ok(g.cast_spell(0, drake))
	resolve_stack()
	assert_false(theirs.tapped, "any lands: the opponent's is legal (CR 608.2d)")
	assert_false(mine[3].tapped)
	assert_eq(untapped_count(mine), 1, "two lands in all")
	assert_has(p0.asked, "Peregrine Drake: untap how many lands? (up to 5)")
	assert_has(p0.asked, "Peregrine Drake: select a land to untap.")

func test_peregrine_drake_trigger_resolves_after_the_drake_has_left() -> void:
	var mine := tapped_islands(0, 5)
	var drake := give_hand(0, "Peregrine Drake")
	assert_ok(g.cast_spell(0, drake))
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))   # the Drake resolves; its trigger goes on
	assert_eq(drake.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.stack.size(), 1)
	g.return_to_hand(drake)   # gone in response
	resolve_stack()
	assert_eq(untapped_count(mine), 5, "the trigger exists apart from its source (CR 603.6)")


# --- Rewind ------------------------------------------------------------------

func test_rewind_counters_and_untaps_four_lands() -> void:
	var bears := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, bears))
	assert_ok(g.pass_priority(0))
	var islands := tapped_islands(1, 4)
	var rewind := give_hand(1, "Rewind")
	assert_ok(g.cast_spell(1, rewind, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(untapped_count(islands), 4, "Rewind cost nothing in the end")
	assert_eq(rewind.zone, Mtg.Zone.GRAVEYARD)

func test_rewind_whose_spell_is_gone_untaps_nothing() -> void:
	var bears := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, bears))
	assert_ok(g.pass_priority(0))
	var islands := tapped_islands(1, 4)
	var rewind := give_hand(1, "Rewind")
	assert_ok(g.cast_spell(1, rewind, [TargetRef.card(bears)]))
	var counter := give_hand(1, "Counterspell")
	add_mana(1, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(1, counter, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(untapped_count(islands), 0, "its only target illegal, Rewind does nothing (CR 608.2b)")

func test_rewind_needs_a_spell_to_target() -> void:
	var bears := put_battlefield(1, "Grizzly Bears")
	var rewind := give_hand(0, "Rewind")
	add_mana(0, Mtg.ManaColor.U, 4)
	assert_refused(g.cast_spell(0, rewind, [TargetRef.card(bears)]))


# --- Time Spiral ---------------------------------------------------------------

func test_time_spiral_refills_both_hands_untaps_six_and_is_exiled() -> void:
	var islands := tapped_islands(0, 6)
	var spiral := give_hand(0, "Time Spiral")
	give_hand(0, "Grizzly Bears")
	give_hand(1, "Hill Giant")
	give_hand(1, "Lightning Bolt")
	var dead := put_battlefield(1, "Llanowar Elves")
	g.destroy(dead)
	var libraries := [g.players[0].library.size(), g.players[1].library.size()]
	assert_ok(g.cast_spell(0, spiral))
	resolve_stack()
	assert_eq(spiral.zone, Mtg.Zone.EXILE, "\"Exile Time Spiral\"")
	assert_eq(g.players[0].hand.size(), 7)
	assert_eq(g.players[1].hand.size(), 7)
	assert_true(g.players[1].graveyard.is_empty(), "the graveyard was shuffled in")
	assert_eq(g.players[0].library.size(), libraries[0] + 1 - 7)
	assert_eq(g.players[1].library.size(), libraries[1] + 3 - 7)
	assert_eq(untapped_count(islands), 6, "you untap up to six lands")

func test_a_countered_time_spiral_goes_to_the_graveyard() -> void:
	tapped_islands(0, 6)
	var spiral := give_hand(0, "Time Spiral")
	assert_ok(g.cast_spell(0, spiral))
	assert_ok(g.pass_priority(0))
	var counter := give_hand(1, "Counterspell")
	add_mana(1, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(1, counter, [TargetRef.card(spiral)]))
	resolve_stack()
	assert_eq(spiral.zone, Mtg.Zone.GRAVEYARD, "it never resolved, so it was never exiled")


# --- Frantic Search -------------------------------------------------------------

func test_frantic_search_loots_two_and_untaps_three() -> void:
	var islands := tapped_islands(0, 3)
	var search := give_hand(0, "Frantic Search")
	var keep := give_hand(0, "Llanowar Elves")
	var hand_before := g.players[0].hand.size()
	var drawn_before := g.players[0].drawn_this_turn.size()
	assert_ok(g.cast_spell(0, search))
	resolve_stack()
	assert_eq(g.players[0].drawn_this_turn.size(), drawn_before + 2, "draw two")
	assert_eq(g.players[0].hand.size(), hand_before - 1 + 2 - 2, "then discard two")
	assert_eq(g.players[0].graveyard.size(), 3, "two discards and the spell")
	assert_eq(untapped_count(islands), 3, "free in the end")
	assert_true(keep.zone == Mtg.Zone.HAND or keep.zone == Mtg.Zone.GRAVEYARD)

func test_frantic_search_with_one_card_left_discards_what_there_is() -> void:
	tapped_islands(0, 3)
	var search := give_hand(0, "Frantic Search")
	assert_ok(g.cast_spell(0, search))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 0, "drew two, discarded two")


# --- Palinchron ---------------------------------------------------------------

func test_palinchron_untaps_seven_and_returns_to_its_owners_hand() -> void:
	var islands := tapped_islands(0, 7)
	var palinchron := give_hand(0, "Palinchron")
	assert_ok(g.cast_spell(0, palinchron))
	resolve_stack()
	assert_true(palinchron.has_keyword(Mtg.Keyword.FLYING))
	assert_eq(untapped_count(islands), 7)
	for i in 4:
		assert_ok(g.tap_for_mana(0, islands[i]))
	assert_ok(g.activate_ability(0, palinchron, 0))
	resolve_stack()
	assert_eq(palinchron.zone, Mtg.Zone.HAND)
	assert_true(g.players[0].hand.has(palinchron))
	var ability: ActivatedAbility = CardRegistry.get_card("Palinchron").activated_abilities[0]
	assert_eq(ability.effects[0].ai_role, &"self_bounce")

func test_palinchron_stolen_goes_back_to_its_owner() -> void:
	var palinchron := put_battlefield(1, "Palinchron")
	g.change_control(palinchron, 0)
	add_mana(0, Mtg.ManaColor.U, 4)
	assert_ok(g.activate_ability(0, palinchron, 0))
	resolve_stack()
	assert_true(g.players[1].hand.has(palinchron), "its OWNER's hand")


# --- Snap ---------------------------------------------------------------------

func test_snap_bounces_and_untaps_two() -> void:
	var islands := tapped_islands(0, 2)
	var giant := put_battlefield(1, "Hill Giant")
	var snap := give_hand(0, "Snap")
	assert_ok(g.cast_spell(0, snap, [TargetRef.card(giant)]))
	resolve_stack()
	assert_true(g.players[1].hand.has(giant))
	assert_eq(untapped_count(islands), 2)

func test_snap_whose_creature_is_gone_untaps_nothing() -> void:
	var islands := tapped_islands(0, 2)
	var giant := put_battlefield(1, "Hill Giant")
	var snap := give_hand(0, "Snap")
	assert_ok(g.cast_spell(0, snap, [TargetRef.card(giant)]))
	g.destroy(giant)
	resolve_stack()
	assert_eq(untapped_count(islands), 0, "the spell is countered on resolution (CR 608.2b)")

func test_snap_holds_a_human_seat_on_how_many_and_which() -> void:
	var islands := tapped_islands(0, 2)
	var giant := put_battlefield(1, "Hill Giant")
	var snap := give_hand(0, "Snap")
	g.agents[0] = HumanAgent.new()
	g.interactive_choices = true
	assert_ok(g.cast_spell(0, snap, [TargetRef.card(giant)]))
	var guard := 0
	while not g.stack.is_empty() and g.awaiting_choice == null and guard < 20:
		g.pass_priority(g.priority_player)
		guard += 1
	assert_not_null(g.awaiting_choice, "held on the number")
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.OPTION)
	assert_eq(g.awaiting_choice.source, "Snap")
	assert_eq(g.awaiting_choice.prompt, "Snap: untap how many lands? (up to 2)")
	assert_eq(g.awaiting_choice.options, ["0", "1", "2"] as Array[String])
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "nothing has happened yet")
	assert_ok(g.answer_choice(1))
	assert_not_null(g.awaiting_choice, "then on the land")
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.CARD)
	assert_eq(g.awaiting_choice.prompt, "Snap: select a land to untap.")
	assert_ok(g.answer_choice(islands[1].id))
	assert_null(g.awaiting_choice)
	assert_true(g.players[1].hand.has(giant))
	assert_true(islands[0].tapped)
	assert_false(islands[1].tapped, "the land the player named")
	assert_eq(g.unanswered_choices.size(), 0)


# --- Treachery -----------------------------------------------------------------

func test_treachery_steals_and_untaps_five() -> void:
	var islands := tapped_islands(0, 5)
	var giant := put_battlefield(1, "Hill Giant")
	var treachery := give_hand(0, "Treachery")
	assert_ok(g.cast_spell(0, treachery, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(treachery.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(giant.controller_id, 0, "you control enchanted creature")
	assert_eq(untapped_count(islands), 5, "the Aura was free")
	g.destroy(treachery)
	g.check_state_based_actions()
	assert_eq(giant.controller_id, 1, "it goes home with the Aura")

func test_treachery_enchants_only_a_creature() -> void:
	var land := put_battlefield(1, "Forest")
	var treachery := give_hand(0, "Treachery")
	add_mana(0, Mtg.ManaColor.U, 5)
	assert_refused(g.cast_spell(0, treachery, [TargetRef.card(land)]))
