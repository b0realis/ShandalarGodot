extends RefCounted
const F := preload("res://cards/sets/fem/_rules.gd")
const S := preload("res://cards/sets/por/_simple.gd")
const T := preload("res://cards/sets/por/_triggers.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Spitting Earth": c.spell(T.MountainDamage.new())
		"Final Strike": c.with_additional_sacrifice("creature", F._creature).spell(SacrificeDamage.new())
		"Path of Peace": c.spell(Peace.new(TargetSpec.creature()))
		"Defiant Stand":
			c.castable_only_when(S._attacked)
			c.spell(PumpAndAction.new(1, 3, false))
		"Burning Cloak": c.spell(PumpAndAction.new(2, 0, true))
		"Time Ebb": c.spell(ToLibrary.new())
		"Blinding Light": c.spell(F.Action.new(_blinding, "tap all nonwhite creatures"))
		"Mobilize": c.spell(F.Action.new(_mobilize, "untap all creatures you control", null, true))
		"Exhaustion": c.spell(F.Action.new(_exhaust, "creatures and lands target opponent controls skip their next untap", TargetSpec.opponent()))
		"Blessed Reversal": c.spell(LifeCensus.new("attackers", 3))
		"Fruition": c.spell(LifeCensus.new("forest", 1))
		"Renewing Dawn": c.spell(LifeCensus.new("mountain", 2))
		"Starlight": c.spell(LifeCensus.new("black", 3))
		"Alluring Scent": c.spell(F.Action.new(_lure, "all creatures able to block target creature do so this turn", TargetSpec.creature(), true))
		"Dread Charge": c.spell(F.Action.new(_evasion.bind(false), "your black creatures can be blocked only by black creatures this turn", null, true))
		"Nature's Cloak": c.spell(F.Action.new(_evasion.bind(true), "your green creatures gain forestwalk this turn", null, true))
		"Summer Bloom": c.spell(F.Action.new(_bloom, "you may play three additional lands this turn", null, true))
		"Deep Wood":
			c.castable_only_when(S._attacked)
			c.spell(F.Action.new(_wood, "prevent all damage attacking creatures would deal to you this turn", null, true).as_damage_prevention())
		"Harsh Justice":
			c.castable_only_when(S._attacked)
			c.spell(F.Action.new(_justice, "attacking creatures that deal combat damage to you also deal that damage to their controller this turn", null, true))
		"False Peace": c.spell(F.Action.new(_next_combat.bind(true), "target player skips combat phases during their next turn", TargetSpec.player()))
		"Taunt": c.spell(F.Action.new(_next_combat.bind(false), "target player's creatures attack you if able during their next turn", TargetSpec.player()))
		"Last Chance": c.spell(LastTurn.new())
		"Charging Rhino", "Stalking Tiger": c.static_ability(StaticAbility.new(_one_blocker, "Can't be blocked by more than one creature."))
		_: return false
	return true

class SacrificeDamage extends DamageEffect:
	func _init() -> void:
		super(0)
		target_spec = TargetSpec.opponent()
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		g.deal_damage(s, t, maxi(0, int(g.cost_paid("_sacrificed_power", 0))))
	func describe() -> String: return "deal damage equal to the sacrificed creature's power"

class Peace extends DestroyEffect:
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var victim := g.find_instance(t.instance_id)
		var owner := victim.owner_id
		g.destroy(victim)
		g.adjust_life(owner, 4) # Owner, even when stolen or regenerated.
	func describe() -> String: return "destroy target creature; its owner gains 4 life"

class PumpAndAction extends PumpEffect:
	var burn: bool
	func _init(power: int, toughness: int, damage: bool) -> void:
		super(power, toughness)
		burn = damage
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		super(g, s, pid, t, x)
		if burn: g.deal_damage(s, t, 2)
		else: g.untap_permanent(g.find_instance(t.instance_id))
	func describe() -> String: return super() + ("; deal 2 damage to that creature" if burn else "; untap it")

class ToLibrary extends ReturnToHandEffect:
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		g.return_permanent_to_library_top(g.find_instance(t.instance_id))
	func describe() -> String: return "put target creature on top of its owner's library"

static func _blinding(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	for i in g.all_battlefield():
		if i.is_creature() and (i.cur_colors & Mtg.ManaColor.W) == 0: g.tap_permanent(i)
static func _mobilize(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	for i in g.players[pid].creatures(): g.untap_permanent(i)
static func _exhaust(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	for i in g.players[t.player_id].battlefield:
		if i.is_creature() or i.is_land(): g.skip_untap_during_next_step(i, t.player_id)

class LifeCensus extends GainLifeEffect:
	var kind: String
	func _init(shape: String, factor: int) -> void:
		super(factor)
		kind = shape
		if kind in ["mountain", "black"]: target_spec = TargetSpec.opponent()
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var count := 0
		var cards: Array[CardInstance] = g.all_battlefield() if t == null else g.players[t.player_id].battlefield
		for i in cards:
			if kind == "attackers" and i.is_creature() and i.controller_id != pid and g.combat.attackers.has(i.id): count += 1
			elif kind == "black" and S._colored_creature(i, Mtg.ManaColor.B): count += 1
			elif kind in ["forest", "mountain"] and i.has_subtype(kind): count += 1
		g.adjust_life(pid, count * amount)
	func describe() -> String: return "gain %d life for each matching %s" % [amount, kind]

static func _lure(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	g.continuous.add_floating_static(s, StaticAbility.new(_lured.bind(t.instance_id), "Must be blocked if able."), ContinuousEffects.Duration.END_OF_TURN, -1, false, t.instance_id)
	g.recalculate()
static func _lured(g: MtgGame, _s: CardInstance, id: int) -> void:
	var i := g.find_instance(id)
	if i != null: i.cur_must_be_blocked = true
static func _one_blocker(_g: MtgGame, s: CardInstance) -> void: s.cur_max_blockers = 1
static func _black(i: CardInstance) -> bool: return (i.cur_colors & Mtg.ManaColor.B) != 0
static func _evasion(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int, forestwalk: bool) -> void:
	for i in g.players[pid].creatures():
		if (i.cur_colors & (Mtg.ManaColor.G if forestwalk else Mtg.ManaColor.B)) == 0: continue
		var ability := StaticAbility.new(_evade.bind(i.id, forestwalk), "Forestwalk." if forestwalk else "Only black creatures can block.")
		if forestwalk: ability.changing_abilities()
		g.continuous.add_floating_static(s, ability, ContinuousEffects.Duration.END_OF_TURN, -1, false, i.id)
	g.recalculate()
static func _evade(g: MtgGame, _s: CardInstance, id: int, forestwalk: bool) -> void:
	var i := g.find_instance(id)
	if i == null: return
	if forestwalk: i.cur_landwalk.append("forest")
	else: i.cur_block_restrictions.append({"desc": "black creatures", "filter": _black})
static func _bloom(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	g.continuous.add_floating_static(s, StaticAbility.new(_more_lands.bind(pid), "Three additional land plays this turn."))
	g.recalculate()
static func _more_lands(g: MtgGame, _s: CardInstance, pid: int) -> void: g.extra_land_plays[pid] = int(g.extra_land_plays.get(pid, 0)) + 3
static func _wood(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	g.continuous.add_floating_static(s, StaticAbility.new(_wood_shield.bind(pid), "Prevent attacking creatures' damage to you this turn."))
	g.recalculate()
static func _wood_shield(g: MtgGame, _s: CardInstance, pid: int) -> void:
	g.players[pid].static_prevention_shields.append({"desc": "Deep Wood", "filter": _attacker.bind(weakref(g))})
static func _attacker(i: CardInstance, game_ref: WeakRef) -> bool:
	var g: MtgGame = game_ref.get_ref()
	return g != null and i.is_creature() and g.combat.attackers.has(i.id)
static func _justice(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var trigger := TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _retaliate, "That creature deals the same damage to its controller.", _hurt.bind(pid, g.turn_number))
	var entry := g.schedule_delayed_trigger(trigger, pid, s, true)
	entry["expires_turn"] = g.turn_number
static func _hurt(g: MtgGame, _s: CardInstance, e: GameEvent, pid: int, turn: int) -> bool:
	var source: CardInstance = e.data.get("source")
	var packet: DamagePacket = e.data.get("packet")
	return g.turn_number == turn and packet != null and packet.is_combat and int(e.data.get("to_player", -1)) == pid and source != null and source.is_creature() and g.combat.attackers.has(source.id)
static func _retaliate(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var source: CardInstance = e.data.source
	g.deal_damage(source, TargetRef.player(source.controller_id), int(e.data.amount))
static func _next_combat(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x: int, skip: bool) -> void:
	if not skip and t.player_id == pid: return # A player cannot attack themself.
	g.queue_next_turn_static(t.player_id, s, StaticAbility.new(_combat_rule.bind(t.player_id, skip), "Skip combat phases." if skip else "Creatures attack if able."))
static func _combat_rule(g: MtgGame, _s: CardInstance, pid: int, skip: bool) -> void:
	if skip: g.skip_combat_this_turn = true
	else:
		for i in g.players[pid].creatures():
			if not i.cur_keywords.has(Mtg.Keyword.MUST_ATTACK): i.cur_keywords.append(Mtg.Keyword.MUST_ATTACK)
class LastTurn extends ExtraTurnEffect:
	func resolve(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void: g.add_extra_turn(pid, s)
	func describe() -> String: return "take an extra turn; at that turn's end step, you lose the game"
