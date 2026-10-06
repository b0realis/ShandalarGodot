extends RefCounted
## Tempest (_combat, Pack 9). Combat rules: blocking and attacking restrictions, combat triggers.
##
## Same conventions as the Mirage module (cards/sets/mir/_combat.gd), whose
## shared helpers this one uses ([code]MC.pair_trigger[/code], the
## per-creature attack fan-out, [code]MC.same[/code], [code]MC.live_source[/code]):
## - "Blocks or becomes blocked by a creature" (Elven Warhounds, Flailing
##   Drake, No Quarter) hears BLOCKED — one event per blocking creature per
##   attacker, so two blockers are two triggers (CR 509.3c-d); the other
##   creature is captured as the ability triggers and acted on only while it
##   is that same object (CR 400.7). No Quarter compares the two powers as
##   the block is declared: it is the trigger condition, not an intervening
##   "if" (CR 603.4), so a later pump changes nothing.
## - "Whenever this creature blocks" (Elite Javelineer) is BECOMES_BLOCKER,
##   once however many attackers it blocks.
## - "Target creature blocking this creature" (Knight of Dusk, Flowstone
##   Salamander) is a creature blocking any member of this creature's band
##   (CR 702.22j) — Mirage's Ambush Party shape (mir/_creatures.gd).
## - "Blocks this creature this turn if able" (Trumpeting Armodon, Magnetic
##   Web) is a Lure narrowed by a filter (Lure's cur_must_be_blocked with
##   cur_must_be_blocked_filter), kept by a floating static bound to the
##   attacker for the turn and OR-ed with any narrowed Lure already there
##   (Crashing Boars' shape, exo/_combat.gd); a Lure asking every creature
##   is left alone. "Blocks each combat if able" (Watchdog) and "attack if
##   able" keyed to a predicate (Magnetic Web) are Pack 9 E4's
##   (CombatState.blocks_each_combat / add_attack_requirement).
## - Propaganda is a combined attack COST paid as attackers are declared
##   (CR 508.1g; Koskun Falls' and Elephant Grass' shape): "attack you" is
##   every creature of its controller's opponent.
## - Maddening Imp: the creatures are those the active player controls as
##   the ability resolves (CR 611.2c) — summoning-sick ones included: they
##   can't attack, so they are destroyed (the card has no "controlled
##   continuously" clause, unlike Siren's Call). "Only before combat": the
##   beginning-of-combat step of a combat still ahead this turn.
## tests/cards/test_pack_9_B8_combat.gd pins each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const MC := preload("res://cards/sets/mir/_combat.gd")


static func configure(c: CardData) -> bool:
	match c.card_name:
		"Apes of Rath":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, _apes,
				"Whenever this creature attacks, it doesn't untap during its controller's next untap step.",
				F._self_attack))
		"Elite Javelineer":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECOMES_BLOCKER, _javelin,
				"Whenever this creature blocks, it deals 1 damage to target attacking creature.",
				F._self_enter).targeting(_attacking_spec(), _weakest_attacker_first,
				"Select an attacking creature."))
		"Elven Warhounds":
			c.triggered(MC.pair_trigger(MC.BLOCKED_BY, Callable(), _warhounds,
				"Whenever this creature becomes blocked by a creature, put that creature on top of its owner's library."))
		"Flailing Drake":
			c.triggered(MC.pair_trigger(MC.EITHER, Callable(), _drake,
				"Whenever this creature blocks or becomes blocked by a creature, that creature gets +1/+1 until end of turn."))
		"Flowstone Salamander":
			var ping := DamageEffect.new(1).target_creature("target creature blocking it")
			ping.target_spec.with_source_filter(_blocking_source)
			c.activated(ActivatedAbility.new("{R}", false, [ping],
				"{R}: This creature deals 1 damage to target creature blocking it."))
		"Gerrard's Battle Cry":
			c.activated(ActivatedAbility.new("{2}{W}", false,
				[MassPumpEffect.new(1, 1, "creatures you control").yours_only()],
				"{2}{W}: Creatures you control get +1/+1 until end of turn."))
		"Knight of Dusk":
			c.activated(ActivatedAbility.new("{B}{B}", false,
				[DestroyEffect.new(TargetSpec.creature("target creature blocking this creature") \
					.with_source_filter(_blocking_source))],
				"{B}{B}: Destroy target creature blocking this creature."))
		"Maddening Imp":
			c.activated(ActivatedAbility.new("", true,
				[F.Action.new(_madden, "non-Wall creatures the active player controls attack this turn if able; at the beginning of the next end step, destroy each of those creatures that didn't attack this turn") \
					.with_ai_role(&"forces_attacks", {"non_wall": true, "sick_die": true})],
				"{T}: Non-Wall creatures the active player controls attack this turn if able. At the beginning of the next end step, destroy each of those creatures that didn't attack this turn. Activate only during an opponent's turn and only before combat.") \
				.only_if(_before_combat_on_their_turn))
		"Magnetic Web":
			c.static_ability(StaticAbility.new(_web_attack,
				"If a creature with a magnet counter on it attacks, all creatures with magnet counters on them attack if able."))
			c.triggered(MC.attack_fan_out(_web_fan_out, _a_magnet_attacks_event,
				"Whenever a creature with a magnet counter on it attacks, all creatures with magnet counters on them block that creature this turn if able."))
			c.activated(ActivatedAbility.new("{1}", true,
				[CounterMarkerEffect.new("magnet", 1, TargetSpec.creature()).with_ai_role(&"magnet_counter")],
				"{1}, {T}: Put a magnet counter on target creature."))
		"Mogg Conscripts":
			c.static_ability(StaticAbility.new(_conscripts,
				"This creature can't attack unless you've cast a creature spell this turn."))
		"Mounted Archers":
			c.activated(ActivatedAbility.new("{W}", false,
				[F.Action.new(_extra_block, "this creature can block an additional creature this turn", null, true) \
					.with_ai_role(&"extra_block", {"blocks": 1})],
				"{W}: This creature can block an additional creature this turn."))
		"No Quarter":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BLOCKED, _quarter_blocker,
				"Whenever a creature becomes blocked by a creature with lesser power, destroy the blocking creature.",
				_blocker_weaker).capturing(_pair_context))
			c.triggered(TriggeredAbility.new(Mtg.EventType.BLOCKED, _quarter_attacker,
				"Whenever a creature blocks a creature with lesser power, destroy the attacking creature.",
				_attacker_weaker).capturing(_pair_context))
		"Propaganda":
			c.static_ability(StaticAbility.new(_propaganda,
				"Creatures can't attack you unless their controller pays {2} for each creature they control that's attacking you."))
		"Renegade Warlord":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, _warlord,
				"Whenever this creature attacks, each other attacking creature gets +1/+0 until end of turn.",
				F._self_attack))
		"Safeguard":
			c.activated(ActivatedAbility.new("{2}{W}", false,
				[PreventCombatDamageEffect.new().by_target_creature()],
				"{2}{W}: Prevent all combat damage that would be dealt by target creature this turn."))
		"Sea Monster":
			c.with_attack_needs_defender_land("island")
		"Storm Front":
			c.activated(ActivatedAbility.new("{G}{G}", false,
				[TapEffect.new(TargetSpec.creature("target creature with flying", MC.P.flying))],
				"{G}{G}: Tap target creature with flying."))
		"Trumpeting Armodon":
			c.activated(ActivatedAbility.new("{1}{G}", false,
				[F.Action.new(_armodon, "target creature blocks this creature this turn if able",
					TargetSpec.creature()).with_ai_role(&"lure_target")],
				"{1}{G}: Target creature blocks this creature this turn if able."))
		"Watchdog":
			c.static_ability(CombatState.blocks_each_combat())
			c.static_ability(StaticAbility.new(_watchdog,
				"As long as this creature is untapped, all creatures attacking you get -1/-0."))
		_: return false
	return true


# ================================================================= helpers

static func _anything(_i: CardInstance) -> bool: return true

static func _attacking(g: MtgGame, i: CardInstance) -> bool: return g.combat.attackers.has(i.id)

static func _attacking_spec() -> TargetSpec:
	return TargetSpec.creature("target attacking creature").with_game_filter(_attacking).because("attacking")

## "Target creature blocking this creature": blocking any member of this
## creature's band (CR 702.22j).
static func _blocking_source(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
	return g.combat.blockers_of_band(g.combat.band_of(s.id)).has(i.id)

## A Lure narrowed to the blockers [param filter] accepts, OR-ed with a
## narrowed Lure already on [param attacker]; a Lure asking every creature
## already covers it — and one made AFTER this raises
## `cur_must_be_blocked_by_all`, which outranks the filter written here
## (CombatDeclaration.lure_binds), so it is never narrowed by it.
static func narrow_lure(attacker: CardInstance, filter: Callable) -> void:
	if attacker.cur_must_be_blocked_by_all or (attacker.cur_must_be_blocked
			and not attacker.cur_must_be_blocked_filter.is_valid()):
		return
	var before := attacker.cur_must_be_blocked_filter
	attacker.cur_must_be_blocked = true
	if not before.is_valid():
		attacker.cur_must_be_blocked_filter = filter
	else:
		attacker.cur_must_be_blocked_filter = func(blocker: CardInstance) -> bool:
			return bool(before.call(blocker)) or bool(filter.call(blocker))


# ------------------------------------------------------------ Apes of Rath --

## Lead Golem's shape (mir/_combat.gd): only while it is the very creature
## that attacked (CR 400.7).
static func _apes(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if MC.same(g, s):
		g.skip_untap_during_next_step(s, s.controller_id)


# -------------------------------------------------------- Elite Javelineer --

## The 1 damage is dealt even if the Javelineer has left (CR 608.2h: last
## known information about the source).
static func _javelin(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	for t in g.current_targets():
		var i := g.find_instance(t.instance_id)
		if g.is_present(i):
			g.deal_damage(s, TargetRef.card(i), 1)

## The hint: an attacker the point kills first, then the biggest.
static func _weakest_attacker_first(g: MtgGame, _s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	var ai := g.find_instance(a.instance_id)
	var bi := g.find_instance(b.instance_id)
	if ai == null or bi == null: return ai != null
	var a_dies := ai.cur_toughness - ai.damage <= 1
	var b_dies := bi.cur_toughness - bi.damage <= 1
	if a_dies != b_dies: return a_dies
	if ai.cur_power != bi.cur_power: return ai.cur_power > bi.cur_power
	return ai.id < bi.id


# --------------------------------------------------------- Elven Warhounds --

static func _warhounds(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var other := MC.pair_other_live(g, s)
	if other != null:
		g.return_permanent_to_library_top(other)


# ---------------------------------------------------------- Flailing Drake --

static func _drake(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var other := MC.pair_other_live(g, s)
	if other == null: return
	g.continuous.add_until_eot_pump(other.id, 1, 1)
	g.recalculate()


# ---------------------------------------------------------- Maddening Imp --

## "Activate only during an opponent's turn and only before combat": a
## beginning-of-combat step still ahead this turn and none in progress.
static func _before_combat_on_their_turn(g: MtgGame, s: CardInstance) -> String:
	if g.active_player == s.controller_id:
		return "activate only during an opponent's turn"
	if Mtg.is_combat_step(g.current_step()) or not g.step_is_ahead(Mtg.Step.COMBAT_BEGIN):
		return "activate only before combat"
	return ""


static func _madden(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	var ap := g.active_player
	var drafted: Array[CardInstance] = []
	for inst in g.players[ap].battlefield:
		if g.is_present(inst) and inst.is_creature() and not inst.has_subtype("wall"):
			drafted.append(inst)
	for inst in drafted:
		g._rec(inst, &"must_attack_this_turn")
		inst.must_attack_this_turn = true
		g.doom_at_next_end_step_if_it_did_not_attack(inst)
	g.log_line("Maddening Imp: %d creature(s) must attack this turn" % drafted.size())


# ------------------------------------------------------------ Magnetic Web --

static func _magnetic(i: CardInstance) -> bool:
	return int(i.counters.get("magnet", 0)) > 0


## The attack half (Pack 9 E4): every creature with a magnet counter must
## attack if able whenever one with a magnet counter attacks (CR 508.1d).
static func _web_attack(g: MtgGame, s: CardInstance) -> void:
	for inst in g.all_battlefield():
		if inst.is_creature() and not inst.phased_out and _magnetic(inst):
			CombatState.add_attack_requirement(inst, s, _magnet_attacks,
				"a creature with a magnet counter on it attacks")


static func _magnet_attacks(_g: MtgGame, declared: Array) -> bool:
	for inst in declared:
		if _magnetic(inst as CardInstance):
			return true
	return false


static func _a_magnet_attacks_event(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	for inst in e.data.get("attackers", []):
		if inst is CardInstance and _magnetic(inst):
			return true
	return false


## One trigger per magnet attacker (CR 603.2c), read as it attacks.
static func _web_fan_out(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	for attacker in e.data.get("attackers", []):
		var i := attacker as CardInstance
		if i != null and _magnetic(i):
			MC.queue_for_attacker(g, s, e, s.controller_id, i, _web_lure,
				"Whenever a creature with a magnet counter on it attacks, all creatures with magnet counters on them block that creature this turn if able.")


## The block half: "all creatures with magnet counters on them block that
## creature this turn if able" — read when blockers are declared (a block
## requirement changes no characteristic, CR 611.2c).
static func _web_lure(g: MtgGame, s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
	var i := MC.live(g, id, stamp)
	if i == null: return
	g.continuous.add_floating_static(s, StaticAbility.new(_web_lure_static.bind(id, stamp),
		"All creatures with magnet counters on them block this creature this turn if able."),
		ContinuousEffects.Duration.END_OF_TURN, -1, false, id)
	g.recalculate()


static func _web_lure_static(g: MtgGame, _s: CardInstance, id: int, stamp: int) -> void:
	var i := MC.live(g, id, stamp)
	if i != null:
		narrow_lure(i, _magnetic)


# --------------------------------------------------------- Mogg Conscripts --

static func _conscripts(g: MtgGame, s: CardInstance) -> void:
	if not cast_creature_spell_this_turn(g, s.controller_id):
		s.cur_cant_attack = true


## Has [param pid] cast a creature spell this turn (a copy is not cast)?
static func cast_creature_spell_this_turn(g: MtgGame, pid: int) -> bool:
	if pid < 0 or pid >= g.spells_cast_this_turn.size(): return false
	for data in g.spells_cast_this_turn[pid]:
		if data is CardData and (data as CardData).is_creature():
			return true
	return false


# --------------------------------------------------------- Mounted Archers --

## A turn-scoped permission (CardInstance.extra_blocks_this_turn, cleared at
## cleanup — Yare's), added to; "any number" (-1) already covers it.
static func _extra_block(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if not MC.live_source(g, s) or s.extra_blocks_this_turn < 0: return
	g._rec(s, &"extra_blocks_this_turn")
	s.extra_blocks_this_turn += 1


# --------------------------------------------------------------- No Quarter --

static func _blocker_weaker(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	var attacker: CardInstance = e.data.get("attacker")
	var blocker: CardInstance = e.data.get("blocker")
	return attacker != null and blocker != null and blocker.cur_power < attacker.cur_power


static func _attacker_weaker(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	var attacker: CardInstance = e.data.get("attacker")
	var blocker: CardInstance = e.data.get("blocker")
	return attacker != null and blocker != null and attacker.cur_power < blocker.cur_power


static func _pair_context(_g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var attacker: CardInstance = e.data.get("attacker")
	var blocker: CardInstance = e.data.get("blocker")
	return {"timestamp": s.layer_timestamp, "controller": s.controller_id,
		"attacker": attacker.id if attacker != null else -1,
		"attacker_stamp": attacker.layer_timestamp if attacker != null else -1,
		"blocker": blocker.id if blocker != null else -1,
		"blocker_stamp": blocker.layer_timestamp if blocker != null else -1}


static func _quarter_blocker(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var i := MC.live(g, int(ctx.get("blocker", -1)), int(ctx.get("blocker_stamp", -2)))
	if i != null:
		g.destroy(i)


static func _quarter_attacker(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var i := MC.live(g, int(ctx.get("attacker", -1)), int(ctx.get("attacker_stamp", -2)))
	if i != null:
		g.destroy(i)


# --------------------------------------------------------------- Propaganda --

static func _propaganda(g: MtgGame, s: CardInstance) -> void:
	for i in g.players[g.opponent_of(s.controller_id)].battlefield:
		if i.is_creature():
			i.cur_attack_costs.append({"desc": "its controller pays {2} (Propaganda)",
				"generic_mana": 2, "can_pay": _can_pay_two, "pay": _pay_two})


static func _can_pay_two(g: MtgGame, who: int) -> bool:
	return g.can_afford_cost(who, ManaCost.parse("{2}"))


static func _pay_two(g: MtgGame, who: int) -> void:
	g.try_pay(who, ManaCost.parse("{2}"))


# --------------------------------------------------------- Renegade Warlord --

## "Each other attacking creature" as the ability resolves (CR 611.2c).
static func _warlord(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pumped := false
	for id in g.combat.attackers:
		var i := g.find_instance(int(id))
		if i == null or i.id == s.id or not g.is_present(i) or not i.is_creature(): continue
		g.continuous.add_until_eot_pump(i.id, 1, 0)
		pumped = true
	if pumped:
		g.recalculate()


# ------------------------------------------------------- Trumpeting Armodon --

## The requirement rides on the Armodon for the turn: "that creature blocks
## this creature if able" is a Lure narrowed to that one object. An Armodon
## that has left (or is a new object) has nothing to be blocked.
static func _armodon(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	var victim := g.find_instance(t.instance_id)
	if not g.is_present(victim) or not MC.live_source(g, s): return
	g.continuous.add_floating_static(s, StaticAbility.new(
		_armodon_lure.bind(s.layer_timestamp, victim.id, victim.layer_timestamp),
		"That creature blocks this creature this turn if able."),
		ContinuousEffects.Duration.END_OF_TURN, -1, false, s.id)
	g.recalculate()


static func _armodon_lure(g: MtgGame, s: CardInstance, stamp: int, id: int, chosen_stamp: int) -> void:
	if not g.is_present(s) or s.layer_timestamp != stamp: return
	narrow_lure(s, func(blocker: CardInstance) -> bool:
		return blocker.id == id and blocker.layer_timestamp == chosen_stamp)


# ---------------------------------------------------------------- Watchdog --

## "All creatures attacking you": while its controller is the defending
## player (CR 506.2), every creature still in combat as an attacker.
static func _watchdog(g: MtgGame, s: CardInstance) -> void:
	if s.tapped or g.active_player == s.controller_id: return
	for id in g.combat.attackers:
		var i := g.find_instance(int(id))
		if g.is_present(i) and i.is_creature() and i.controller_id != s.controller_id:
			i.cur_power -= 1
