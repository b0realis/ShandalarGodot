extends RefCounted
const F := preload("res://cards/sets/fem/_rules.gd")
const SNOW := preload("res://cards/sets/ice/_snow.gd")
const SCARABS := {"White Scarab": Mtg.ManaColor.W, "Blue Scarab": Mtg.ManaColor.U,
	"Black Scarab": Mtg.ManaColor.B, "Red Scarab": Mtg.ManaColor.R, "Green Scarab": Mtg.ManaColor.G}

static func configure(c: CardData) -> bool:
	var n := c.card_name
	if SCARABS.has(n):
		c.enchants(TargetSpec.creature())
		c.static_ability(StaticAbility.new(_scarab.bind(int(SCARABS[n])), "Conditional +2/+2 and evasion from the named colour."))
		return true
	match n:
		"Armor of Faith":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(1, 1), "Enchanted creature gets +1/+1."))
			c.activated(F._ability("{W}", false, HostPump.new(0, 1)))
		"Stonehands":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(0, 2), "Enchanted creature gets +0/+2."))
			c.activated(F._ability("{R}", false, HostPump.new(1, 0)))
		"Soul Kiss":
			c.enchants(TargetSpec.creature())
			c.activated(F._ability("{B}", false, HostPump.new(2, 2)).with_life_cost(1).per_turn(3))
		"Cooperation":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(_host_keywords.bind([Mtg.Keyword.BANDING]), "Enchanted creature has banding.").changing_abilities())
		"Wings of Aesthir":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(1, 0), "Enchanted creature gets +1/+0."))
			c.static_ability(StaticAbility.new(_host_keywords.bind([Mtg.Keyword.FLYING, Mtg.Keyword.FIRST_STRIKE]),
				"Enchanted creature has flying and first strike.").changing_abilities())
		"Imposing Visage":
			c.enchants(TargetSpec.creature())
			# A layer-6 grant (CR 613.1f; campaign 2026-10, w3-7): a newer
			# Humility takes the menace away.
			c.static_ability(StaticAbility.new(_host_menace, "Enchanted creature has menace.").changing_abilities())
		"Leshrac's Rite":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(_swampwalk, "Enchanted creature has swampwalk.").changing_abilities())
		"Spectral Shield":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(0, 2), "Enchanted creature gets +0/+2."))
			c.static_ability(StaticAbility.new(_spell_shroud, "Enchanted creature can't be the target of spells."))
		"Snow Devil":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(_snow_devil, "Flying; first strike while blocking with a snow land.").changing_abilities())
		"Krovikan Fetish":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(1, 1), "Enchanted creature gets +1/+1."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _slow_draw, "Draw next turn's upkeep.", F._self_enter))
		"Essence Flare":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(2, 0), "Enchanted creature gets +2/+0."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _flare,
				"Put a -0/-1 counter on enchanted creature.", _host_upkeep).capturing(_host_context))
		"Maddening Wind":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _wind, "Deal 2 damage to enchanted creature's controller.",
				_host_upkeep).capturing(_host_context))
		"Mind Whip":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _whip, "Pay {3} or take 2 damage and tap enchanted creature.",
				_host_upkeep).capturing(_host_context))
		"Seizures":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECAME_TAPPED, _seizures, "Pay {3} or take 3 damage.",
				_host_tapped).capturing(_host_context))
		"Binding Grasp":
			c.enchants(TargetSpec.creature()).steals_control()
			c.static_ability(StaticAbility.new(F._aura_pump.bind(0, 1), "Enchanted creature gets +0/+1."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, F._upkeep_payment.bind("{1}{U}"),
				"Pay {1}{U} or sacrifice this Aura.", F._your_upkeep))
		"Conquer":
			c.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _land)).steals_control()
		"Forbidden Lore", "Mystic Might", "Hot Springs":
			var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _land)
			if n != "Forbidden Lore": spec.with_source_filter(F._own)
			c.enchants(spec)
			c.static_ability(StaticAbility.new(_land_ability.bind(n), "Enchanted land gains a tap ability.").changing_abilities())
		"Fylgja":
			c.enchants(TargetSpec.creature()).with_enters_counters("healing", 4)
			var prevent := F.Action.new(_healing, "prevent the next 1 damage to enchanted creature", null, true).as_damage_prevention()
			c.activated(F._ability("", false, prevent).with_counter_cost("healing"))
			c.activated(F._ability("{2}{W}", false, F.Action.new(_add_healing, "put a healing counter on this Aura")))
		_:
			return false
	return true

static func _land(i: CardInstance) -> bool: return i.is_land()
static func host(g: MtgGame, source: CardInstance) -> CardInstance:
	var i := g.find_instance(source.attached_to)
	return i if i != null and i.zone == Mtg.Zone.BATTLEFIELD else null
static func paid_host(g: MtgGame, source: CardInstance) -> CardInstance:
	var i := g.find_instance(int(g.cost_paid("_source_attached_to", source.attached_to)))
	return i if i != null and i.zone == Mtg.Zone.BATTLEFIELD and i.layer_timestamp == int(g.cost_paid("_source_attached_timestamp", -1)) else null
static func _host_keywords(g: MtgGame, source: CardInstance, keywords: Array) -> void:
	var i := host(g, source)
	if i == null: return
	for k in keywords:
		if not i.cur_keywords.has(k): i.cur_keywords.append(k)
static func _host_menace(g: MtgGame, source: CardInstance) -> void:
	var i := host(g, source)
	if i != null: i.cur_min_blockers = maxi(i.cur_min_blockers, 2)
static func _swampwalk(g: MtgGame, source: CardInstance) -> void:
	var i := host(g, source)
	if i != null and not i.cur_landwalk.has("swamp"): i.cur_landwalk.append("swamp")
static func _spell_shroud(g: MtgGame, source: CardInstance) -> void:
	var i := host(g, source)
	if i != null: i.cur_cant_be_spell_target = true
static func _snow_devil(g: MtgGame, source: CardInstance) -> void:
	_host_keywords(g, source, [Mtg.Keyword.FLYING])
	var i := host(g, source)
	if i != null and not g.combat.attackers_blocked_by(i.id).is_empty() and SNOW.snow_count(g, source.controller_id) > 0:
		_host_keywords(g, source, [Mtg.Keyword.FIRST_STRIKE])
static func _not_color(i: CardInstance, color: int) -> bool: return (i.cur_colors & color) == 0
static func _scarab(g: MtgGame, source: CardInstance, color: int) -> void:
	var i := host(g, source)
	if i == null: return
	i.cur_block_restrictions.append({"desc": "not " + Mtg.COLOR_NAMES[color], "filter": _not_color.bind(color)})
	for other in g.all_battlefield():
		if other.controller_id != source.controller_id and (other.cur_colors & color) != 0:
			i.cur_power += 2
			i.cur_toughness += 2
			break
static func _host_upkeep(g: MtgGame, source: CardInstance, e: GameEvent) -> bool:
	var i := host(g, source)
	return i != null and i.controller_id == int(e.data.get("player", -1))
static func _host_tapped(g: MtgGame, source: CardInstance, e: GameEvent) -> bool:
	return e.data.get("instance") == host(g, source)
static func _host_context(g: MtgGame, source: CardInstance, e: GameEvent) -> Dictionary:
	var out := F._source_context(g, source, e)
	var i := host(g, source)
	if i != null: out.merge({"host": i.id, "host_stamp": i.layer_timestamp, "host_controller": i.controller_id})
	return out
static func _trigger_host(g: MtgGame, source: CardInstance) -> CardInstance:
	var context := g.trigger_context(source)
	var i := g.find_instance(int(context.get("host", -1)))
	return i if i != null and i.zone == Mtg.Zone.BATTLEFIELD and i.layer_timestamp == int(context.get("host_stamp", -1)) else null
static func _flare(g: MtgGame, source: CardInstance, _e: GameEvent) -> void:
	var i := _trigger_host(g, source)
	if i != null: g.add_counters(i, "-0/-1")
static func _wind(g: MtgGame, source: CardInstance, _e: GameEvent) -> void:
	g.deal_damage(source, TargetRef.player(int(g.trigger_context(source).host_controller)), 2)
static func _whip(g: MtgGame, source: CardInstance, _e: GameEvent) -> void:
	var pid := int(g.trigger_context(source).host_controller)
	if not EffectBase.unless_paid(g, pid, ManaCost.parse("{3}"), "Mind Whip: pay {3}?"):
		g.deal_damage(source, TargetRef.player(pid), 2)
		var i := _trigger_host(g, source)
		if i != null: g.tap_permanent(i)
static func _seizures(g: MtgGame, source: CardInstance, _e: GameEvent) -> void:
	var pid := int(g.trigger_context(source).host_controller)
	if not EffectBase.unless_paid(g, pid, ManaCost.parse("{3}"), "Seizures: pay {3}?"):
		g.deal_damage(source, TargetRef.player(pid), 3)
static func _slow_draw(g: MtgGame, source: CardInstance, _e: GameEvent) -> void:
	DelayedDrawEffect.new().resolve(g, source, int(g.trigger_context(source).controller), null)
static func _land_ability(g: MtgGame, source: CardInstance, name: String) -> void:
	var i := host(g, source)
	if i == null: return
	var effect: EffectBase = PreventDamageEffect.new(1).any_target() if name == "Hot Springs" else PumpEffect.new(2, 2 if name == "Mystic Might" else 1)
	i.cur_activated_abilities.append(F._ability("", true, effect))
static func _healing(g: MtgGame, source: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var i := paid_host(g, source)
	if i != null: PreventDamageEffect.new(1).any_target().resolve(g, source, pid, TargetRef.card(i))
static func _add_healing(g: MtgGame, source: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if source.zone == Mtg.Zone.BATTLEFIELD and source.layer_timestamp == int(g.cost_paid("_source_timestamp", -1)):
		g.add_counters(source, "healing")

class HostPump extends PumpEffect:
	func _init(p: int, t: int) -> void:
		super(p, t)
		target_spec = null
	func describe() -> String:
		return "enchanted creature gets %+d/%+d until end of turn" % [power, toughness]
	func resolve(g: MtgGame, source: CardInstance, pid: int, _t: TargetRef, x := 0) -> void:
		var id := int(g.cost_paid("_source_attached_to", -1))
		var i := g.find_instance(id)
		if i != null and i.zone == Mtg.Zone.BATTLEFIELD and i.layer_timestamp == int(g.cost_paid("_source_attached_timestamp", -1)):
			super(g, source, pid, TargetRef.card(i), x)
