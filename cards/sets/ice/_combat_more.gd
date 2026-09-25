extends RefCounted
const F := preload("res://cards/sets/fem/_rules.gd")
const C := preload("res://cards/sets/ice/_creatures.gd")
const M := preload("res://cards/sets/ice/_more.gd")
const TYPES: Array[String] = ["plains", "island", "swamp", "mountain", "forest"]

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Arcum's Weathervane":
			for snow in [false, true]:
				var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target nonsnow basic land" if snow else "target snow land", _weather_target.bind(snow))
				c.activated(F._ability("{2}", true, F.Action.new(_weather.bind(snow), "change this land's snow supertype permanently", spec, true)))
		"Barbarian Guides":
			c.activated(F._ability("{2}{R}", true, F.Action.new(_guides, "grant snow landwalk and return the creature at the next end step", TargetSpec.creature("target creature you control").with_source_filter(F._own), true)))
		"Norritt", "Arcum's Whistle":
			var whistle := c.card_name == "Arcum's Whistle"
			if not whistle: c.activated(F._ability("", true, UntapEffect.new(TargetSpec.creature("target blue creature", F._color.bind(Mtg.ManaColor.U)))))
			c.activated(F._ability("{3}" if whistle else "", true, F.Action.new(_draft.bind(whistle), "force an eligible creature to attack or be destroyed", TargetSpec.creature("target eligible non-Wall creature").with_source_filter(_draftable))).only_if(_before_attackers))
		"Goblin Sappers":
			for both in [true, false]:
				var a := F._ability("{R}{R}" if both else "{R}{R}{R}{R}", true, M.own_pump(0, 0, [Mtg.Keyword.UNBLOCKABLE]))
				a.effects.append(F.Action.new(_sappers.bind(both), "destroy the affected creatures at end of combat"))
				c.activated(a)
		"Lim-Dûl's Cohort":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BLOCKED, _cohort, "The other creature can't regenerate this turn.", _fought).capturing(_fight_context))
		"Kjeldoran Frostbeast", "Dread Wight":
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_OF_COMBAT, _combat_end.bind(c.card_name == "Dread Wight"), "Affect creatures still blocking or blocked by this creature.", _in_combat).capturing(_combat_context))
		"Márton Stromgald":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, _marton.bind(true), "Other attackers get +1/+1 for each other attacker.", F._self_attack))
			c.triggered(TriggeredAbility.new(Mtg.EventType.BLOCKERS_DECLARED, _marton.bind(false), "Other blockers get +1/+1 for each other blocker.", _is_blocker))
		"Mountain Titan":
			c.activated(F._ability("{1}{R}{R}", false, F.Action.new(_titan, "this turn, casting a black spell puts a +1/+1 counter on this creature")))
		"Shyft": c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _shyft, "You may choose this creature's colors.", F._your_upkeep))
		"Total War": c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, _total_war, "Destroy the eligible untapped creatures that didn't attack.", _any_attack).capturing(_war_context))
		_: return false
	return true

static func _weather_target(i: CardInstance, snow: bool) -> bool:
	var is_snow := (i.cur_supertypes & Mtg.Supertype.SNOW) != 0
	return i.is_land() and (not is_snow and (i.cur_supertypes & Mtg.Supertype.BASIC) != 0 if snow else is_snow)
static func _weather(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x: int, snow: bool) -> void:
	var i := g.find_instance(t.instance_id)
	g.continuous.add_floating_static(s, StaticAbility.new(_snow_type.bind(i.id, snow), "Snow supertype changed.").changing_types(), ContinuousEffects.Duration.INDEFINITE, -1, false, i.id)
	g.recalculate()
static func _snow_type(g: MtgGame, _s: CardInstance, id: int, snow: bool) -> void:
	var i := g.find_instance(id)
	if i == null: return
	if snow: i.cur_supertypes |= Mtg.Supertype.SNOW
	else: i.cur_supertypes &= ~Mtg.Supertype.SNOW
static func _guides(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var i := g.find_instance(t.instance_id)
	var pick := g.agents[pid].choose_option(g, pid, TYPES, "Barbarian Guides: choose a snow landwalk type", 1)
	g.continuous.add_until_eot_landwalk(i.id, ["snow " + TYPES[pick]])
	g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _bounce.bind(i.id, i.layer_timestamp), "Return the guided creature to its owner's hand."), pid, s)
	g.recalculate()
static func _bounce(g: MtgGame, _s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
	var i := g.find_instance(id)
	if i != null and i.zone == Mtg.Zone.BATTLEFIELD and i.layer_timestamp == stamp: g.return_to_hand(i)
static func _draftable(g: MtgGame, _s: CardInstance, i: CardInstance) -> bool:
	return i.controller_id == g.active_player and not i.has_subtype("wall") and not i.summoning_sick
static func _before_attackers(g: MtgGame, _s: CardInstance) -> String:
	return "" if g.step_is_ahead(Mtg.Step.DECLARE_ATTACKERS) else "Activate only before attackers are declared"
static func _draft(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int, whistle: bool) -> void:
	var i := g.find_instance(t.instance_id)
	if whistle and EffectBase.unless_paid(g, i.controller_id, ManaCost.parse("{%d}" % i.data.cost.mana_value()), "Pay to ignore Arcum's Whistle?"): return
	g._rec(i, &"must_attack_this_turn")
	i.must_attack_this_turn = true
	g.doom_at_next_end_step_if_it_did_not_attack(i)
static func _sappers(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int, both: bool) -> void:
	var i := M.target_from_activation(g)
	var pairs: Array = []
	if i != null: pairs.append([i.id, i.layer_timestamp])
	if both and C.same_activation(g, s): pairs.append([s.id, s.layer_timestamp])
	g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_OF_COMBAT, _destroy_pairs.bind(pairs), "Destroy the Sappers' affected creatures."), pid, s)
static func _destroy_pairs(g: MtgGame, _s: CardInstance, _e: GameEvent, pairs: Array) -> void:
	g.begin_simultaneous()
	var done := {}
	for pair in pairs:
		var i := g.find_instance(pair[0])
		if i != null and not done.has(i.id) and i.zone == Mtg.Zone.BATTLEFIELD and i.layer_timestamp == int(pair[1]):
			done[i.id] = true
			g.destroy(i)
	g.end_simultaneous()
static func _fought(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool: return e.data.attacker == s or e.data.blocker == s
static func _fight_context(_g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var other: CardInstance = e.data.blocker if e.data.attacker == s else e.data.attacker
	return {"id": other.id, "stamp": other.layer_timestamp}
static func _cohort(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var i := g.find_instance(int(ctx.id))
	if i != null and i.zone == Mtg.Zone.BATTLEFIELD and i.layer_timestamp == int(ctx.stamp):
		g._rec(i, &"regeneration_banned_this_turn")
		i.regeneration_banned_this_turn = true
static func _opponents(g: MtgGame, s: CardInstance) -> Array[int]:
	return g.combat.blockers_of(s.id) if g.combat.attackers.has(s.id) else g.combat.attackers_blocked_by(s.id)
static func _in_combat(g: MtgGame, s: CardInstance, _e: GameEvent) -> bool: return not _opponents(g, s).is_empty()
static func _combat_context(g: MtgGame, s: CardInstance, _e: GameEvent) -> Dictionary:
	var pairs: Array = []
	for id in _opponents(g, s):
		var i := g.find_instance(id)
		if i != null: pairs.append([id, i.layer_timestamp])
	return {"pairs": pairs}
static func _combat_end(g: MtgGame, s: CardInstance, e: GameEvent, wight: bool) -> void:
	var pairs: Array = g.trigger_context(s).pairs
	if not wight:
		_destroy_pairs(g, s, e, pairs)
		return
	for pair in pairs:
		var i := g.find_instance(pair[0])
		if i == null or i.zone != Mtg.Zone.BATTLEFIELD or i.layer_timestamp != int(pair[1]): continue
		g.add_counters(i, "paralyzation")
		g.tap_permanent(i)
		g.continuous.add_floating_static(s, StaticAbility.new(_paralyzed.bind(i.id), "Doesn't untap with paralyzation counters."), ContinuousEffects.Duration.INDEFINITE, -1, false, i.id)
		g.continuous.add_granted_activated_ability(i.id, F._ability("{4}", false, F.Action.new(_remove_paralyzation, "remove a paralyzation counter from this creature")))
	g.recalculate()
static func _paralyzed(g: MtgGame, _s: CardInstance, id: int) -> void:
	var i := g.find_instance(id)
	if i != null and int(i.counters.get("paralyzation", 0)) > 0: i.cur_skips_untap = true
static func _remove_paralyzation(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if C.same_activation(g, s): g.remove_counters(s, "paralyzation")
static func _is_blocker(g: MtgGame, s: CardInstance, _e: GameEvent) -> bool: return not g.combat.attackers_blocked_by(s.id).is_empty()
static func _marton(g: MtgGame, s: CardInstance, _e: GameEvent, attacking: bool) -> void:
	var bodies: Array[int] = []
	for i in g.all_battlefield():
		if i == s or not i.is_creature(): continue
		if g.combat.attackers.has(i.id) if attacking else not g.combat.attackers_blocked_by(i.id).is_empty(): bodies.append(i.id)
	for id in bodies: g.continuous.add_until_eot_pump(id, bodies.size(), bodies.size())
	g.recalculate()
static func _titan(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	if not C.same_activation(g, s): return
	var entry := g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, _titan_grow.bind(s.id, s.layer_timestamp), "Put a +1/+1 counter on Mountain Titan.", _black_cast.bind(pid)), pid, s, true)
	entry["expires_turn"] = g.turn_number
static func _black_cast(_g: MtgGame, _s: CardInstance, e: GameEvent, pid: int) -> bool:
	return int(e.data.controller) == pid and (e.data.instance.cur_colors & Mtg.ManaColor.B) != 0
static func _titan_grow(g: MtgGame, _s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
	var i := g.find_instance(id)
	if i != null and i.zone == Mtg.Zone.BATTLEFIELD and i.layer_timestamp == stamp: g.add_counters(i, "+1/+1")
static func _shyft(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	var options: Array[String] = ["Keep current colors"]
	var colors := [Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B, Mtg.ManaColor.R, Mtg.ManaColor.G]
	var masks: Array[int] = [0]
	for bits in range(1, 32):
		var mask := 0
		var labels: Array[String] = []
		for n in 5:
			if (bits & (1 << n)) != 0:
				mask |= colors[n]
				labels.append(Mtg.COLOR_NAMES[colors[n]])
		options.append(" + ".join(labels))
		masks.append(mask)
	var choice := g.agents[s.controller_id].choose_option(g, s.controller_id, options, "Shyft: choose colors", 0)
	if choice > 0:
		g.continuous.add_until_eot_color(s.id, masks[choice], false, ContinuousEffects.Duration.INDEFINITE)
		g.recalculate()
static func _any_attack(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool: return not e.data.attackers.is_empty()
static func _war_context(g: MtgGame, _s: CardInstance, _e: GameEvent) -> Dictionary: return {"who": g.active_player}
static func _total_war(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var who := int(g.trigger_context(_s).who)
	var doomed: Array[CardInstance] = []
	for i in g.players[who].battlefield:
		if i.is_creature() and not i.tapped and not i.has_subtype("wall") and not i.summoning_sick and not i.attacked_this_turn: doomed.append(i)
	g.begin_simultaneous()
	for i in doomed: g.destroy(i)
	g.end_simultaneous()
