extends GameTest
## Pack 9 (the Tempest block), batch B1: the Stronghold and Exodus shadow
## cards of cards/sets/sth/_shadow.gd and cards/sets/exo/_shadow.gd —
## Dauthi Trapper, Soltari Champion, Thalakos Deceiver, Dauthi Cutthroat,
## Dauthi Jackal, Dauthi Warlord (Pack 9 E5's after-layer-6 CDA), Soltari
## Visionary, Thalakos Drifters and Thalakos Scout. The blocking matrix of
## every body is tests/cards/test_pack_9_B1_matrix.gd.


## FIFO answers; an empty queue falls back to the caller's hint.
class Scripted extends DecisionAgent:
	var answers: Array = []   # bool

	func answer_yes_no(_g: MtgGame, _p: int, _prompt: String, hint: bool) -> bool:
		return bool(answers.pop_front()) if not answers.is_empty() else hint


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
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


func _why(blocker: CardInstance, attacker: CardInstance) -> String:
	return CombatState.block_illegality(g, blocker, attacker, blocker.controller_id)


func _to_blockers(attackers: Array) -> void:
	var ids: Array = []
	for a in attackers: ids.append(a.id)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(g.active_player, ids))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_true(g.awaiting_blockers)


func _priority_to(pid: int) -> void:
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.priority_player, pid)


# --- Dauthi Trapper ----------------------------------------------------------

func test_dauthi_trapper_taps_to_give_shadow() -> void:
	var sick := put_battlefield(0, "Dauthi Trapper", true)
	var trapper := put_battlefield(0, "Dauthi Trapper")
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	assert_refused(g.activate_ability(0, sick, 0, [TargetRef.card(bears)]))
	assert_ok(g.activate_ability(0, trapper, 0, [TargetRef.card(bears)]))
	assert_true(trapper.tapped)
	resolve_stack()
	assert_true(bears.has_keyword(Mtg.Keyword.SHADOW))
	assert_string_contains(_why(giant, bears), "shadow")
	assert_false(trapper.has_keyword(Mtg.Keyword.SHADOW), "the Trapper itself has none")
	advance_to_next_turn()
	assert_false(bears.has_keyword(Mtg.Keyword.SHADOW))


# --- Soltari Champion --------------------------------------------------------

func test_soltari_champion_pumps_the_others_when_it_attacks() -> void:
	var champion := put_battlefield(0, "Soltari Champion")
	var bears := put_battlefield(0, "Grizzly Bears")
	var home := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	_to_blockers([champion, bears])
	assert_eq([champion.cur_power, champion.cur_toughness], [2, 2], "other creatures")
	assert_eq([bears.cur_power, bears.cur_toughness], [3, 3])
	assert_eq([home.cur_power, home.cur_toughness], [3, 3], "attacking or not")
	assert_eq([theirs.cur_power, theirs.cur_toughness], [2, 2], "you control")
	advance_to_next_turn()
	assert_eq(bears.cur_power, 2)


func test_soltari_champion_does_nothing_when_it_stays_home() -> void:
	put_battlefield(0, "Soltari Champion")
	var bears := put_battlefield(0, "Grizzly Bears")
	_to_blockers([bears])
	assert_eq(bears.cur_power, 2)


# --- Thalakos Deceiver -------------------------------------------------------

func test_thalakos_deceiver_trades_itself_for_their_creature() -> void:
	var deceiver := put_battlefield(0, "Thalakos Deceiver")
	var giant := put_battlefield(1, "Hill Giant")
	_to_blockers([deceiver])
	assert_ok(g.declare_blockers(1, {}))
	resolve_stack()
	assert_eq(deceiver.zone, Mtg.Zone.GRAVEYARD, "sacrificed")
	assert_eq(giant.controller_id, 0, "gain control of target creature")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(giant.controller_id, 0, "indefinitely")


func test_thalakos_deceiver_may_decline_and_needs_to_be_unblocked() -> void:
	var p0 := seat(0)
	p0.answers = [false]
	var deceiver := put_battlefield(0, "Thalakos Deceiver")
	var giant := put_battlefield(1, "Hill Giant")
	_to_blockers([deceiver])
	assert_ok(g.declare_blockers(1, {}))
	resolve_stack()
	assert_eq(deceiver.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(giant.controller_id, 1)
	advance_to_next_turn()
	advance_to_next_turn()
	var sentry := put_battlefield(1, "Thalakos Sentry")
	_to_blockers([deceiver])
	assert_ok(g.declare_blockers(1, {sentry.id: deceiver.id}))
	assert_true(g.stack.is_empty(), "blocked: no trigger")
	assert_eq(giant.controller_id, 1)


## The default answer keeps the Deceiver when the best creature in reach
## is no better than its own 1/1 body (a public read of the board).
func test_thalakos_deceiver_default_declines_a_poor_trade() -> void:
	var deceiver := put_battlefield(0, "Thalakos Deceiver")
	var foot := put_battlefield(1, "Soltari Foot Soldier")
	_to_blockers([deceiver])
	assert_ok(g.declare_blockers(1, {}))
	resolve_stack()
	assert_eq(deceiver.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(foot.controller_id, 1)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 19)


# --- Dauthi Cutthroat --------------------------------------------------------

func test_dauthi_cutthroat_destroys_only_a_creature_with_shadow() -> void:
	var cutthroat := put_battlefield(0, "Dauthi Cutthroat")
	var foot := put_battlefield(1, "Soltari Foot Soldier")
	var bears := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.activate_ability(0, cutthroat, 0, [TargetRef.card(bears)]))
	assert_ok(g.activate_ability(0, cutthroat, 0, [TargetRef.card(foot)]))
	resolve_stack()
	assert_eq(foot.zone, Mtg.Zone.GRAVEYARD)
	assert_true(cutthroat.tapped)


func test_dauthi_cutthroat_reads_live_shadow() -> void:
	var cutthroat := put_battlefield(0, "Dauthi Cutthroat")
	var bears := put_battlefield(1, "Grizzly Bears")
	cast("Shadow Rift", [TargetRef.card(bears)])
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, cutthroat, 0, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "granted shadow makes it a legal target")


# --- Dauthi Jackal -----------------------------------------------------------

func test_dauthi_jackal_destroys_a_blocking_creature() -> void:
	var jackal := put_battlefield(0, "Dauthi Jackal")
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_refused(g.activate_ability(0, jackal, 0, [TargetRef.card(giant)]), "blocking")
	_to_blockers([bears])
	assert_ok(g.declare_blockers(1, {giant.id: bears.id}))
	_priority_to(0)
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.activate_ability(0, jackal, 0, [TargetRef.card(giant)]))
	assert_eq(jackal.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the cost")
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[1].life, 20, "a blocked creature stays blocked")


# --- Dauthi Warlord ----------------------------------------------------------

func test_dauthi_warlord_counts_every_creature_with_shadow() -> void:
	var warlord := put_battlefield(0, "Dauthi Warlord")
	assert_eq([warlord.cur_power, warlord.cur_toughness], [1, 1], "itself")
	var foot := put_battlefield(1, "Soltari Foot Soldier")
	put_battlefield(1, "Grizzly Bears")
	g.recalculate()
	assert_eq(warlord.cur_power, 2, "whoever controls it")
	var bears := put_battlefield(0, "Grizzly Bears")
	cast("Shadow Rift", [TargetRef.card(bears)])
	assert_eq(warlord.cur_power, 3, "granted shadow counts (after layer 6, E5)")
	cast("Reality Anchor", [TargetRef.card(foot)])
	assert_eq(warlord.cur_power, 2, "lost shadow does not")
	advance_to_next_turn()
	assert_eq(warlord.cur_power, 2, "the grant and the loss both ended")


func test_dauthi_warlord_in_hand_and_under_a_base_setter() -> void:
	put_battlefield(0, "Soltari Foot Soldier")
	put_battlefield(1, "Thalakos Sentry")
	var held := give_hand(0, "Dauthi Warlord")
	g.recalculate()
	assert_eq(held.cur_power, 2, "a characteristic-defining ability works in every zone (CR 604.3)")
	var warlord := put_battlefield(0, "Dauthi Warlord")
	assert_eq(warlord.cur_power, 3)
	g.destroy(warlord)
	assert_eq(warlord.zone, Mtg.Zone.GRAVEYARD)


# --- Soltari Visionary -------------------------------------------------------

func test_soltari_visionary_destroys_an_enchantment_of_the_damaged_player() -> void:
	var visionary := put_battlefield(0, "Soltari Visionary")
	var moon := put_battlefield(1, "Bad Moon")
	var crusade := put_battlefield(0, "Crusade")
	_to_blockers([visionary])
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(g.players[1].life, 17, "2 + Crusade's 1")
	assert_eq(moon.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(crusade.zone, Mtg.Zone.BATTLEFIELD, "that player's, never its controller's")


func test_soltari_visionary_without_an_enchantment_there_does_nothing() -> void:
	var visionary := put_battlefield(0, "Soltari Visionary")
	var crusade := put_battlefield(0, "Crusade")
	var sentry := put_battlefield(1, "Thalakos Sentry")
	var moon := put_battlefield(1, "Bad Moon")
	_to_blockers([visionary])
	assert_ok(g.declare_blockers(1, {sentry.id: visionary.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(moon.zone, Mtg.Zone.BATTLEFIELD, "damage to a creature is not damage to a player")
	g.destroy(moon)
	advance_to_next_turn()
	advance_to_next_turn()
	_to_blockers([visionary])
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(crusade.zone, Mtg.Zone.BATTLEFIELD, "no enchantment of theirs: the trigger is removed")


# --- Thalakos Drifters / Scout -----------------------------------------------

func test_thalakos_drifters_discards_for_shadow() -> void:
	var drifters := put_battlefield(0, "Thalakos Drifters")
	var bears := put_battlefield(1, "Grizzly Bears")
	assert_refused(g.activate_ability(0, drifters, 0), "discard")
	var spare := give_hand(0, "Forest")
	assert_ok(g.activate_ability(0, drifters, 0))
	assert_eq(spare.zone, Mtg.Zone.GRAVEYARD, "the discard is the cost")
	resolve_stack()
	assert_true(drifters.has_keyword(Mtg.Keyword.SHADOW))
	assert_string_contains(_why(bears, drifters), "shadow")
	var e: EffectBase = CardRegistry.get_card("Thalakos Drifters").activated_abilities[0].effects[0]
	assert_eq(e.ai_role, &"self_keyword")
	advance_to_next_turn()
	assert_false(drifters.has_keyword(Mtg.Keyword.SHADOW))


func test_thalakos_scout_discards_to_go_home() -> void:
	var scout := put_battlefield(0, "Thalakos Scout")
	assert_refused(g.activate_ability(0, scout, 0), "discard")
	var spare := give_hand(0, "Forest")
	assert_ok(g.activate_ability(0, scout, 0))
	assert_eq(spare.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(scout.zone, Mtg.Zone.HAND)
	assert_eq(CardRegistry.get_card("Thalakos Scout").activated_abilities[0].effects[0].ai_role, &"self_bounce")


## In response to a Terror the Scout escapes; the Terror fizzles.
func test_thalakos_scout_answers_removal() -> void:
	var scout := put_battlefield(0, "Thalakos Scout")
	give_hand(0, "Forest")
	_priority_to(1)
	var terror := give_hand(1, "Terror")
	fund(1, terror)
	assert_ok(g.cast_spell(1, terror, [TargetRef.card(scout)]))
	_priority_to(0)
	assert_ok(g.activate_ability(0, scout, 0))
	resolve_stack()
	assert_eq(scout.zone, Mtg.Zone.HAND)
	assert_eq(terror.zone, Mtg.Zone.GRAVEYARD)
