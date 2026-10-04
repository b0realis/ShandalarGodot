extends RefCounted
## Weatherlight (_combat, Pack 8). Combat rules: flanking, blocking and attacking restrictions, combat triggers.
##
## "At end of combat" riders are DELAYED TRIGGERS (CR 603.7) created by the
## combat trigger and bound to that object (CR 400.7: a creature that left
## and came back is a new one). tests/cards/test_pack_8_b8_wth_combat.gd
## pins each card's distinguishing clause.
const F := preload("res://cards/sets/fem/_rules.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Foriysian Brigade":
			c.with_extra_blocks(1)
		"Cloud Djinn":
			c.static_ability(StaticAbility.new(_flyers_only, "This creature can block only creatures with flying."))
		"Fog Elemental":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, _sacrifice_after_combat,
				"When this creature attacks, sacrifice it at end of combat.", _self_attacks))
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECOMES_BLOCKER, _sacrifice_after_combat,
				"When this creature blocks, sacrifice it at end of combat.", F._self_enter))
		"Manta Ray":
			c.with_attack_needs_defender_land("island").with_sacrifice_if_no_land("island")
			c.static_ability(StaticAbility.new(_blue_blockers_only, "This creature can't be blocked except by blue creatures."))
		"Ophidian":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UNBLOCKED_ATTACKER, _ophidian,
				"Whenever this creature attacks and isn't blocked, you may draw a card. If you do, this creature assigns no combat damage this turn.", F._self_enter))
		"Tolarian Entrancer":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BLOCKED, _entrance,
				"Whenever this creature becomes blocked by a creature, gain control of that creature at end of combat.", _blocked_by_creature))
		"Bone Dancer":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UNBLOCKED_ATTACKER, _bone_dance,
				"Whenever this creature attacks and isn't blocked, you may put the top creature card of defending player's graveyard onto the battlefield under your control. If you do, this creature assigns no combat damage this turn.", F._self_enter))
		"Shadow Rider":
			# Flanking is the engine's own stack trigger (engine/abilities/flanking.gd).
			if not c.keywords.has(Mtg.Keyword.FLANKING): c.with_keywords([Mtg.Keyword.FLANKING])
		"Cinder Wall":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECOMES_BLOCKER, _destroy_after_combat,
				"When this creature blocks, destroy it at end of combat.", F._self_enter))
		"Dwarven Berserker":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECOMES_BLOCKED, _berserk,
				"Whenever this creature becomes blocked, it gets +3/+0 and gains trample until end of turn.", F._self_enter))
		"Goblin Grenadiers":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UNBLOCKED_ATTACKER, _grenade,
				"Whenever this creature attacks and isn't blocked, you may sacrifice it. If you do, destroy target creature and target land.", F._self_enter)
				.targeting(TargetSpec.creature(), _grenade_creature_first, "Select target creature.")
				.and_targeting(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _land), F._enemy_first, "Select target land."))
		"Goblin Vandal":
			var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact defending player controls", _artifact) \
				.with_source_filter(_defending_player_controls)
			c.triggered(TriggeredAbility.new(Mtg.EventType.UNBLOCKED_ATTACKER, _vandal,
				"Whenever this creature attacks and isn't blocked, you may pay {R}. If you do, destroy target artifact defending player controls and this creature assigns no combat damage this turn.", F._self_enter)
				.targeting(spec, F._enemy_first, "Select target artifact defending player controls."))
		"Heat Stroke":
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_OF_COMBAT, _heat_stroke,
				"At end of combat, destroy each creature that blocked or was blocked this turn.", _always))
		"Lava Storm":
			c.mode("Lava Storm deals 2 damage to each attacking creature", [CombatSweep.new(false)])
			c.mode("Lava Storm deals 2 damage to each blocking creature", [CombatSweep.new(true)])
			c.with_ai_mode(_lava_mode)
		"Sawtooth Ogre":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BLOCKED, _ogre_bite,
				"Whenever this creature blocks or becomes blocked by a creature, this creature deals 1 damage to that creature at end of combat.", _ogre_pair))
		"Choking Vines":
			c.castable_only_when(_during_declare_blockers)
			c.spell(MakeBlockedEffect.attacking().then_damage(1).x_targets())
		"Familiar Ground":
			c.static_ability(StaticAbility.new(_one_blocker_each, "Each creature you control can't be blocked by more than one creature."))
		"Jangling Automaton":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, _jangle,
				"Whenever this creature attacks, untap all creatures defending player controls.", _self_attacks))
		_: return false
	return true


static func _always(_g: MtgGame, _s: CardInstance, _e: GameEvent) -> bool: return true
static func _land(i: CardInstance) -> bool: return i.is_land()
static func _artifact(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ARTIFACT)
static func _flying(i: CardInstance) -> bool: return i.has_keyword(Mtg.Keyword.FLYING)
static func _not_flying(i: CardInstance) -> bool: return not _flying(i)
static func _blue(i: CardInstance) -> bool: return i.has_color(Mtg.ManaColor.U)

static func _self_attacks(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return (e.data.get("attackers", []) as Array).has(s)

static func _context_pid(g: MtgGame, s: CardInstance) -> int:
	return int(g.trigger_context(s).get("controller", s.controller_id))

## The defending player of a two-seat duel: the attacker's opponent.
static func _defending_player_controls(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
	return s != null and i.controller_id == g.opponent_of(s.controller_id)


# ---------------------------------------------------------------- statics

static func _flyers_only(_g: MtgGame, s: CardInstance) -> void:
	s.cur_cant_block_filter = _not_flying

static func _blue_blockers_only(_g: MtgGame, s: CardInstance) -> void:
	s.cur_block_restrictions.append({"desc": "blue creatures", "filter": _blue})

static func _one_blocker_each(g: MtgGame, s: CardInstance) -> void:
	for i in g.players[s.controller_id].battlefield:
		if i.is_creature() and (i.cur_max_blockers == 0 or i.cur_max_blockers > 1):
			i.cur_max_blockers = 1


# ----------------------------------------------------- end-of-combat riders

## A delayed END_OF_COMBAT trigger (CR 603.7) controlled by the trigger's
## controller, acting on [param target] only while it is the same object.
static func _at_end_of_combat(g: MtgGame, s: CardInstance, pid: int, action: Callable, text: String) -> void:
	g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_OF_COMBAT, action, text, _always), pid, s)

static func _live(g: MtgGame, id: int, stamp: int) -> CardInstance:
	var i := g.find_instance(id)
	return i if i != null and i.zone == Mtg.Zone.BATTLEFIELD and i.layer_timestamp == stamp else null

static func _sacrifice_after_combat(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	_at_end_of_combat(g, s, _context_pid(g, s), _sacrifice_it.bind(s.id, s.layer_timestamp), "Sacrifice it.")

## "Sacrifice it": only its controller can (CR 701.17a) — the player the
## delayed trigger belongs to.
static func _sacrifice_it(g: MtgGame, _s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
	var i := _live(g, id, stamp)
	if i != null and i.controller_id == g.current_resolution_controller(): g.sacrifice_permanent(i)

static func _destroy_after_combat(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	_at_end_of_combat(g, s, _context_pid(g, s), _destroy_it.bind(s.id, s.layer_timestamp), "Destroy it.")

static func _destroy_it(g: MtgGame, _s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
	var i := _live(g, id, stamp)
	if i != null: g.destroy(i)

static func _blocked_by_creature(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("attacker") == s and e.data.get("blocker") != null

static func _entrance(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var blocker: CardInstance = e.data.get("blocker")
	if blocker == null: return
	_at_end_of_combat(g, s, _context_pid(g, s), _take_control.bind(blocker.id, blocker.layer_timestamp),
		"Gain control of that creature.")

static func _take_control(g: MtgGame, _s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
	var i := _live(g, id, stamp)
	var pid := g.current_resolution_controller()
	if i != null and pid >= 0: g.change_control(i, pid)

static func _ogre_pair(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("attacker") == s or e.data.get("blocker") == s

static func _ogre_bite(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var other: CardInstance = e.data.get("blocker") if e.data.get("attacker") == s else e.data.get("attacker")
	if other == null: return
	_at_end_of_combat(g, s, _context_pid(g, s), _bite.bind(other.id, other.layer_timestamp),
		"This creature deals 1 damage to that creature.")

## The Ogre deals the damage even if it has left (last known information,
## CR 608.2h); the creature must still be the one it fought.
static func _bite(g: MtgGame, s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
	var i := _live(g, id, stamp)
	if i != null: g.deal_damage(s, TargetRef.card(i), 1)


# ------------------------------------------------------- combat triggers

static func _berserk(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	g.continuous.add_until_eot_pump(s.id, 3, 0, [Mtg.Keyword.TRAMPLE])
	g.recalculate()

static func _ophidian(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := _context_pid(g, s)
	var lethal := F._same_trigger_source(g, s) and g.players[g.opponent_of(pid)].life <= s.cur_power
	if not g.agents[pid].choose_yes_no(g, pid,
			"Ophidian: draw a card? If you do, it assigns no combat damage this turn.", not lethal):
		return
	g.draw_cards(pid, 1)
	if F._same_trigger_source(g, s): F._no_assignment(g, s, s.id)

## "The top creature card of defending player's graveyard": the topmost
## card that IS a creature card, whatever lies above it.
static func _bone_dance(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := _context_pid(g, s)
	var grave: Array = g.players[g.opponent_of(pid)].graveyard
	var top: CardInstance = null
	for k in range(grave.size() - 1, -1, -1):
		if (grave[k] as CardInstance).data.is_creature():
			top = grave[k]
			break
	if top == null: return
	var lethal := F._same_trigger_source(g, s) and g.players[g.opponent_of(pid)].life <= s.cur_power
	if not g.agents[pid].choose_yes_no(g, pid,
			"Bone Dancer: put %s onto the battlefield under your control? It then assigns no combat damage this turn." % top.data.card_name,
			not lethal):
		return
	g.reanimate(top, pid)
	if F._same_trigger_source(g, s): F._no_assignment(g, s, s.id)

## E9's two-slot trigger: "you may sacrifice it. If you do, destroy target
## creature and target land" — each slot read on its own (CR 608.2b).
static func _grenade(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	var pid := _context_pid(g, s)
	if s.controller_id != pid: return
	var creature_ref := g.current_trigger_target(0)
	var land_ref := g.current_trigger_target(1)
	var hint := false
	for ref in [creature_ref, land_ref]:
		if ref == null: continue
		var i := g.find_instance(ref.instance_id)
		if i != null and i.controller_id != pid: hint = true
	# ...but never at the price of another creature of OURS (the Mirage bug
	# pass: a Serra Angel destroyed for a Plains). The Grenadiers itself, the
	# creature slot's fallback, is sacrificed anyway.
	var own: CardInstance = null
	if creature_ref != null: own = g.find_instance(creature_ref.instance_id)
	if own != null and own != s and own.controller_id == pid: hint = false
	if not g.agents[pid].choose_yes_no(g, pid, "Goblin Grenadiers: sacrifice it to destroy the targets?", hint): return
	g.sacrifice_permanent(s)
	g.begin_simultaneous()
	for ref in [creature_ref, land_ref]:
		if ref == null: continue
		var i := g.find_instance(ref.instance_id)
		if i != null and i.zone == Mtg.Zone.BATTLEFIELD: g.destroy(i)
	g.end_simultaneous()

## Goblin Grenadiers' creature slot, best first for its controller: theirs
## (the biggest first), then the Grenadiers itself — sacrificed anyway, so
## naming it costs nothing more — then ours, the smallest first.
static func _grenade_creature_first(g: MtgGame, source: CardInstance, at: TargetRef, bt: TargetRef) -> bool:
	return _grenade_rank(source, g.find_instance(at.instance_id)) \
		> _grenade_rank(source, g.find_instance(bt.instance_id))

static func _grenade_rank(source: CardInstance, i: CardInstance) -> int:
	if i == null: return -100000
	if i.controller_id != source.controller_id: return 100000 + i.cur_power + i.cur_toughness
	if i == source: return 0
	return -1 - maxi(i.cur_power, 0) - maxi(i.cur_toughness, 0)

static func _vandal(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ref := g.current_trigger_target(0)
	if ref == null: return
	var victim := g.find_instance(ref.instance_id)
	if victim == null: return
	var pid := _context_pid(g, s)
	if not EffectBase.unless_paid(g, pid, ManaCost.parse("{R}"),
			"Goblin Vandal: pay {R} to destroy %s?" % victim.data.card_name, true):
		return
	g.destroy(victim)
	if F._same_trigger_source(g, s): F._no_assignment(g, s, s.id)

static func _jangle(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	for i in g.players[g.opponent_of(_context_pid(g, s))].battlefield.duplicate():
		if i.is_creature() and i.tapped: g.untap_permanent(i)

## Who blocked (blocked_this_turn) or was blocked this turn: this combat's
## blocked attackers and every surviving blocker's record — an attacker
## must also have attacked this turn as the object it is now (CR 400.7).
static func _heat_stroke(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	var was_blocked := {}
	for id in g.combat.blocked_attackers: was_blocked[int(id)] = true
	for i in g.all_battlefield():
		for id in i.blocked_ids_this_turn: was_blocked[int(id)] = true
	var doomed: Array[CardInstance] = []
	for i in g.all_battlefield():
		if not i.is_creature(): continue
		if i.blocked_this_turn or (i.attacked_this_turn and was_blocked.has(i.id)):
			doomed.append(i)
	if doomed.is_empty(): return
	g.begin_simultaneous()
	for i in doomed: g.destroy(i)
	g.end_simultaneous()


# --------------------------------------------------------------- Lava Storm

## "2 damage to each attacking (or each blocking) creature" — a sweeper
## over one side of the combat, simultaneous (CR 704.3).
class CombatSweep extends DamageAllEffect:
	var blocking: bool
	func _init(p_blocking: bool) -> void:
		super(2, "each blocking creature" if p_blocking else "each attacking creature")
		blocking = p_blocking
	func resolve(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		var victims: Array[CardInstance] = []
		for i in g.all_battlefield():
			if i.is_creature() and (g.combat.blocks.has(i.id) if blocking else g.combat.attackers.has(i.id)):
				victims.append(i)
		if victims.is_empty(): return
		g.begin_simultaneous()
		for i in victims: g.deal_damage(s, TargetRef.card(i), amount)
		g.end_simultaneous()

## The AI's mode: the side of the combat where 2 damage kills more of the
## enemy than of its own (public board state).
static func _lava_mode(g: MtgGame, pid: int) -> int:
	var score := [0.0, 0.0]
	for i in g.all_battlefield():
		if not i.is_creature() or i.cur_indestructible or i.cur_toughness - i.damage > 2: continue
		var worth := float(i.cur_power + i.cur_toughness) * (1.0 if i.controller_id != pid else -1.0)
		if g.combat.attackers.has(i.id): score[0] += worth
		if g.combat.blocks.has(i.id): score[1] += worth
	return 1 if score[1] > score[0] else 0


# ------------------------------------------------------------- Choking Vines

static func _during_declare_blockers(g: MtgGame, _pid: int) -> String:
	return "" if g.current_step() == Mtg.Step.DECLARE_BLOCKERS else "cast only during the declare blockers step"
