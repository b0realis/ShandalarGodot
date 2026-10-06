extends GameTest
## Pack 9 (the Tempest block), batch B1: the Tempest shadow cards of
## cards/sets/tmp/_shadow.gd, one clause at a time — the grants and the
## loss (Shadow Rift, Dauthi Embrace, Soltari Emissary, Reality Anchor),
## the readers of "a creature with shadow" (Shadowstorm, Circle of
## Protection: Shadow, Maze of Shadows, Phyrexian Splicer, Dauthi Ghoul's
## last known keywords), the shades' own abilities, and the 1997
## damage-prevention window for the two damage cards. The blocking matrix
## of every body is tests/cards/test_pack_9_B1_matrix.gd.


## FIFO answers; an empty queue falls back to the caller's hint (the
## default seat's behaviour). [member window] opts into the 1997 window.
class Scripted extends DecisionAgent:
	var answers: Array = []   # bool
	var options: Array = []   # int
	var picks: Array = []     # CardInstance
	var seen: Array = []      # the candidates of the last card question
	var window := false

	func wants_damage_prevention_window() -> bool:
		return window

	func answer_yes_no(_g: MtgGame, _p: int, _prompt: String, hint: bool) -> bool:
		return bool(answers.pop_front()) if not answers.is_empty() else hint

	func answer_option(_g: MtgGame, _p: int, _prompt: String, _labels: Array[String], hint: int) -> int:
		return int(options.pop_front()) if not options.is_empty() else hint

	func answer_card(_g: MtgGame, _p: int, candidates: Array[CardInstance], _prompt: String) -> CardInstance:
		seen = candidates.duplicate()
		if not picks.is_empty():
			var want: CardInstance = picks.pop_front()
			if candidates.has(want):
				return want
		return null if candidates.is_empty() else candidates[0]


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


## Exactly the mana [param card]'s cost asks for.
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


## The active player attacks with [param attackers]; the other seat is to
## declare blockers.
func _to_blockers(attackers: Array) -> void:
	var ids: Array = []
	for a in attackers: ids.append(a.id)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(g.active_player, ids))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_true(g.awaiting_blockers)


## Give [param pid] priority now (the other seat passes).
func _priority_to(pid: int) -> void:
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.priority_player, pid)


func _close_window() -> void:
	var guard := 0
	while (g.awaiting_damage_prevention or g.awaiting_regeneration or not g.stack.is_empty()) \
			and guard < 20:
		if g.stack.is_empty():
			assert_ok(g.end_damage_prevention(g.priority_player))
		else:
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_lt(guard, 20)


# --- Shadow Rift / Dauthi Embrace / Soltari Emissary: granted shadow ----------

func test_shadow_rift_grants_shadow_until_end_of_turn_and_draws() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var sentry := put_battlefield(1, "Thalakos Sentry")
	var hand := g.players[0].hand.size()
	cast("Shadow Rift", [TargetRef.card(bears)])
	assert_true(bears.has_keyword(Mtg.Keyword.SHADOW))
	assert_eq(g.players[0].hand.size(), hand + 1, "draw a card")
	assert_string_contains(_why(giant, bears), "shadow", "now only a shade blocks it")
	assert_eq(_why(sentry, bears), "")
	advance_to_next_turn()
	assert_false(bears.has_keyword(Mtg.Keyword.SHADOW), "until end of turn")


func test_shadow_rift_fizzles_whole_when_its_target_is_gone() -> void:
	var bears := put_battlefield(1, "Grizzly Bears")
	var rift := give_hand(0, "Shadow Rift")
	fund(0, rift)
	assert_ok(g.cast_spell(0, rift, [TargetRef.card(bears)]))
	g.destroy(bears)
	var hand := g.players[0].hand.size()
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand, "no draw: the only target is illegal (CR 608.2b)")


## A shadow gained after blockers are declared changes nothing (CR 506.4).
func test_shadow_granted_after_blocks_does_not_undo_the_block() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	_to_blockers([bears])
	assert_ok(g.declare_blockers(1, {giant.id: bears.id}))
	cast("Shadow Rift", [TargetRef.card(bears)])
	assert_true(bears.has_keyword(Mtg.Keyword.SHADOW))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "still blocked by the Giant")
	assert_eq(g.players[1].life, 20)


func test_dauthi_embrace_gives_any_creature_shadow_for_bb() -> void:
	var embrace := put_battlefield(0, "Dauthi Embrace")
	var bears := put_battlefield(1, "Grizzly Bears")
	var raiders := put_battlefield(0, "Mons's Goblin Raiders")
	add_mana(0, Mtg.ManaColor.B)
	assert_refused(g.activate_ability(0, embrace, 0, [TargetRef.card(bears)]), "mana")
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, embrace, 0, [TargetRef.card(bears)]))
	resolve_stack()
	assert_true(bears.has_keyword(Mtg.Keyword.SHADOW), "an opponent's creature too")
	assert_string_contains(_why(bears, raiders), "shadow", "and now it can block only shades")
	advance_to_next_turn()
	assert_false(bears.has_keyword(Mtg.Keyword.SHADOW))


func test_soltari_emissary_buys_its_own_shadow() -> void:
	var emissary := put_battlefield(0, "Soltari Emissary")
	var bears := put_battlefield(1, "Grizzly Bears")
	assert_eq(_why(bears, emissary), "", "no shadow of its own")
	assert_refused(g.activate_ability(0, emissary, 0), "mana")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.activate_ability(0, emissary, 0))
	resolve_stack()
	assert_true(emissary.has_keyword(Mtg.Keyword.SHADOW))
	assert_string_contains(_why(bears, emissary), "shadow")
	var e: EffectBase = CardRegistry.get_card("Soltari Emissary").activated_abilities[0].effects[0]
	assert_eq(e.ai_role, &"self_keyword")
	assert_eq(int(e.ai_parameters.keyword), Mtg.Keyword.SHADOW)
	advance_to_next_turn()
	assert_false(emissary.has_keyword(Mtg.Keyword.SHADOW))


# --- Reality Anchor: lost shadow ----------------------------------------------

func test_reality_anchor_strips_shadow_and_draws() -> void:
	var foot := put_battlefield(1, "Soltari Foot Soldier")
	var bears := put_battlefield(0, "Grizzly Bears")
	var hand := g.players[0].hand.size()
	cast("Reality Anchor", [TargetRef.card(foot)])
	assert_false(foot.has_keyword(Mtg.Keyword.SHADOW))
	assert_eq(g.players[0].hand.size(), hand + 1)
	assert_eq(_why(bears, foot), "", "an ordinary creature now")
	advance_to_next_turn()
	assert_true(foot.has_keyword(Mtg.Keyword.SHADOW), "until end of turn")


func test_reality_anchor_targets_a_creature_only() -> void:
	var anchor := give_hand(0, "Reality Anchor")
	fund(0, anchor)
	assert_refused(g.cast_spell(0, anchor, [TargetRef.player(1)]))
	var land := put_battlefield(1, "Forest")
	assert_refused(g.cast_spell(0, anchor, [TargetRef.card(land)]))


## Layer 6 in timestamp order: a later grant beats the earlier loss.
func test_a_later_shadow_rift_beats_an_earlier_reality_anchor() -> void:
	var foot := put_battlefield(0, "Soltari Foot Soldier")
	cast("Reality Anchor", [TargetRef.card(foot)])
	assert_false(foot.has_keyword(Mtg.Keyword.SHADOW))
	cast("Shadow Rift", [TargetRef.card(foot)])
	assert_true(foot.has_keyword(Mtg.Keyword.SHADOW))


# --- Shadowstorm ------------------------------------------------------------

func test_shadowstorm_hits_each_creature_with_shadow_and_nothing_else() -> void:
	var marauder := put_battlefield(1, "Dauthi Marauder")
	var sentry := put_battlefield(0, "Thalakos Sentry")
	var bears := put_battlefield(1, "Grizzly Bears")
	var rifted := put_battlefield(1, "Grizzly Bears")
	var wall := put_battlefield(0, "Wall of Diffusion")
	var anchored := put_battlefield(1, "Soltari Foot Soldier")
	cast("Shadow Rift", [TargetRef.card(rifted)])
	cast("Reality Anchor", [TargetRef.card(anchored)])
	cast("Shadowstorm")
	assert_eq(marauder.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(sentry.zone, Mtg.Zone.GRAVEYARD, "its own controller's shades too")
	assert_eq(rifted.zone, Mtg.Zone.GRAVEYARD, "granted shadow counts")
	assert_eq(bears.damage, 0)
	assert_eq(wall.damage, 0, "blocking as though it had shadow is not having it")
	assert_eq(anchored.zone, Mtg.Zone.BATTLEFIELD, "lost shadow does not count")
	assert_eq(g.players[1].life, 20, "creatures only")


# --- Circle of Protection: Shadow ---------------------------------------------

## Their turn: a shade and a bear attack P0; the Circle may name only the
## shade, and stops exactly its damage.
func test_circle_of_protection_shadow_names_only_a_creature_with_shadow() -> void:
	var p0 := seat(0)
	var circle := put_battlefield(0, "Circle of Protection: Shadow")
	advance_to_next_turn()
	var marauder := put_battlefield(1, "Dauthi Marauder")
	var bears := put_battlefield(1, "Grizzly Bears")
	_to_blockers([marauder, bears])
	assert_ok(g.declare_blockers(0, {}))
	_priority_to(0)
	assert_refused(g.activate_ability(0, circle, 0), "mana")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, circle, 0))
	resolve_stack()
	assert_eq(p0.seen, [marauder], "a creature with shadow, nothing else")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 18, "the shade's 3 prevented, the bear's 2 dealt")
	var e: EffectBase = CardRegistry.get_card("Circle of Protection: Shadow").activated_abilities[0].effects[0]
	assert_true(e.is_damage_prevention, "legal in the 1997 window")


## With no shade in sight there is nothing to name: the shield is wasted.
func test_circle_of_protection_shadow_with_no_shade_shields_nothing() -> void:
	var circle := put_battlefield(0, "Circle of Protection: Shadow")
	advance_to_next_turn()
	var bears := put_battlefield(1, "Grizzly Bears")
	_to_blockers([bears])
	assert_ok(g.declare_blockers(0, {}))
	_priority_to(0)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, circle, 0))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 18)


## The 1997 preset: the damage waits in the window and the Circle takes the
## shade's packet — and only a shade's packet.
func test_circle_of_protection_shadow_in_the_1997_window() -> void:
	g.rules.set_edition("fifth")
	var p0 := seat(0)
	p0.window = true
	var circle := put_battlefield(0, "Circle of Protection: Shadow")
	advance_to_next_turn()
	var marauder := put_battlefield(1, "Dauthi Marauder")
	var bears := put_battlefield(1, "Grizzly Bears")
	_to_blockers([marauder, bears])
	assert_ok(g.declare_blockers(0, {}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_prevention, "the window is open")
	assert_eq(g.players[0].life, 20, "the damage is waiting")
	_priority_to(0)
	var shade_packet: DamagePacket = null
	var bear_packet: DamagePacket = null
	for packet in g.damage_pending:
		if packet.source == marauder: shade_packet = packet
		if packet.source == bears: bear_packet = packet
	assert_not_null(shade_packet)
	assert_not_null(bear_packet)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.activate_ability(0, circle, 0, [TargetRef.damage(bear_packet)]))
	assert_ok(g.activate_ability(0, circle, 0, [TargetRef.damage(shade_packet)]))
	_close_window()
	assert_eq(g.players[0].life, 18)


# --- Phyrexian Splicer --------------------------------------------------------

func test_phyrexian_splicer_moves_each_of_its_four_abilities() -> void:
	var splicer := put_battlefield(0, "Phyrexian Splicer")
	var rows := [[Mtg.Keyword.FLYING, "Air Elemental"], [Mtg.Keyword.FIRST_STRIKE, "White Knight"],
		[Mtg.Keyword.TRAMPLE, "War Mammoth"], [Mtg.Keyword.SHADOW, "Dauthi Marauder"]]
	assert_eq(splicer.cur_activated_abilities.size(), 4, "one row per choice (CR 602.2b)")
	for index in rows.size():
		var keyword: int = rows[index][0]
		var donor := put_battlefield(1, String(rows[index][1]))
		var taker := put_battlefield(0, "Grizzly Bears")
		assert_true(donor.has_keyword(keyword))
		add_mana(0, Mtg.ManaColor.C, 2)
		assert_ok(g.activate_ability(0, splicer, index, [TargetRef.card(donor), TargetRef.card(taker)]))
		assert_true(splicer.tapped)
		resolve_stack()
		assert_false(donor.has_keyword(keyword), "%s: lost" % donor.data.card_name)
		assert_true(taker.has_keyword(keyword), "%s: gained" % donor.data.card_name)
		advance_to_next_turn()
		assert_true(donor.has_keyword(keyword), "until end of turn")
		assert_false(taker.has_keyword(keyword))
		advance_to_next_turn()


func test_phyrexian_splicer_needs_the_ability_on_the_first_and_two_creatures() -> void:
	var splicer := put_battlefield(0, "Phyrexian Splicer")
	var angel := put_battlefield(1, "Serra Angel")
	var bears := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, splicer, 0, [TargetRef.card(bears), TargetRef.card(angel)]))
	assert_refused(g.activate_ability(0, splicer, 0, [TargetRef.card(angel), TargetRef.card(angel)]))
	# The shadow row: the Angel has no shadow to give.
	assert_refused(g.activate_ability(0, splicer, 3, [TargetRef.card(angel), TargetRef.card(bears)]), "abilities")
	assert_false(splicer.tapped, "nothing was paid")
	assert_ok(g.activate_ability(0, splicer, 0, [TargetRef.card(angel), TargetRef.card(bears)]))


## Each half is judged on its own (CR 608.2b): the first creature lost
## shadow in response (Reality Anchor), the second still gains it.
func test_phyrexian_splicer_gives_even_when_the_first_target_became_illegal() -> void:
	var splicer := put_battlefield(0, "Phyrexian Splicer")
	var foot := put_battlefield(1, "Soltari Foot Soldier")
	var bears := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, splicer, 3, [TargetRef.card(foot), TargetRef.card(bears)]))
	cast("Reality Anchor", [TargetRef.card(foot)], 1)
	assert_false(foot.has_keyword(Mtg.Keyword.SHADOW))
	assert_true(bears.has_keyword(Mtg.Keyword.SHADOW))


# --- Maze of Shadows ----------------------------------------------------------

func test_maze_of_shadows_taps_for_colorless() -> void:
	var maze := put_battlefield(0, "Maze of Shadows")
	assert_ok(g.tap_for_mana(0, maze))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 1)


func test_maze_of_shadows_calls_off_an_attacking_shade_only() -> void:
	var maze := put_battlefield(1, "Maze of Shadows")
	var marauder := put_battlefield(0, "Dauthi Marauder")
	var bears := put_battlefield(0, "Grizzly Bears")
	var idle := put_battlefield(0, "Soltari Foot Soldier")
	_to_blockers([marauder, bears])
	assert_ok(g.declare_blockers(1, {}))
	_priority_to(1)
	# Index 0: the mana ability is a row of its own (cur_mana_abilities).
	assert_refused(g.activate_ability(1, maze, 0, [TargetRef.card(bears)]))
	assert_refused(g.activate_ability(1, maze, 0, [TargetRef.card(idle)]))
	assert_ok(g.activate_ability(1, maze, 0, [TargetRef.card(marauder)]))
	resolve_stack()
	assert_false(marauder.tapped, "untapped")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 18, "only the bear's 2")
	assert_eq(CardRegistry.get_card("Maze of Shadows").activated_abilities[0].effects[0].ai_role, &"fog_attacker")


# --- Dauthi Ghoul ------------------------------------------------------------

func test_dauthi_ghoul_grows_on_each_shade_that_dies() -> void:
	var ghoul := put_battlefield(0, "Dauthi Ghoul")
	var foot := put_battlefield(1, "Soltari Foot Soldier")
	var bears := put_battlefield(1, "Grizzly Bears")
	cast("Lightning Bolt", [TargetRef.card(foot)])
	assert_eq(int(ghoul.counters.get("+1/+1", 0)), 1, "a creature with shadow died")
	cast("Lightning Bolt", [TargetRef.card(bears)])
	assert_eq(int(ghoul.counters.get("+1/+1", 0)), 1, "a bear is no shade")
	assert_eq([ghoul.cur_power, ghoul.cur_toughness], [2, 2])


## Last known information (CR 608.2h): granted shadow counts as it dies,
## lost shadow does not.
func test_dauthi_ghoul_reads_the_dead_creatures_last_keywords() -> void:
	var ghoul := put_battlefield(0, "Dauthi Ghoul")
	var rifted := put_battlefield(1, "Grizzly Bears")
	var anchored := put_battlefield(1, "Thalakos Sentry")
	cast("Shadow Rift", [TargetRef.card(rifted)])
	cast("Reality Anchor", [TargetRef.card(anchored)])
	cast("Lightning Bolt", [TargetRef.card(rifted)])
	assert_eq(int(ghoul.counters.get("+1/+1", 0)), 1)
	cast("Lightning Bolt", [TargetRef.card(anchored)])
	assert_eq(int(ghoul.counters.get("+1/+1", 0)), 1, "it had lost shadow")


# --- Dauthi Horror ------------------------------------------------------------

func test_dauthi_horror_cannot_be_blocked_by_a_white_shade() -> void:
	var horror := put_battlefield(0, "Dauthi Horror")
	var foot := put_battlefield(1, "Soltari Foot Soldier")
	var sentry := put_battlefield(1, "Thalakos Sentry")
	assert_string_contains(_why(foot, horror), "nonwhite")
	assert_eq(_why(sentry, horror), "")
	_to_blockers([horror])
	assert_refused(g.declare_blockers(1, {foot.id: horror.id}))
	assert_ok(g.declare_blockers(1, {sentry.id: horror.id}))


# --- Dauthi Mercenary / Soltari Crusader --------------------------------------

func test_dauthi_mercenary_and_soltari_crusader_pump_power() -> void:
	var merc := put_battlefield(0, "Dauthi Mercenary")
	var crusader := put_battlefield(0, "Soltari Crusader")
	add_mana(0, Mtg.ManaColor.B)
	assert_refused(g.activate_ability(0, merc, 0), "mana")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, merc, 0))
	resolve_stack()
	assert_eq([merc.cur_power, merc.cur_toughness], [3, 1])
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, crusader, 0), "mana")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.activate_ability(0, crusader, 0))
	resolve_stack()
	assert_eq([crusader.cur_power, crusader.cur_toughness], [3, 1])
	advance_to_next_turn()
	assert_eq(merc.cur_power, 2)


# --- Dauthi Mindripper -------------------------------------------------------

func _hand(pid: int, count: int) -> void:
	for i in count:
		give_hand(pid, "Forest")


func test_dauthi_mindripper_trades_itself_for_three_cards() -> void:
	var ripper := put_battlefield(0, "Dauthi Mindripper")
	_hand(1, 4)
	_to_blockers([ripper])
	assert_ok(g.declare_blockers(1, {}))
	resolve_stack()
	assert_eq(ripper.zone, Mtg.Zone.GRAVEYARD, "sacrificed")
	assert_eq(g.players[1].hand.size(), 1, "three discarded")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20, "no longer there to deal damage")


func test_dauthi_mindripper_may_decline_and_needs_to_be_unblocked() -> void:
	var p0 := seat(0)
	p0.answers = [false]
	var ripper := put_battlefield(0, "Dauthi Mindripper")
	_hand(1, 4)
	_to_blockers([ripper])
	assert_ok(g.declare_blockers(1, {}))
	resolve_stack()
	assert_eq(ripper.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[1].hand.size(), 4)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 18)
	advance_to_next_turn()
	advance_to_next_turn()
	var sentry := put_battlefield(1, "Thalakos Sentry")
	var hand := g.players[1].hand.size()
	_to_blockers([ripper])
	assert_ok(g.declare_blockers(1, {sentry.id: ripper.id}))
	assert_true(g.stack.is_empty(), "blocked: no trigger")
	resolve_stack()
	assert_eq(g.players[1].hand.size(), hand)
	assert_eq(ripper.zone, Mtg.Zone.BATTLEFIELD)


# --- Dauthi Slayer -----------------------------------------------------------

func test_dauthi_slayer_attacks_each_combat_if_able() -> void:
	var slayer := put_battlefield(0, "Dauthi Slayer")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, []))
	assert_ok(g.declare_attackers(0, [slayer.id]))


# --- Heartwood Dryad / Wall of Diffusion --------------------------------------

func test_heartwood_dryad_blocks_a_shade_and_a_bear() -> void:
	var dryad := put_battlefield(1, "Heartwood Dryad")
	var foot := put_battlefield(0, "Soltari Foot Soldier")
	var bears := put_battlefield(0, "Grizzly Bears")
	assert_eq(_why(dryad, bears), "")
	_to_blockers([foot, bears])
	assert_ok(g.declare_blockers(1, {dryad.id: foot.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(foot.zone, Mtg.Zone.GRAVEYARD)
	assert_false(dryad.has_keyword(Mtg.Keyword.SHADOW), "it does not have shadow")


func test_wall_of_diffusion_blocks_shades_and_cannot_attack() -> void:
	var wall := put_battlefield(0, "Wall of Diffusion")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [wall.id]))
	assert_ok(g.declare_attackers(0, []))
	advance_to_next_turn()
	var lancer := put_battlefield(1, "Soltari Lancer")
	_to_blockers([lancer])
	assert_ok(g.declare_blockers(0, {wall.id: lancer.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 20)


# --- Soltari Guerrillas ------------------------------------------------------

func test_soltari_guerrillas_turn_their_combat_damage_on_a_creature() -> void:
	var guerrillas := put_battlefield(0, "Soltari Guerrillas")
	var giant := put_battlefield(1, "Hill Giant")
	assert_refused(g.activate_ability(0, guerrillas, 0, [TargetRef.player(1)]))
	assert_ok(g.activate_ability(0, guerrillas, 0, [TargetRef.card(giant)]))
	resolve_stack()
	_to_blockers([guerrillas])
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20, "the 3 went to the Giant instead")
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	var e: EffectBase = CardRegistry.get_card("Soltari Guerrillas").activated_abilities[0].effects[0]
	assert_true(e.is_damage_prevention, "a redirection: the 1997 window's family")


func test_soltari_guerrillas_redirect_waits_for_damage_to_an_opponent() -> void:
	var guerrillas := put_battlefield(0, "Soltari Guerrillas")
	var giant := put_battlefield(1, "Hill Giant")
	var sentry := put_battlefield(1, "Thalakos Sentry")
	assert_ok(g.activate_ability(0, guerrillas, 0, [TargetRef.card(giant)]))
	resolve_stack()
	_to_blockers([guerrillas])
	assert_ok(g.declare_blockers(1, {sentry.id: guerrillas.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(sentry.zone, Mtg.Zone.GRAVEYARD, "the blocker took the damage")
	assert_eq(giant.damage, 0, "nothing was dealt to the opponent, nothing redirected")


func test_soltari_guerrillas_in_the_1997_window() -> void:
	g.rules.set_edition("fifth")
	var p1 := seat(1)
	p1.window = true
	var guerrillas := put_battlefield(0, "Soltari Guerrillas")
	var giant := put_battlefield(1, "Hill Giant")
	_to_blockers([guerrillas])
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_prevention)
	_priority_to(0)
	assert_ok(g.activate_ability(0, guerrillas, 0, [TargetRef.card(giant)]))
	_close_window()
	assert_eq(g.players[1].life, 20)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)


# --- Soltari Lancer / Trooper -------------------------------------------------

func test_soltari_lancer_has_first_strike_only_while_attacking() -> void:
	var lancer := put_battlefield(0, "Soltari Lancer")
	var slayer := put_battlefield(1, "Dauthi Slayer")
	assert_false(lancer.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	_to_blockers([lancer])
	assert_true(lancer.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_ok(g.declare_blockers(1, {slayer.id: lancer.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(slayer.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(lancer.zone, Mtg.Zone.BATTLEFIELD, "struck first")
	advance_to_next_turn()
	assert_false(lancer.has_keyword(Mtg.Keyword.FIRST_STRIKE))


func test_soltari_trooper_grows_when_it_attacks() -> void:
	var trooper := put_battlefield(0, "Soltari Trooper")
	_to_blockers([trooper])
	assert_eq([trooper.cur_power, trooper.cur_toughness], [2, 2])
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 18)
	advance_to_next_turn()
	assert_eq([trooper.cur_power, trooper.cur_toughness], [1, 1])


# --- Soltari Monk / Priest ----------------------------------------------------

func test_soltari_monk_and_priest_keep_their_protection() -> void:
	var monk := put_battlefield(1, "Soltari Monk")
	var priest := put_battlefield(1, "Soltari Priest")
	var terror := give_hand(0, "Terror")
	fund(0, terror)
	assert_refused(g.cast_spell(0, terror, [TargetRef.card(monk)]))
	var bolt := give_hand(0, "Lightning Bolt")
	fund(0, bolt)
	assert_refused(g.cast_spell(0, bolt, [TargetRef.card(priest)]))


# --- Thalakos Dreamsower ------------------------------------------------------

func test_thalakos_dreamsower_locks_a_creature_while_it_stays_tapped() -> void:
	var p0 := seat(0)
	var dreamsower := put_battlefield(0, "Thalakos Dreamsower")
	var giant := put_battlefield(1, "Hill Giant")
	_to_blockers([dreamsower])
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(g.players[1].life, 19)
	assert_true(giant.tapped, "tap target creature")
	advance_to_next_turn()   # theirs: the Giant stays tapped
	assert_true(giant.tapped)
	advance_to_next_turn()   # ours: the default keeps the Dreamsower tapped
	assert_true(dreamsower.tapped)
	advance_to_next_turn()
	assert_true(giant.tapped)
	p0.options = [0]         # ours: untap it this time
	advance_to_next_turn()
	assert_false(dreamsower.tapped)
	advance_to_next_turn()
	assert_false(giant.tapped, "the lock ended when the Dreamsower untapped")


func test_thalakos_dreamsower_needs_damage_to_an_opponent() -> void:
	var dreamsower := put_battlefield(0, "Thalakos Dreamsower")
	var giant := put_battlefield(1, "Hill Giant")
	var sentry := put_battlefield(1, "Thalakos Sentry")
	_to_blockers([dreamsower])
	assert_ok(g.declare_blockers(1, {sentry.id: dreamsower.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_false(giant.tapped, "damage to a creature is not damage to an opponent")
	assert_true(CardRegistry.get_card("Thalakos Dreamsower").may_skip_untap)


# --- Thalakos Mistfolk / Seer -------------------------------------------------

func test_thalakos_mistfolk_hides_on_top_of_its_library() -> void:
	var mistfolk := put_battlefield(0, "Thalakos Mistfolk")
	assert_refused(g.activate_ability(0, mistfolk, 0), "mana")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, mistfolk, 0))
	resolve_stack()
	assert_eq(mistfolk.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[0].library.back(), mistfolk, "on top")
	assert_eq(CardRegistry.get_card("Thalakos Mistfolk").activated_abilities[0].effects[0].ai_role, &"self_bounce")


func test_thalakos_seer_draws_when_it_leaves_however_it_leaves() -> void:
	var seer := put_battlefield(0, "Thalakos Seer")
	var hand := g.players[0].hand.size()
	cast("Unsummon", [TargetRef.card(seer)], 1)
	assert_eq(seer.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].hand.size(), hand + 2, "the Seer back and a card drawn")
	var dying := put_battlefield(0, "Thalakos Seer")
	hand = g.players[0].hand.size()
	cast("Lightning Bolt", [TargetRef.card(dying)], 1)
	assert_eq(g.players[0].hand.size(), hand + 1)
	assert_eq(g.players[1].hand.size(), 0, "its controller draws, not the caster")
