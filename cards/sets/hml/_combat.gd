extends RefCounted
## Combat history uses immutable IDs, incarnation stamps and event colours.
const F := preload("res://cards/sets/fem/_rules.gd")
const C := preload("res://cards/sets/ice/_creatures.gd")
const K := preload("res://cards/sets/ice/_combat_more.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Folk of An-Havva", "Root Spider":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BLOCKERS_DECLARED, _block_bonus, "Gets a blocking bonus until end of turn.", _blocking))
		"Ghost Hounds": c.triggered(TriggeredAbility.new(Mtg.EventType.BLOCKED, _ghost, "Gains first strike until end of turn.", _fought_white))
		"Rashka the Slayer", "Serra Inquisitors": c.triggered(TriggeredAbility.new(Mtg.EventType.BLOCKERS_DECLARED, _black_bonus, "Gets a bonus for blocking or being blocked by black creatures.", _fought_black))
		"Labyrinth Minotaur": c.triggered(TriggeredAbility.new(Mtg.EventType.BLOCKED, _labyrinth, "The blocked creature skips its next untap.", _as_blocker).capturing(K._fight_context))
		"Sea Troll": c.activated(F._ability("{U}", false, RegenerateEffect.new()).only_if(_fought_blue))
		"Clockwork Steed", "Clockwork Swarm":
			c.with_enters_counters("+1/+0", 4)
			if c.card_name == "Clockwork Swarm": c.with_cant_be_blocked_by(["wall"])
			else: c.static_ability(StaticAbility.new(_no_artifact_blockers, "Can't be blocked by artifact creatures."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_OF_COMBAT, _wind_down, "Remove a +1/+0 counter if this creature fought this combat.", _participated))
			c.activated(F._ability("{X}", true, F.Action.new(_wind_up, "put up to X +1/+0 counters on this creature, to a maximum of four", null, true)).during_step(Mtg.Step.UPKEEP).your_turn_only())
		"Greater Werewolf": c.triggered(TriggeredAbility.new(Mtg.EventType.END_OF_COMBAT, _werewolf, "Put a -0/-2 counter on each creature blocking or blocked by this creature.", K._in_combat).capturing(K._combat_context))
		"Joven's Ferrets":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, _ferret_bonus, "Gets +0/+2 until end of turn.", F._self_attack))
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_OF_COMBAT, _ferret_lock, "Tap creatures that blocked this creature this turn; they skip their next untap.").capturing(_ferret_context))
		"Spectral Bears": c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, _spectral, "Skip your next untap if defending player controls no black nontoken permanent.", _spectral_attacks))
		"Heart Wolf": c.activated(F._ability("", true, HeartWolf.new()).combat_only())
		"Dwarven Sea Clan": c.activated(F._ability("", true, F.Action.new(_sea_clan, "deal 2 damage to target attacking or blocking creature at end of combat", TargetSpec.creature("target attacking or blocking creature whose controller controls an Island").with_game_filter(_island_combatant))).before_step(Mtg.Step.COMBAT_END))
		"Reef Pirates": c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _mill, "That opponent mills a card.", _hit_opponent))
		"Giant Albatross": c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _albatross, "May pay {1}{U}; destroy creatures that damaged this unless their controllers pay 2 life.", _self_died).capturing(_albatross_context))
		_: return false
	return true

static func _blocking(g: MtgGame, s: CardInstance, _e: GameEvent) -> bool: return F._blocking(g, s)
static func _block_bonus(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	var spider := s.data.card_name == "Root Spider"
	var keywords: Array[int] = []
	if spider: keywords.append(Mtg.Keyword.FIRST_STRIKE)
	g.continuous.add_until_eot_pump(s.id, 1 if spider else 2, 0, keywords)
	g.recalculate()
static func _fought_white(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	if e.data.attacker != s and e.data.blocker != s: return false
	var other: CardInstance = e.data.blocker if e.data.attacker == s else e.data.attacker
	return (other.cur_colors & Mtg.ManaColor.W) != 0
static func _ghost(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s):
		g.continuous.add_until_eot_pump(s.id, 0, 0, [Mtg.Keyword.FIRST_STRIKE])
		g.recalculate()
static func _fought_black(g: MtgGame, s: CardInstance, _e: GameEvent) -> bool:
	var ids: Array[int] = g.combat.attackers_blocked_by(s.id)
	if s.data.card_name != "Rashka the Slayer": ids.append_array(g.combat.blockers_of(s.id))
	for id in ids:
		var i := g.find_instance(id)
		if i != null and (i.cur_colors & Mtg.ManaColor.B) != 0: return true
	return false
static func _black_bonus(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	var rashka := s.data.card_name == "Rashka the Slayer"
	g.continuous.add_until_eot_pump(s.id, 1 if rashka else 2, 2 if rashka else 0)
	g.recalculate()
static func _as_blocker(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool: return e.data.blocker == s
static func _labyrinth(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var context := g.trigger_context(s)
	var i := g.find_instance(int(context.id))
	if i != null and i.zone == Mtg.Zone.BATTLEFIELD and i.layer_timestamp == int(context.stamp):
		g._rec(i, &"skip_next_untap")
		i.skip_next_untap = true
static func _fought_blue(g: MtgGame, s: CardInstance) -> String:
	for pair in g.combat_pair_history:
		if int(pair.attacker) == s.id and int(pair.attacker_stamp) == s.layer_timestamp and (int(pair.get("blocker_colors", 0)) & Mtg.ManaColor.U) != 0: return ""
		if int(pair.blocker) == s.id and int(pair.blocker_stamp) == s.layer_timestamp and (int(pair.get("attacker_colors", 0)) & Mtg.ManaColor.U) != 0: return ""
	return "Activate only after blocking or being blocked by a blue creature this turn"
static func _not_artifact(i: CardInstance) -> bool: return not i.is_type(Mtg.CardType.ARTIFACT)
static func _no_artifact_blockers(_g: MtgGame, s: CardInstance) -> void: s.cur_block_restrictions.append({"desc": "nonartifact creatures", "filter": _not_artifact})
static func _participated(g: MtgGame, s: CardInstance, _e: GameEvent) -> bool: return int(g.combat.participant_stamps.get(s.id, -1)) == s.layer_timestamp
static func _wind_down(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s): g.remove_counters(s, "+1/+0")
static func _wind_up(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, x: int) -> void:
	if not C.same_activation(g, s): return
	var max_count := mini(x, maxi(0, 4 - int(s.counters.get("+1/+0", 0))))
	if max_count == 0: return
	var options: Array[String] = []
	for count in max_count + 1: options.append("Add %d +1/+0 counters" % count)
	var count := g.agents[pid].choose_option(g, pid, options, "Clockwork: wind up", max_count)
	if count > 0 and count <= max_count: g.add_counters(s, "+1/+0", count)
static func _werewolf(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.begin_simultaneous()
	for pair in g.trigger_context(s).pairs:
		var i := g.find_instance(pair[0])
		if i != null and i.zone == Mtg.Zone.BATTLEFIELD and i.layer_timestamp == int(pair[1]): g.add_counters(i, "-0/-2")
	g.end_simultaneous()
static func _ferret_bonus(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s):
		g.continuous.add_until_eot_pump(s.id, 0, 2)
		g.recalculate()
static func _ferret_context(g: MtgGame, s: CardInstance, _e: GameEvent) -> Dictionary:
	var pairs: Array = []
	for pair in g.combat_pair_history:
		if int(pair.attacker) == s.id and int(pair.attacker_stamp) == s.layer_timestamp:
			var key := [int(pair.blocker), int(pair.blocker_stamp)]
			if not pairs.has(key): pairs.append(key)
	return {"pairs": pairs}
static func _ferret_lock(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	for pair in g.trigger_context(s).pairs:
		var i := g.find_instance(pair[0])
		if i != null and i.zone == Mtg.Zone.BATTLEFIELD and i.layer_timestamp == int(pair[1]):
			g.tap_permanent(i)
			g._rec(i, &"skip_next_untap")
			i.skip_next_untap = true
static func _no_black_permanent(g: MtgGame, who: int) -> bool:
	for i in g.players[1 - who].battlefield:
		if not i.is_token and (i.cur_colors & Mtg.ManaColor.B) != 0: return false
	return true
static func _spectral_attacks(g: MtgGame, s: CardInstance, e: GameEvent) -> bool: return F._self_attack(g, s, e) and _no_black_permanent(g, s.controller_id)
static func _spectral(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s) and _no_black_permanent(g, int(g.trigger_context(s).controller)):
		g.skip_untap_during_next_step(s, int(g.trigger_context(s).controller))
static func _island_combatant(g: MtgGame, i: CardInstance) -> bool:
	if not g.combat.attackers.has(i.id) and not F._blocking(g, i): return false
	for land in g.players[i.controller_id].battlefield:
		if land.is_land() and land.has_subtype("island"): return true
	return false
static func _sea_clan(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var i := g.find_instance(t.instance_id)
	g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_OF_COMBAT, _late_damage.bind(i.id, i.layer_timestamp), "Deal 2 damage to that creature."), pid, s)
static func _late_damage(g: MtgGame, s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
	var i := g.find_instance(id)
	if i != null and i.zone == Mtg.Zone.BATTLEFIELD and i.layer_timestamp == stamp: g.deal_damage(s, TargetRef.card(i), 2)
static func _hit_opponent(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool: return e.data.get("source") == s and int(e.data.get("to_player", -1)) == 1 - s.controller_id
static func _mill(g: MtgGame, _s: CardInstance, e: GameEvent) -> void: g.mill(int(e.data.to_player), 1)
static func _self_died(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool: return e.data.instance == s
static func _albatross_context(_g: MtgGame, _s: CardInstance, e: GameEvent) -> Dictionary: return {"controller": int(e.data.controller), "origins": e.data.get("damage_origins", {}).duplicate()}
static func _albatross(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var context := g.trigger_context(s)
	var who := int(context.controller)
	var victims: Array[CardInstance] = []
	for i in g.all_battlefield():
		if i.is_creature() and context.origins.has("%d:%d" % [i.id, i.layer_timestamp]): victims.append(i)
	if victims.is_empty() or not EffectBase.unless_paid(g, who, ManaCost.parse("{1}{U}"), "Giant Albatross: pay {1}{U} to avenge it?", true): return
	var destroy: Array[CardInstance] = []
	for i in victims:
		var owner := i.controller_id
		if g.players[owner].life >= 2 and g.agents[owner].choose_yes_no(g, owner, "Pay 2 life to save %s from Giant Albatross?" % i.data.card_name, g.players[owner].life > 2): g.adjust_life(owner, -2)
		else: destroy.append(i)
	g.begin_simultaneous()
	for i in destroy: g.destroy(i, false)
	g.end_simultaneous()
static func _dwarf_left(_g: MtgGame, _s: CardInstance, e: GameEvent, id: int, stamp: int) -> bool: return e.data.instance.id == id and e.data.instance.layer_timestamp == stamp
static func _wolf_sacrifice(g: MtgGame, _s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
	var i := g.find_instance(id)
	if i != null and i.zone == Mtg.Zone.BATTLEFIELD and i.layer_timestamp == stamp: g.sacrifice_permanent(i)

class HeartWolf extends PumpEffect:
	func _init() -> void:
		super(2, 0, [Mtg.Keyword.FIRST_STRIKE])
		target_spec = TargetSpec.creature("target Dwarf creature", F._subtype.bind("dwarf"))
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		super(g, s, pid, t, x)
		if not C.same_activation(g, s): return
		var i := g.find_instance(t.instance_id)
		var rules = load("res://cards/sets/hml/_combat.gd")
		var entry := g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.LEAVES_BATTLEFIELD, rules._wolf_sacrifice.bind(s.id, s.layer_timestamp), "Sacrifice Heart Wolf.", rules._dwarf_left.bind(i.id, i.layer_timestamp)), pid, s)
		entry["expires_turn"] = g.turn_number
