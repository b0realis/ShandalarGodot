extends GameTest
## Pack 8 (the Mirage block), batch B6: the Visions and Weatherlight Auras
## (and Parapet) in cards/sets/vis/_auras.gd and cards/sets/wth/_auras.gd.
##
## The four Visions flash-rider cards (Parapet, Relic Ward, Mystic Veil,
## Spider Climb) are driven down BOTH paths: cast with a sorcery's timing
## (kept) and cast at instant speed (sacrificed at the beginning of the next
## cleanup step — after damage wears off, from the stack — CR 514.3a).

const CLAIMED := ["Parapet", "Relic Ward", "Sun Clasp", "Betrayal", "Mystic Veil",
	"Dark Privilege", "Death Watch", "Vampirism", "Mob Mentality", "Mortal Wound",
	"Spider Climb", "Empyrial Armor", "Kithkin Armor", "Abduction", "Apathy",
	"Mana Chains", "Phantom Wings", "Coils of the Medusa", "Betrothed of Fire",
	"Fire Whip", "Briar Shield", "Nature's Kiss"]

## Answers every yes/no with [member yes]; picks the card named [member pick]
## when offered (else the first); remembers prompts.
class Seat extends DecisionAgent:
	var yes := true
	var pick := ""
	var asked: Array[String] = []
	func answer_yes_no(_g: MtgGame, _pid: int, prompt: String, _hint: bool) -> bool:
		asked.append(prompt)
		return yes
	func answer_card(_g: MtgGame, _pid: int, candidates: Array[CardInstance], prompt: String) -> CardInstance:
		asked.append(prompt)
		for c in candidates:
			if c.data.card_name == pick: return c
		return null if candidates.is_empty() else candidates[0]

func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	super()

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)

func _seat(pid: int) -> Seat:
	var s := Seat.new()
	g.set_agent(pid, s)
	return s

func _enchant(pid: int, aura_name: String, host: CardInstance, mana: Array) -> CardInstance:
	var aura := give_hand(pid, aura_name)
	for m in mana: add_mana(pid, int(m))
	assert_ok(g.cast_spell(pid, aura, [TargetRef.card(host)]))
	resolve_stack()
	return aura

func _cast(pid: int, card_name: String, targets: Array, mana: Array) -> CardInstance:
	var card := give_hand(pid, card_name)
	for m in mana: add_mana(pid, int(m))
	assert_ok(g.cast_spell(pid, card, targets))
	return card

func _to_cleanup_priority() -> void:
	var turn := g.turn_number
	var guard := 0
	while not (g.current_step() == Mtg.Step.CLEANUP and not g.stack.is_empty()) \
			and g.turn_number == turn and guard < 200:
		_advance_once()
		guard += 1

func _to_blocks(attackers: Array, blocks: Dictionary) -> void:
	var ids: Array = []
	for a in attackers: ids.append(a.id)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(g.active_player, ids))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	var map := {}
	for b in blocks: map[(b as CardInstance).id] = (blocks[b] as CardInstance).id
	assert_ok(g.declare_blockers(g.opponent_of(g.active_player), map))
	resolve_stack()

func _to_my_next_upkeep(pid := 0) -> void:
	var turn := g.turn_number
	var guard := 0
	while g.turn_number == turn and guard < 400:
		_advance_once()
		guard += 1
	while not (g.active_player == pid and g.current_step() == Mtg.Step.UPKEEP) and guard < 800:
		_advance_once()
		guard += 1
	assert_eq(g.active_player, pid)
	assert_eq(g.current_step(), Mtg.Step.UPKEEP)


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# ------------------------------------------------------------------- Parapet --

func test_parapet_main_phase_cast_is_a_lasting_anthem_for_your_creatures() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	var parapet := _cast(0, "Parapet", [], [Mtg.ManaColor.W, Mtg.ManaColor.W])
	resolve_stack()
	assert_eq(bear.cur_toughness, 3)
	assert_eq(theirs.cur_toughness, 2, "only creatures you control")
	advance_to_next_turn()
	assert_eq(parapet.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.cur_toughness, 3)

func test_parapet_cast_after_blocks_saves_the_creature_then_is_sacrificed() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var blocker := put_battlefield(1, "Grizzly Bears")
	_to_blocks([bear], {blocker: bear})
	var parapet := _cast(0, "Parapet", [], [Mtg.ManaColor.W, Mtg.ManaColor.W])
	assert_true(bool(parapet.memory.get("flash_cast", false)))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "2/3 survives 2 damage")
	assert_eq(blocker.zone, Mtg.Zone.GRAVEYARD)
	_to_cleanup_priority()
	assert_eq(bear.damage, 0)
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(parapet.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


# ---------------------------------------------------------------- Relic Ward --

func test_relic_ward_enchants_only_an_artifact_and_gives_it_shroud() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var ring := put_battlefield(0, "Sol Ring")
	var bear := put_battlefield(0, "Grizzly Bears")
	var ward := give_hand(0, "Relic Ward")
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_refused(g.cast_spell(0, ward, [TargetRef.card(bear)]))
	assert_ok(g.cast_spell(0, ward, [TargetRef.card(ring)]))
	resolve_stack()
	assert_true(ring.cur_shroud)
	assert_eq(ward.zone, Mtg.Zone.BATTLEFIELD, "shroud doesn't shed an Aura already attached")
	advance_to_next_turn()
	assert_eq(ward.zone, Mtg.Zone.BATTLEFIELD, "main-phase cast: kept")
	var shatter := give_hand(1, "Shatter")
	add_mana(1, Mtg.ManaColor.R, 2)
	assert_refused(g.cast_spell(1, shatter, [TargetRef.card(ring)]))

func test_relic_ward_in_response_to_shatter() -> void:
	advance_to_next_turn()   # P1's turn
	var ring := put_battlefield(0, "Sol Ring")
	var shatter := _cast(1, "Shatter", [TargetRef.card(ring)], [Mtg.ManaColor.R, Mtg.ManaColor.R])
	assert_ok(g.pass_priority(1))
	var ward := _cast(0, "Relic Ward", [TargetRef.card(ring)], [Mtg.ManaColor.W, Mtg.ManaColor.W])
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.BATTLEFIELD, "Shatter's target gained shroud: it does nothing")
	assert_eq(shatter.zone, Mtg.Zone.GRAVEYARD)
	advance_to_next_turn()
	assert_eq(ward.zone, Mtg.Zone.GRAVEYARD, "sacrificed at that turn's cleanup step")
	assert_false(ring.cur_shroud)


# ------------------------------------------------------------------ Sun Clasp --

func test_sun_clasp_pumps_and_returns_its_creature_for_white() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(1, "Hill Giant")
	var clasp := _enchant(0, "Sun Clasp", giant, [Mtg.ManaColor.W, Mtg.ManaColor.W])
	assert_eq([giant.cur_power, giant.cur_toughness], [4, 6])
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.activate_ability(0, clasp, 0))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.HAND)
	assert_true(g.players[1].hand.has(giant), "to its OWNER's hand")
	assert_eq(clasp.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------------------- Betrayal --

func test_betrayal_draws_whenever_the_enemy_creature_becomes_tapped() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var mine := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var betrayal := give_hand(0, "Betrayal")
	add_mana(0, Mtg.ManaColor.U)
	assert_refused(g.cast_spell(0, betrayal, [TargetRef.card(mine)]), "")
	assert_ok(g.cast_spell(0, betrayal, [TargetRef.card(giant)]))
	resolve_stack()
	var hand := g.players[0].hand.size()
	advance_to_next_turn()   # P1's turn
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [giant.id]))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 1, "attacking tapped it: the Aura's controller draws")
	assert_eq(g.players[1].hand.size(), 1, "its controller only drew for the turn")

func test_betrayal_falls_off_when_you_gain_control_of_the_creature() -> void:
	# CR 704.5m: "enchant creature an opponent controls" is no longer true.
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(1, "Hill Giant")
	var betrayal := _enchant(0, "Betrayal", giant, [Mtg.ManaColor.U])
	g.change_control(giant, 0)
	g.check_state_based_actions()
	assert_eq(betrayal.zone, Mtg.Zone.GRAVEYARD)


# ---------------------------------------------------------------- Mystic Veil --

func test_mystic_veil_in_response_to_terror_then_gone_at_cleanup() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_next_turn()   # P1's main phase
	var terror := _cast(1, "Terror", [TargetRef.card(bear)], [Mtg.ManaColor.B, Mtg.ManaColor.B])
	assert_ok(g.pass_priority(1))
	var veil := _cast(0, "Mystic Veil", [TargetRef.card(bear)], [Mtg.ManaColor.U, Mtg.ManaColor.U])
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "shroud: Terror's target is illegal")
	assert_eq(terror.zone, Mtg.Zone.GRAVEYARD)
	assert_true(bear.cur_shroud)
	advance_to_next_turn()
	assert_eq(veil.zone, Mtg.Zone.GRAVEYARD)
	assert_false(bear.cur_shroud)

func test_mystic_veil_main_phase_cast_stays() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var veil := _enchant(0, "Mystic Veil", bear, [Mtg.ManaColor.U, Mtg.ManaColor.U])
	advance_to_next_turn()
	assert_eq(veil.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(bear.cur_shroud)


# ------------------------------------------------------------- Dark Privilege --

func test_dark_privilege_sacrifices_a_creature_to_regenerate() -> void:
	var seat := _seat(0)
	seat.pick = "Scathe Zombies"
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var fodder := put_battlefield(0, "Scathe Zombies")
	var privilege := _enchant(0, "Dark Privilege", bear, [Mtg.ManaColor.B, Mtg.ManaColor.B])
	assert_eq([bear.cur_power, bear.cur_toughness], [3, 3])
	assert_ok(g.activate_ability(0, privilege, 0))
	assert_eq(fodder.zone, Mtg.Zone.GRAVEYARD, "the creature is the cost")
	resolve_stack()
	assert_eq(bear.regeneration_shields, 1)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "regenerated")
	assert_true(bear.tapped)

func test_dark_privilege_needs_a_creature_to_sacrifice() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(1, "Hill Giant")
	var privilege := _enchant(0, "Dark Privilege", giant, [Mtg.ManaColor.B, Mtg.ManaColor.B])
	assert_refused(g.activate_ability(0, privilege, 0))


# ----------------------------------------------------------------- Death Watch --

func test_death_watch_drains_by_the_dead_creatures_last_power_and_toughness() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(1, "Hill Giant")
	_enchant(0, "Death Watch", giant, [Mtg.ManaColor.B])
	var growth := _cast(0, "Giant Growth", [TargetRef.card(giant)], [Mtg.ManaColor.G])
	resolve_stack()
	assert_eq(growth.zone, Mtg.Zone.GRAVEYARD)
	g.destroy(giant)
	resolve_stack()
	assert_eq(g.players[1].life, 14, "its controller loses its power (6)")
	assert_eq(g.players[0].life, 26, "you gain its toughness (6)")


# ------------------------------------------------------------------ Vampirism --

func test_vampirism_feeds_on_your_other_creatures() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(0, "Grizzly Bears")
	var unicorn := put_battlefield(0, "Pearled Unicorn")
	var theirs := put_battlefield(1, "Grizzly Bears")
	var hand := g.players[0].hand.size()
	_enchant(0, "Vampirism", giant, [Mtg.ManaColor.B, Mtg.ManaColor.B])
	assert_eq([giant.cur_power, giant.cur_toughness], [5, 5], "+1/+1 for each OTHER creature you control")
	assert_eq([bear.cur_power, bear.cur_toughness], [1, 1])
	assert_eq([unicorn.cur_power, unicorn.cur_toughness], [1, 1])
	assert_eq([theirs.cur_power, theirs.cur_toughness], [2, 2], "only yours")
	g.destroy(bear)
	assert_eq(giant.cur_power, 4)
	advance_to_next_turn()
	assert_eq(g.players[0].hand.size(), hand + 1, "drew at the beginning of the next turn's upkeep")

func test_vampirism_on_an_opponents_creature_still_drains_yours() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var theirs := put_battlefield(1, "Hill Giant")
	var mine := put_battlefield(0, "Merfolk of the Pearl Trident")
	_enchant(0, "Vampirism", theirs, [Mtg.ManaColor.B, Mtg.ManaColor.B])
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD, "a 1/1 of yours dies to -1/-1")
	assert_eq(theirs.cur_power, 3, "and the creature counts YOUR other creatures: none left")


# -------------------------------------------------------------- Mob Mentality --

func test_mob_mentality_pumps_when_every_non_wall_creature_attacks() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	put_battlefield(0, "Wall of Stone")
	_enchant(0, "Mob Mentality", bear, [Mtg.ManaColor.R])
	assert_true(bear.has_keyword(Mtg.Keyword.TRAMPLE))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id, giant.id]))
	resolve_stack()
	assert_eq(bear.cur_power, 4, "+X/+0, X = 2 attacking creatures (the Wall may stay home)")

func test_mob_mentality_needs_all_of_them() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Hill Giant")
	_enchant(0, "Mob Mentality", bear, [Mtg.ManaColor.R])
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	resolve_stack()
	assert_eq(bear.cur_power, 2, "the Giant stayed home: no trigger")


# --------------------------------------------------------------- Mortal Wound --

func test_mortal_wound_destroys_a_creature_dealt_any_damage() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var wurm := put_battlefield(1, "Craw Wurm")
	var wound := _enchant(0, "Mortal Wound", wurm, [Mtg.ManaColor.G])
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.card(wurm)]))
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD, "1 damage, then destroyed")
	assert_eq(wound.zone, Mtg.Zone.GRAVEYARD)

func test_mortal_wound_allows_regeneration() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var troll := put_battlefield(1, "Uthden Troll")
	var wound := _enchant(0, "Mortal Wound", troll, [Mtg.ManaColor.G])
	g._rec(troll, &"regeneration_shields")
	troll.regeneration_shields = 1   # setup: a shield already up
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.card(troll)]))
	resolve_stack()
	assert_eq(troll.zone, Mtg.Zone.BATTLEFIELD, "destroy, not sacrifice: regenerated")
	assert_true(troll.tapped)
	assert_eq(wound.zone, Mtg.Zone.BATTLEFIELD)


# ---------------------------------------------------------------- Spider Climb --

func test_spider_climb_lets_a_creature_block_a_flier_and_then_goes() -> void:
	advance_to_next_turn()   # P1's turn
	var angel := put_battlefield(1, "Serra Angel")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [angel.id]))
	assert_ok(g.pass_priority(1))
	var climb := _cast(0, "Spider Climb", [TargetRef.card(bear)], [Mtg.ManaColor.G])
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.REACH))
	assert_eq(bear.cur_toughness, 5)
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {bear.id: angel.id}))
	advance_to_step(Mtg.Step.END)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "2/5 survives 4 damage")
	advance_to_next_turn()
	assert_eq(climb.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "damage was gone before the sacrifice")

func test_spider_climb_main_phase_cast_stays() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var climb := _enchant(0, "Spider Climb", bear, [Mtg.ManaColor.G])
	advance_to_next_turn()
	assert_eq(climb.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(bear.has_keyword(Mtg.Keyword.REACH))


# -------------------------------------------------------------- Empyrial Armor --

func test_empyrial_armor_counts_its_controllers_hand() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(1, "Hill Giant")
	for n in 3: give_hand(0, "Forest")
	_enchant(0, "Empyrial Armor", giant, [Mtg.ManaColor.W, Mtg.ManaColor.W, Mtg.ManaColor.W])
	var n := g.players[0].hand.size()
	assert_eq(giant.cur_power, 3 + n, "your hand, not the creature's controller's")
	give_hand(0, "Forest")
	g.recalculate()
	assert_eq(giant.cur_power, 4 + n)


# --------------------------------------------------------------- Kithkin Armor --

func test_kithkin_armor_evasion() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var small := put_battlefield(1, "Pearled Unicorn")
	_enchant(0, "Kithkin Armor", bear, [Mtg.ManaColor.W])
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {giant.id: bear.id}))
	assert_ok(g.declare_blockers(1, {small.id: bear.id}))

func test_kithkin_armor_sacrificed_in_response_prevents_the_bolt() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var armor := _enchant(0, "Kithkin Armor", bear, [Mtg.ManaColor.W])
	advance_to_next_turn()   # P1's main phase
	_cast(1, "Lightning Bolt", [TargetRef.card(bear)], [Mtg.ManaColor.R])
	assert_ok(g.pass_priority(1))
	assert_ok(g.activate_ability(0, armor, 0))
	assert_eq(armor.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the cost")
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "the Bolt (the named source) was prevented")
	assert_eq(bear.damage, 0)


# ------------------------------------------------------------------- Abduction --

func test_abduction_untaps_steals_and_sends_the_body_home_on_death() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(1, "Hill Giant")
	g.tap_permanent(giant)
	var abduction := _enchant(0, "Abduction", giant, [Mtg.ManaColor.U, Mtg.ManaColor.U, Mtg.ManaColor.U, Mtg.ManaColor.U])
	assert_eq(giant.controller_id, 0)
	assert_false(giant.tapped, "untapped as the Aura enters")
	var bolt := _cast(0, "Lightning Bolt", [TargetRef.card(giant)], [Mtg.ManaColor.R])
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(abduction.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "returned to the battlefield")
	assert_eq(giant.controller_id, 1, "under its OWNER's control")

func test_abduction_leaving_returns_control() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(1, "Hill Giant")
	var abduction := _enchant(0, "Abduction", giant, [Mtg.ManaColor.U, Mtg.ManaColor.U, Mtg.ManaColor.U, Mtg.ManaColor.U])
	g.destroy(abduction)
	assert_eq(giant.controller_id, 1)


# ---------------------------------------------------------------------- Apathy --

func test_apathy_locks_and_offers_a_random_discard_to_untap() -> void:
	var seat := _seat(1)
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(1, "Hill Giant")
	_enchant(0, "Apathy", giant, [Mtg.ManaColor.U])
	g.tap_permanent(giant)
	seat.yes = false
	_to_my_next_upkeep(1)
	resolve_stack()
	assert_true(giant.tapped, "declined: stays tapped (it didn't untap in the untap step)")
	seat.yes = true
	_to_my_next_upkeep(1)
	var before := g.players[1].hand.size()
	assert_gt(before, 0, "it drew last turn")
	resolve_stack()
	assert_eq(g.players[1].hand.size(), before - 1, "discarded at random")
	assert_false(giant.tapped, "and untapped")


# ----------------------------------------------------------------- Mana Chains --

func test_mana_chains_gives_the_creature_cumulative_upkeep_one() -> void:
	var seat := _seat(1)
	seat.yes = false
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(1, "Hill Giant")
	var chains := _enchant(0, "Mana Chains", giant, [Mtg.ManaColor.U])
	_to_my_next_upkeep(1)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "its controller didn't pay: the creature is sacrificed")
	assert_eq(chains.zone, Mtg.Zone.GRAVEYARD)

func test_mana_chains_paid_adds_an_age_counter_to_the_creature() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(1, "Hill Giant")
	_enchant(0, "Mana Chains", giant, [Mtg.ManaColor.U])
	_to_my_next_upkeep(1)
	add_mana(1, Mtg.ManaColor.C)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(int(giant.counters.get("age", 0)), 1)


# --------------------------------------------------------------- Phantom Wings --

func test_phantom_wings_flies_and_bounces_on_sacrifice() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var wings := _enchant(0, "Phantom Wings", bear, [Mtg.ManaColor.U, Mtg.ManaColor.U])
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))
	assert_ok(g.activate_ability(0, wings, 0))
	assert_eq(wings.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.HAND)


# ---------------------------------------------------------- Coils of the Medusa --

func test_coils_of_the_medusa_destroys_its_non_wall_blockers() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	var unicorn := put_battlefield(1, "Pearled Unicorn")
	var wall := put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.MAIN1)
	var coils := _enchant(0, "Coils of the Medusa", giant, [Mtg.ManaColor.B, Mtg.ManaColor.B])
	assert_eq([giant.cur_power, giant.cur_toughness], [4, 2])
	_to_blocks([giant], {bear: giant, wall: giant})
	assert_ok(g.activate_ability(0, coils, 0))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD, "Walls are spared")
	assert_eq(unicorn.zone, Mtg.Zone.BATTLEFIELD, "not blocking")


# ------------------------------------------------------------ Betrothed of Fire --

func test_betrothed_of_fire_both_sacrifices() -> void:
	var seat := _seat(0)
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var fodder := put_battlefield(0, "Scathe Zombies")
	var other := put_battlefield(0, "Pearled Unicorn")
	var betrothed := _enchant(0, "Betrothed of Fire", bear, [Mtg.ManaColor.R, Mtg.ManaColor.R])
	seat.pick = "Scathe Zombies"
	assert_ok(g.activate_ability(0, betrothed, 0))
	assert_eq(fodder.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(bear.cur_power, 4, "+2/+0")
	assert_ok(g.activate_ability(0, betrothed, 1))
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the enchanted creature is the cost")
	resolve_stack()
	assert_eq(other.cur_power, 4, "creatures you control get +2/+0")

func test_betrothed_of_fire_refuses_a_tapped_body_and_an_enemy_host() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(1, "Hill Giant")
	var tapped := put_battlefield(0, "Scathe Zombies")
	g.tap_permanent(tapped)
	var betrothed := _enchant(0, "Betrothed of Fire", giant, [Mtg.ManaColor.R, Mtg.ManaColor.R])
	assert_refused(g.activate_ability(0, betrothed, 0), "")
	assert_refused(g.activate_ability(0, betrothed, 1), "")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "you can't sacrifice what you don't control")


# ----------------------------------------------------------------- Fire Whip --

func test_fire_whip_hands_its_creature_a_ping_and_burns_when_sacrificed() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	var whip := give_hand(0, "Fire Whip")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_refused(g.cast_spell(0, whip, [TargetRef.card(theirs)]), "")
	assert_ok(g.cast_spell(0, whip, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_activated_abilities.size(), 1)
	assert_ok(g.activate_ability(0, bear, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 19, "the creature deals 1")
	assert_true(bear.tapped)
	assert_ok(g.activate_ability(0, whip, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 18, "the sacrificed Aura deals 1")
	assert_eq(bear.cur_activated_abilities.size(), 0)

func test_fire_whip_falls_off_when_the_creature_changes_control() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var whip := _enchant(0, "Fire Whip", bear, [Mtg.ManaColor.R, Mtg.ManaColor.R])
	g.change_control(bear, 1)
	g.check_state_based_actions()
	assert_eq(whip.zone, Mtg.Zone.GRAVEYARD, "enchant creature you control: no longer legal (CR 704.5m)")


# ---------------------------------------------------------------- Briar Shield --

func test_briar_shield_static_and_sacrifice_pump() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var shield := _enchant(0, "Briar Shield", bear, [Mtg.ManaColor.G])
	assert_eq([bear.cur_power, bear.cur_toughness], [3, 3])
	assert_ok(g.activate_ability(0, shield, 0))
	resolve_stack()
	assert_eq([bear.cur_power, bear.cur_toughness], [5, 5], "the static is gone, +3/+3 until end of turn")
	advance_to_next_turn()
	assert_eq([bear.cur_power, bear.cur_toughness], [2, 2])


# ---------------------------------------------------------------- Nature's Kiss --

func test_natures_kiss_exiles_the_top_graveyard_card_per_pump() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var kiss := _enchant(0, "Nature's Kiss", bear, [Mtg.ManaColor.G, Mtg.ManaColor.G])
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.activate_ability(0, kiss, 0), "")
	var bottom := give_hand(0, "Forest")
	g.card_to_graveyard_from_anywhere(bottom)
	var top := give_hand(0, "Island")
	g.card_to_graveyard_from_anywhere(top)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, kiss, 0))
	assert_eq(top.zone, Mtg.Zone.EXILE, "the TOP card, nobody chooses")
	assert_eq(bottom.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq([bear.cur_power, bear.cur_toughness], [3, 3])
