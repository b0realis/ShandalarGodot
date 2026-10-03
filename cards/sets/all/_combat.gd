extends RefCounted
const F := preload("res://cards/sets/fem/_rules.gd")
const A := preload("res://cards/sets/ice/_auras.gd")
const B := preload("res://cards/sets/all/_basic.gd")
const T := preload("res://cards/sets/all/_triggers.gd")
const H := preload("res://cards/sets/hml/_combat.gd")
const O := preload("res://cards/sets/hml/_oyster_redirect.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Bestial Fury":
			c.enchants(TargetSpec.creature()).triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, B._slow_draw, "Draw next turn's upkeep.", F._self_enter))
			c.triggered(TriggeredAbility.new(Mtg.EventType.BLOCKERS_DECLARED, _fury, "Blocked enchanted creature gets +4/+0 and trample.", _host_blocked).capturing(_host_context))
		"Gift of the Woods":
			c.enchants(TargetSpec.creature()).triggered(TriggeredAbility.new(Mtg.EventType.BLOCKERS_DECLARED, _gift, "Enchanted creature gets +0/+3 and you gain 1 life.", _host_fighting).capturing(_host_context))
		"Keeper of Tresserhorn", "Swamp Mosquito", "Stromgald Spy", "Lim-Dûl's Paladin":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UNBLOCKED_ATTACKER, _unblocked, "Resolve this creature's unblocked attack effect.", F._self_enter))
			if c.card_name == "Stromgald Spy": c.static_ability(StaticAbility.new(_reveal_hand, "The defending player's hand stays revealed."))
			if c.card_name == "Lim-Dûl's Paladin":
				c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _paladin_upkeep, "May discard a card; otherwise sacrifice this creature and draw a card.", F._your_upkeep))
				c.triggered(TriggeredAbility.new(Mtg.EventType.BLOCKERS_DECLARED, _paladin_blocked, "Gets +6/+3 until end of turn.", _blocked))
		"Kjeldoran Home Guard": c.triggered(TriggeredAbility.new(Mtg.EventType.END_OF_COMBAT, _home_guard, "Put a -0/-1 counter on this creature and create a Deserter.", H._participated))
		"Sworn Defender": c.activated(F._ability("{1}", false, F.Action.new(_defender, "set this creature's power to the other creature's toughness minus 1 and its toughness to that creature's power plus 1", TargetSpec.creature().with_source_filter(_partner), true)))
		"Urza's Engine":
			c.activated(F._ability("{3}", false, PumpEffect.new(0, 0, [Mtg.Keyword.BANDING]).self_buff()))
			c.activated(F._ability("{3}", false, F.Action.new(_band_trample, "attacking creatures banded with this creature gain trample", null, true)))
		"Varchild's Crusader": c.activated(F._ability("", false, F.Action.new(_crusader, "only Walls can block this creature this turn; sacrifice it at the next end step", null, true)))
		"Whip Vine":
			c.with_may_skip_untap().activated(F._ability("", true, F.Action.new(_vine, "tap and lock target flying creature blocked by this creature while this creature remains tapped", TargetSpec.creature("target flying creature blocked by this creature").with_source_filter(_vine_target))))
		"Diseased Vermin":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _infection, "Put an infection counter on this creature.", _hit_player).capturing(_infection_context))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _vermin, "Deal damage equal to infection counters to a previously damaged opponent.", F._your_upkeep).targeting(TargetSpec.opponent().with_player_source_filter(_infected_player)))
		"Gargantuan Gorilla":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _gorilla_upkeep, "Sacrifice a Forest; otherwise this creature deals 7 damage to you and is sacrificed.", F._your_upkeep))
			c.activated(F._ability("", true, F.Action.new(_fight, "this creature and another target creature deal damage equal to their powers to each other", TargetSpec.creature().with_source_filter(_other))))
		"Storm Elemental":
			c.activated(F._ability("{U}", false, TapEffect.new(TargetSpec.creature("target creature with flying", B._flying))).with_library_exile_cost(1))
			c.activated(F._ability("{U}", false, F.Action.new(_snow_pump, "gets +1/+1 if the exiled card was a snow land", null, true)).with_library_exile_cost(1))
		_: return false
	return true

static func _host_blocked(g: MtgGame, s: CardInstance, _e: GameEvent) -> bool:
	var host := A.host(g, s)
	return host != null and _blocked(g, host, _e)
static func _host_fighting(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var host := A.host(g, s)
	return host != null and (_blocked(g, host, e) or F._blocking(g, host))
static func _blocked(g: MtgGame, s: CardInstance, _e: GameEvent) -> bool: return g.combat.attackers.has(s.id) and g.combat.was_blocked(g.combat.band_of(s.id))
static func _host_context(g: MtgGame, s: CardInstance, _e: GameEvent) -> Dictionary:
	var host := A.host(g, s)
	return {"id": host.id, "stamp": host.layer_timestamp, "controller": s.controller_id}
static func _fury(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var host := O._live(g, int(ctx.id), int(ctx.stamp))
	if host != null: g.continuous.add_until_eot_pump(host.id, 4, 0, [Mtg.Keyword.TRAMPLE])
	g.recalculate()
static func _gift(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var host := O._live(g, int(ctx.id), int(ctx.stamp))
	if host != null: g.continuous.add_until_eot_pump(host.id, 0, 3)
	g.adjust_life(int(ctx.controller), 1)
	g.recalculate()
static func _no_damage(_g: MtgGame, s: CardInstance) -> void: s.cur_assigns_no_combat_damage = true
static func _unblocked(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := int(g.trigger_context(s).controller)
	var opponent := 1 - pid
	if s.data.card_name == "Swamp Mosquito":
		g.add_poison(opponent)
		return
	if s.data.card_name == "Stromgald Spy":
		if not g.agents[pid].choose_yes_no(g, pid, "Reveal the defending player's hand instead of assigning combat damage?", not g.players[opponent].hand.is_empty()): return
		# "For as long as it remains on the battlefield" never starts for a
		# phased-out Spy (CR 611.2b, 702.26f).
		if F._same_trigger_source(g, s) and g.is_present(s):
			g._rec(s, &"memory")
			s.memory["all_spy"] = opponent
			# Ends for good if the Spy phases out (CR 702.26f) — the
			# phase marker moves and never matches again.
			s.memory["all_spy_phase"] = s.phase_sequence
	else: g.adjust_life(opponent, -4 if s.data.card_name == "Lim-Dûl's Paladin" else -2)
	if F._same_trigger_source(g, s) and g.is_present(s): g.continuous.add_floating_static(s, StaticAbility.new(_no_damage, "Assigns no combat damage."), ContinuousEffects.Duration.END_OF_TURN, -1, false, s.id)   # CR 702.26e
	g.recalculate()
static func _reveal_hand(g: MtgGame, s: CardInstance) -> void:
	if s.memory.has("all_spy") and s.phase_sequence == int(s.memory.get("all_spy_phase", s.phase_sequence)):
		g.players[int(s.memory.all_spy)].hand_revealed = true
static func _paladin_upkeep(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := int(g.trigger_context(s).controller)
	var pick := g.agents[pid].choose_card(g, pid, g.players[pid].hand, "Discard a card to keep Lim-Dûl's Paladin?", true, true)
	if pick != null and g.players[pid].hand.has(pick): g.discard_cards(pid, [pick])
	else:
		if F._same_trigger_source(g, s) and s.controller_id == pid: g.sacrifice_permanent(s)
		g.draw_cards(pid, 1)
static func _paladin_blocked(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s) and g.is_present(s): g.continuous.add_until_eot_pump(s.id, 6, 3)   # CR 702.26e
	g.recalculate()
static func _home_guard(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s): g.add_counters(s, "-0/-1")
	g.create_token(int(g.trigger_context(s).controller), CardData.new("Deserter", "", Mtg.CardType.CREATURE).pt(0, 1).with_colors(Mtg.ManaColor.W).with_subtypes(["deserter"]))
# Band-wide on both sides (2026-10-03): a creature blocking one band member
# blocks every member (CR 702.22h).
static func _partner(g: MtgGame, s: CardInstance, i: CardInstance) -> bool: return g.combat.blockers_of_band(g.combat.band_of(s.id)).has(i.id) or g.combat.opposing_attackers(s.id).has(i.id)
static func _defender(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	if not B.live_source(g, s) or not g.is_present(s): return   # CR 702.26e
	var other := g.find_instance(t.instance_id)
	g.continuous.add_until_eot_base_pt(s.id, other.cur_toughness - 1, other.cur_power + 1, false, ContinuousEffects.Duration.END_OF_TURN, -1, -1, true)
	g.recalculate()
static func _band_trample(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if not B.live_source(g, s) or not g.combat.attackers.has(s.id): return
	for id in g.combat.band_of(s.id):
		if id != s.id: g.continuous.add_until_eot_keywords(id, [Mtg.Keyword.TRAMPLE])
	g.recalculate()
static func _wall(i: CardInstance) -> bool: return i.has_subtype("wall")
static func _walls_only(_g: MtgGame, s: CardInstance) -> void: s.cur_block_restrictions.append({"desc": "Walls", "filter": _wall})
static func _crusader(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	if not B.live_source(g, s): return
	# Phased out: no restriction (CR 702.26e); the sacrifice is still scheduled.
	if g.is_present(s): g.continuous.add_floating_static(s, StaticAbility.new(_walls_only, "Only Walls may block this creature."), ContinuousEffects.Duration.END_OF_TURN, -1, false, s.id)
	g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _sac_later.bind(s.id, s.layer_timestamp), "Sacrifice this creature."), pid, s)
	g.recalculate()
static func _sac_later(g: MtgGame, s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
	var i := O._live(g, id, stamp)
	if i != null and i.controller_id == g.current_resolution_controller(): g.sacrifice_permanent(i)
static func _vine_target(g: MtgGame, s: CardInstance, i: CardInstance) -> bool: return i.has_keyword(Mtg.Keyword.FLYING) and g.combat.opposing_attackers(s.id).has(i.id)
static func _vine(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	var i := g.find_instance(t.instance_id)
	g.tap_permanent(i)
	if not F._remained_tapped(g, s): return
	g.continuous.add_floating_static(s, StaticAbility.new(O._lock.bind(i.id, i.layer_timestamp, s.layer_timestamp, s.untap_sequence), "Doesn't untap while Whip Vine remains tapped."), ContinuousEffects.Duration.INDEFINITE, -1, false, i.id)
	g.recalculate()
static func _hit_player(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool: return e.data.source == s and e.data.has("to_player") and e.data.packet.is_combat and int(e.data.amount) > 0
static func _infection_context(_g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary: return {"timestamp": s.layer_timestamp, "controller": s.controller_id, "victim": int(e.data.to_player)}
static func _infection(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	g.add_counters(s, "infection")
	g._rec(s, &"memory")
	s.memory["all_infected_%d" % int(g.trigger_context(s).victim)] = true
static func _infected_player(_g: MtgGame, who: int, s: CardInstance) -> bool: return s != null and s.memory.has("all_infected_%d" % who)
static func _vermin(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var counters := s.counters if F._same_trigger_source(g, s) else s.last_counters
	for t in g.current_targets(): g.deal_damage(s, t, int(counters.get("infection", 0)))
static func _other(_g: MtgGame, s: CardInstance, i: CardInstance) -> bool: return i != s
# A Gorilla gone before resolution still deals its damage, with its last
# known power (CR 608.2h) — only the damage back has nowhere to go (Karplusan
# Yeti's Fight, 2026-10-03). One still here but no longer a creature has no
# power at all (CR 208.3).
static func _fight(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	var other := g.find_instance(t.instance_id)
	if other == null: return
	var live := B.live_source(g, s)
	if live and not s.is_creature(): return
	var power := s.cur_power if live else s.last_power
	var other_power := other.cur_power
	g.begin_simultaneous()
	g.deal_damage(s, t, maxi(0, power))
	if live: g.deal_damage(other, TargetRef.card(s), maxi(0, other_power))
	g.end_simultaneous()
static func _gorilla_upkeep(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := int(g.trigger_context(s).controller)
	var forests: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if i.is_land() and i.has_subtype("forest"): forests.append(i)
	var pick := g.agents[pid].choose_card(g, pid, forests, "Sacrifice a Forest to keep Gargantuan Gorilla?", true, true)
	if pick != null and forests.has(pick):
		var snow := (pick.cur_supertypes & Mtg.Supertype.SNOW) != 0
		g.sacrifice_permanent(pick)
		if snow and F._same_trigger_source(g, s) and g.is_present(s): g.continuous.add_until_eot_keywords(s.id, [Mtg.Keyword.TRAMPLE])   # CR 702.26e
	else:
		g.deal_damage(s, TargetRef.player(pid), 7)
		if F._same_trigger_source(g, s) and s.controller_id == pid: g.sacrifice_permanent(s)
	g.recalculate()
static func _snow_pump(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	var cards: Array = g.cost_paid("_library_exiled", [])
	if cards.is_empty() or not B.live_source(g, s) or not g.is_present(s): return   # CR 702.26e
	if (int(cards[0].types) & Mtg.CardType.LAND) != 0 and (int(cards[0].supertypes) & Mtg.Supertype.SNOW) != 0:
		g.continuous.add_until_eot_pump(s.id, 1, 1)
		g.recalculate()
